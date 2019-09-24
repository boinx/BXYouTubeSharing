//**********************************************************************************************************************
//
//  BXYouTubeUploadController.swift
//  Copyright ©2019 Boinx Software Ltd. & Imagine GbR. All rights reserved.
//
//**********************************************************************************************************************


import Foundation


//----------------------------------------------------------------------------------------------------------------------


public class BXYouTubeUploadController: NSObject
{

	/// Convenience singleton instance of this controller
	
	public static let shared = BXYouTubeUploadController()
	
	/// The user access token used to authenticate all requests made by this controller
	
	public var accessToken:String? = nil

	/// The delegate for UI feedback
	
	public weak var delegate:BXYouTubeUploadControllerDelegate? = nil
	
    override init()
    {
        super.init()
        
        self.restoreUploadItem()
    }
	

//----------------------------------------------------------------------------------------------------------------------


	// MARK: -
	
	
	/// Retrieves the list of categories that are known to YouTube. Specify a language code like "en" or "de"
	/// to localize the names.
	
	public func requestCategories(for languageCode:String, maxRetries: Int = 3, completionHandler: @escaping ([Category], Error?)->Void)
	{
        guard let accessToken = self.accessToken else
        {
            BXYouTubeAuthenticationController.shared?.requestAccessToken({ (accessToken, error) in
                if error != nil
                {
                    completionHandler([], Error.other(underlyingError: error))
                    return
                }
                self.accessToken = accessToken
                self.requestCategories(for: languageCode, maxRetries: maxRetries-1, completionHandler: completionHandler)
            })
            return
        }
        
		let request = BXYouTubeNetworkHelpers.categoriesRequest(languageCode: languageCode, accessToken: accessToken)
        
        let task = self.foregroundSession.dataTask(with: request)
        {
            (data, _, error) in
            
            if let error = error
            {
                DispatchQueue.main.async
                {
                    completionHandler([], Error.other(underlyingError: error))
                }
                return
            }
            else if let data = data,
                    let payload = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
            {
                if let errorDict = payload["error"] as? [String: Any],
                   let errorCode = errorDict["code"] as? Int,
                   let errorDescription = errorDict["message"] as? String
                {
                    if (errorCode == 401 || errorCode == 403) && maxRetries > 0
                    {
                        // Retry
                        BXYouTubeAuthenticationController.shared?.requestAccessToken({ (accessToken, error) in
                            if error != nil
                            {
                                completionHandler([], Error.other(underlyingError: error))
                                return
                            }
                            self.accessToken = accessToken
                            self.requestCategories(for: languageCode, maxRetries: maxRetries-1, completionHandler: completionHandler)
                        })
                        return
                    }
                    else
                    {
                        DispatchQueue.main.async
                        {
                            completionHandler([], Error.youTubeAPIError(reason: errorDescription))
                        }
                        return
                    }
                }
                else if let items = payload["items"] as? [[String: Any]]
                {
                    // Extract assignable categories from items.
                    let categories = items.compactMap({ Category(withResponse: $0) })
                                          .filter({ $0.assignable })
                    
                    DispatchQueue.main.async
                    {
                        completionHandler(categories, nil)
                    }
                    return
                }
            }
            
            DispatchQueue.main.async
            {
                completionHandler([], Error.youTubeAPIError(reason: "Invalid response"))
            }
        }
        task.resume()
	}
	

//----------------------------------------------------------------------------------------------------------------------


	// MARK: -
	
	public enum Error : Swift.Error
	{
		case invalidAccessToken
        case fileAccessError
        case userCanceled
        case uploadAlreadyInProgress
        case accountWithoutChannel // The YouTube API's `youtubeSignupRequired` error, see https://developers.google.com/youtube/create-channel
        case youTubeAPIError(reason: String)
		case other(underlyingError: Swift.Error?)
	}
	
	
//----------------------------------------------------------------------------------------------------------------------


 	/// High priority session for immediate tasks
	
    private lazy var foregroundSession: URLSession =
    {
        return URLSession(configuration: .default, delegate: nil, delegateQueue: self.queue)
    }()
	
	
 	/// Low priority session for long running background tasks
	
    private lazy var backgroundSession: URLSession =
    {
        let identifier = BXYouTubeNetworkHelpers.backgroundSessionIdentifier
        return URLSession(configuration: .background(withIdentifier: identifier), delegate: self, delegateQueue: self.queue)
    }()
	
	
	/// Background qork will be performed on this queue
	
