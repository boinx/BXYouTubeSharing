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
    {
        didSet
        {
            if self.delegate == nil { return }
            
            // (Re-)create the background URLSession to receive updates about running upload tasks on the delegate queue.
            let _ = self.backgroundSession
            
            self.backgroundSession.getTasksWithCompletionHandler
            { (_, uploadTasks, _) in
                if let uploadTask = uploadTasks.first(where: { $0.taskIdentifier == self.uploadItem?.taskID })
                {
                    // TODO: Pass uploadItem to delegate
                    self.delegate?.onMainThread { $0.didContinueUpload(progress: uploadTask.progress) }
                }
            }
        }
    }
	
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
            let identifier = BXYouTubeNetworkHelpers.backgroundSessionIdentifier
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
    }
	private var uploadURL: URL? = nil
	private var uploadTask: URLSessionUploadTask? = nil
    private var retryCount = 0

    private func restoreUploadItem()
    {
        let identifier = BXYouTubeNetworkHelpers.backgroundSessionIdentifier
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
        
        creationTask.resume()
	}
 
 
    /// Cancels the upload
    
    public func cancel()
    {
        self.queue.addOperation
        {
            [weak self] in
            
            guard let self = self else { return }
            
            self.uploadTask?.cancel()

            self._resetState()
            self.delegate?.onMainThread { $0.didFinishUpload(url: nil, error: Error.userCanceled) }
        }
    }
	
 
    // MARK: - Internal Methods
	
	private func _startUploadTask()
	{
        assert(OperationQueue.current == self.queue, "BXYouTubeUploadController.\(#function) may only be called on self.queue")
 
        self.uploadTask = nil
 
		guard let accessToken = self.accessToken else { return }
		guard let item = self.uploadItem else { return }
		guard let fileSize = item.fileURL.fileSize else { return }
		guard let uploadURL = self.uploadURL else { return }

        // Upload task may not be created on self.queue (which has a concurrency of 1 and therefore blocks).
        DispatchQueue.background.async
        {
            let uploadRequest = BXYouTubeNetworkHelpers.videoUploadRequest(for: item, ofSize: fileSize, location: uploadURL, accessToken: accessToken)
            let uploadTask = self.backgroundSession.uploadTask(with: uploadRequest, fromFile: item.fileURL)
            uploadTask.resume()
            
            self.queue.addOperation
            {
                self.uploadTask = uploadTask
            }
        }
	}
 
    private func _resetState()
    {
        assert(OperationQueue.current == self.queue, "BXYouTubeUploadController.\(#function) may only be called on self.queue")
        
        self.retryCount = 0
        self.uploadItem = nil
        self.uploadURL = nil
        self.uploadTask = nil
    }
    
}


//----------------------------------------------------------------------------------------------------------------------


// MARK: - URLSessionTaskDelegate

extension BXYouTubeUploadController: URLSessionTaskDelegate
{
	// Notify our client of the upload progress
	
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64)
    {
        self.delegate?.onMainThread { $0.didContinueUpload(progress: task.progress) }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Swift.Error?)
    {
		if let error = error
        {
            self._resetState()
            self.delegate?.onMainThread { $0.didFinishUpload(url: nil, error: Error.other(underlyingError: error)) }
        }
		else if let statusCode = (task.response as? HTTPURLResponse)?.statusCode,
			    statusCode == 500 || statusCode == 502 || statusCode == 503 || statusCode == 504
		{
			// If we failed to start the upload, then retry a limited number of times,
			// each time backing off a little bit longer
			
			if self.retryCount < 5 && self.uploadItem != nil
			{
				let delay = pow(2,Double(retryCount))
				self.retryCount += 1

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
                self._resetState()
                self.delegate?.onMainThread { $0.didFinishUpload(url: nil, error: Error.youTubeAPIError(reason:"Too many retries!")) }
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
                url = URL(string: "https://www.youtube.com/watch?v=\(videoId)")
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
        self.uploadItem?.uploadReponseData.append(data)
    }
}


extension BXYouTubeUploadController: URLSessionDelegate
{
    // None of the regular URLSessionDelegate methods are implemented as we don't expect to need them.
}


//----------------------------------------------------------------------------------------------------------------------