    private lazy var queue: OperationQueue =
    {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()


	private var uploadItem: Item? = nil
    {
        didSet
        {
            self.storeUploadItem()
        }
    }
	private var uploadURL: URL? = nil
    private var retryCount = 0
    
    private func storeUploadItem()
    {
        let identifier = BXYouTubeNetworkHelpers.backgroundSessionIdentifier.replacingOccurrences(of: ".", with: "_")
        if let uploadItem = self.uploadItem,
           let data = try? JSONEncoder().encode(uploadItem)
        {
            UserDefaults.standard.set(data, forKey: identifier)
        }
        else
        {
            UserDefaults.standard.removeObject(forKey: identifier)
        }
    }

    private func restoreUploadItem()
    {
        let identifier = BXYouTubeNetworkHelpers.backgroundSessionIdentifier.replacingOccurrences(of: ".", with: "_")
        if let data = UserDefaults.standard.data(forKey: identifier),
           let uploadItem = try? JSONDecoder().decode(Item.self, from: data)
        {
            self.uploadItem = uploadItem
        }
    }

//----------------------------------------------------------------------------------------------------------------------


	// MARK: - Public API

	/// Starts the upload process
	
	public func upload(_ item:Item, notifySubscribers:Bool = true) throws
	{
 		// NOTE: uploadItem can and will be modified from the background queue. If code related to that property behaves
        // strangely, maybe always use self.queue when accessing uploaditem.
        
        guard self.uploadItem == nil else
        {
            throw Error.uploadAlreadyInProgress
        }
 		guard let accessToken = self.accessToken else
        {
            throw Error.invalidAccessToken
        }
		guard let fileSize = item.fileURL.fileSize else
        {
            throw Error.fileAccessError
        }
        
        self.uploadItem = item

		// Notify delegate that upload is about to start, so that UI can be updated.
		
        self.delegate?.onMainThread { $0.willStartUpload() }

        let videoCreationRequest = BXYouTubeNetworkHelpers.videoCreationRequest(for: item, ofSize: fileSize, accessToken: accessToken, notifySubscribers: notifySubscribers)
  
        let creationTask = self.foregroundSession.dataTask(with: videoCreationRequest)
        {
        	[weak self] (data, response, error) in
			
            guard let _self = self else { return }
            
            if let error = error
            {
                _self._resetState()
                _self.delegate?.onMainThread { $0.didFinishUpload(url: nil, error: Error.other(underlyingError: error)) }
            }
            else if let httpResponse = response as? HTTPURLResponse
            {
                if httpResponse.statusCode == 200,
                   let uploadLocation = httpResponse.allHeaderFields["Location"] as? String,
                   let uploadURL = URL(string: uploadLocation)
                {
                    _self.delegate?.onMainThread { $0.didStartUpload() }

                    _self.uploadURL = uploadURL
                    _self._startUploadTask()
                }
                else if let data = data,
                        let jsonObj = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any],
                        let errorObj = jsonObj["error"] as? [String: Any],
                        let errorMessage = errorObj["message"] as? String
                {
                    var error: Error = .youTubeAPIError(reason: errorMessage)
                    
                    // Check nested error description objects for youtubeSignupRequired error.
                    if let errorReasonObjs = jsonObj["errors"] as? [[String: Any]],
                       errorReasonObjs.contains(where: { errorReasonObj in
                           (errorReasonObj["reason"] as? String) == "youtubeSignupRequired"
                       })
                    {
                        // The user is logged in with an account that has no channel and therefore can't upload video.
                        // https://developers.google.com/youtube/create-channel describes how to handle such situations.
                        error = .accountWithoutChannel
                    }
                	
                    _self._resetState()
                    _self.delegate?.onMainThread { $0.didFinishUpload(url: nil, error: error) }
                }
            }
            else
            {
                _self._resetState()
                _self.delegate?.onMainThread { $0.didFinishUpload(url: nil, error: Error.other(underlyingError: nil)) }
            }
        }
        self.uploadItem?.taskID = creationTask.taskIdentifier
        self.storeUploadItem()
        
        creationTask.resume()
	}
 
 
    /// Cancels the upload
    
    public func cancel()
    {
        self.queue.addOperation
        {
            [weak self] in
            
            guard let _self = self,
                  let uploadTaskID = _self.uploadItem?.taskID
            else { return }
            
            _self.backgroundSession.getTasksWithCompletionHandler
            {
                (_, uploadTasks, _) in
                
                uploadTasks.first(where: { $0.taskIdentifier == uploadTaskID })?.cancel()
            }

            _self._resetState()
            _self.delegate?.onMainThread { $0.didFinishUpload(url: nil, error: Error.userCanceled) }
        }
    }
	
 
    // MARK: - Internal Methods
	
	private func _startUploadTask()
	{
        assert(OperationQueue.current == self.queue, "BXYouTubeUploadController.\(#function) may only be called on self.queue")
 
        self.lastUploadStatus = nil
 
		guard let accessToken = self.accessToken else { return }
		guard let item = self.uploadItem else { return }
		guard let fileSize = item.fileURL.fileSize else { return }
		guard let uploadURL = self.uploadURL else { return }

        // Upload task may not be created on self.queue (which has a concurrency of 1 and therefore blocks).
        DispatchQueue.background.async
        {
            let uploadRequest = BXYouTubeNetworkHelpers.videoUploadRequest(for: item, ofSize: fileSize, location: uploadURL, accessToken: accessToken)
            let uploadTask = self.backgroundSession.uploadTask(with: uploadRequest, fromFile: item.fileURL)
            
            self.queue.addOperation
            {
                self.uploadItem?.taskID = uploadTask.taskIdentifier
                self.storeUploadItem()
            }
            self.queue.waitUntilAllOperationsAreFinished()
            
            uploadTask.resume()
        }
	}
 
    private func _resetState()
    {
        assert(OperationQueue.current == self.queue, "BXYouTubeUploadController.\(#function) may only be called on self.queue")
        
//        NSLog("RESET UPLOAD STATE")
        
        self.retryCount = 0
        self.uploadItem = nil
        self.uploadURL = nil
        
        // NOTE: _resetState does not clear lastUplaodStatus, because it should be avaialble to consumers even after
        // the volatile upload state used during the upload has been cleared.
    }
    
    public enum UploadStatus
    {
        case progress(uploadItem: Item, progress: Progress)
        case completed(uploadItem: Item, url: URL)
        case failed(uploadItem: Item, error: Error)
    }
    
    private var lastUploadStatus: UploadStatus? = nil
    {
        didSet
        {
//            NSLog("Did set lastUploadStatus to \(String(describing: self.lastUploadStatus))")
        }
    }
    
    private var uploadStatusCompletionhandlers: [(UploadStatus?) -> Void] = []
    private var notifyUploadStatusCompletionHandlersAfterFirstProgressEvent = false
    
    private func _notifyUploadStatusCompletionHandlers()
    {
        assert(OperationQueue.current == self.queue, "BXYouTubeUploadController.\(#function) may only be called on self.queue")
        
        let uploadStatus = self.lastUploadStatus
        
//		NSLog("Notify completion handlers with status \(String(describing:uploadStatus))")
        
        let completionHandlers = self.uploadStatusCompletionhandlers
        self.uploadStatusCompletionhandlers = []
        
        DispatchQueue.main.async
        {
            completionHandlers.forEach { $0(uploadStatus) }
        }
        
        self.notifyUploadStatusCompletionHandlersAfterFirstProgressEvent = false
    }
    
    public func checkUploadStatus(completionHandler: ((UploadStatus?) -> Void)? = nil)
    {
//        NSLog("Start check upload status")
        self.queue.addOperation
        {
            // If the uploadStatus has already been determined, we won't receive any events for that upload anymore and
            // must call the completion handler directly.
            // Note: `lastUploadStatus` must be cleared once a new upload begins, or a old value will be reported here!
            if let uploadStatus = self.lastUploadStatus
            {
//                NSLog("Has cached upload status, deliver it.")
                DispatchQueue.main.async
                {
                    completionHandler?(uploadStatus)
                }
                return
            }
            
            // If there is no upload in process, there is no use in creating the url session and waiting for delegate
            // events.
            guard let uploadItem = self.uploadItem else
            {
//                NSLog("Has no upload item")
                DispatchQueue.main.async
                {
                    completionHandler?(nil)
                }
                return
            }
            
//            NSLog("Store completion handler for later")
            
            // In all other cases, remember the completion handler and call it once all events have been flushed. The
            // completion handlers will be called and cleared in `urlSessionDidFinishEvents`.
            if let completionHandler = completionHandler
            {
                self.uploadStatusCompletionhandlers.append(completionHandler)
            }
            
            // (Re-)create the background URLSession to receive updates about running upload tasks on the delegate queue.
            let session = self.backgroundSession
            
            // If the upload's task is still in progress, completion handlers must be called immediately because no
            // events will be replayed and thus didFinishEvents will not be called.
            session.getTasksWithCompletionHandler(
            {
                (_, uploadTasks, _) in
                
                if let currentUploadTasks = uploadTasks.first(where: { $0.taskIdentifier == uploadItem.taskID }),
                   currentUploadTasks.state == .running
                {
                    self.lastUploadStatus = .progress(uploadItem: uploadItem, progress: currentUploadTasks.progress)
                    self._notifyUploadStatusCompletionHandlers()
                }
            })
        }
    }
    
}


//----------------------------------------------------------------------------------------------------------------------


// MARK: - URLSessionTaskDelegate

extension BXYouTubeUploadController: URLSessionTaskDelegate
{
	// Notify our client of the upload progress
	
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64)
    {
        // Method is called on self.queue.
        
//        NSLog("Urlsession session:task:didSendBodyData: \(totalBytesSent) of \(totalBytesExpectedToSend)")
        
        if let uploadItem = self.uploadItem,
           uploadItem.taskID == task.taskIdentifier
        {
            self.lastUploadStatus = .progress(uploadItem: uploadItem, progress: task.progress)
        }
        
        self.delegate?.onMainThread { $0.didContinueUpload(progress: task.progress) }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Swift.Error?)
    {
        // Method is called on self.queue.
        
//        NSLog("UploadController: session:task:didCompleteWithError: \(String(describing: error))")
        
		if let error = error
        {
            let wrappedError = Error.other(underlyingError: error)
            
            if let uploadItem = self.uploadItem,
               uploadItem.taskID == task.taskIdentifier
            {
                self.lastUploadStatus = .failed(uploadItem: uploadItem, error: wrappedError)
            }
        
            self._resetState()
            self.delegate?.onMainThread { $0.didFinishUpload(url: nil, error: wrappedError) }
        }
		else if let statusCode = (task.response as? HTTPURLResponse)?.statusCode,
			    statusCode == 500 || statusCode == 502 || statusCode == 503 || statusCode == 504
		{
			// If we failed to start the upload, then retry a limited number of times,
			// each time backing off a little bit longer
   
//            NSLog("Upload has failed")
			
			if self.retryCount < 5 && self.uploadItem != nil
			{
				let delay = pow(2,Double(retryCount))
				self.retryCount += 1
    
//                NSLog("Retry upload later")

				DispatchQueue.main.asyncAfter(deadline:.now()+delay)
				{
					[weak self] in
                    
                    self?.queue.addOperation
                    {
                        self?._startUploadTask()
                    }
				}
			}
			
			// After a certain number of retries we finally give up
			
			else
			{
//                NSLog("Giving up, too many retries")
                
                let error = Error.youTubeAPIError(reason:"Too many retries!")
                
                if let uploadItem = self.uploadItem,
                   uploadItem.taskID == task.taskIdentifier
                {
                    self.lastUploadStatus = .failed(uploadItem: uploadItem, error: error)
                }
                
                self._resetState()
                self.delegate?.onMainThread { $0.didFinishUpload(url: nil, error: error) }
			}
		}
		
		// Everything finished successfully!
		
		else
		{
            var url: URL? = nil
            if let data = self.uploadItem?.uploadReponseData,
               let jsonResponse = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any],
               let videoId = jsonResponse["id"] as? String
            {
                NSLog("Extracted video ID \(videoId) from payload")
                url = URL(string: "https://www.youtube.com/watch?v=\(videoId)")
            }
            
            NSLog("Upload was fine. UploadItem: \(String(describing: self.uploadItem)), stored taskID: \(String(describing: self.uploadItem?.taskID)), completed taskID: \(task.taskIdentifier)")
            
            if let uploadItem = self.uploadItem,
               uploadItem.taskID == task.taskIdentifier,
               let url = url
            {
                self.lastUploadStatus = .completed(uploadItem: uploadItem, url: url)
            }
            
            self._resetState()
            self.delegate?.onMainThread { $0.didFinishUpload(url: url, error: nil) }
		}
		
    }
}

extension BXYouTubeUploadController: URLSessionDataDelegate
{
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data)
    {
//        NSLog("didReceiveData")
        self.uploadItem?.uploadReponseData.append(data)
        
        self.storeUploadItem()
    }
}


extension BXYouTubeUploadController: URLSessionDelegate
{
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession)
    {
        // Method is called on self.queue.
        
        self._notifyUploadStatusCompletionHandlers()
    }
}


//----------------------------------------------------------------------------------------------------------------------
