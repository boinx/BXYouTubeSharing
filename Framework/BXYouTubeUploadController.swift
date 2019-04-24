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
	
	public weak var delegate:BXYouTubeSharingDelegate? = nil
	
	
//----------------------------------------------------------------------------------------------------------------------


	// MARK: -

	/// An Item specifies the movie file to be uploaded and the metadata that needs to be attached
	
	public struct Item : Codable
	{
		/// File to upload
		
		public var url:URL
		
		/// The video title
		
		public var title:String = ""

		/// The video description - this should also include any music credits
		
		public var description:String = ""
		
		/// The category identifier (valid identifiers need to be retrieved from YouTube)
		
		public var categoryID:String = ""
		
		/// An optional list of tags for the uploaded video
		
		public var tags:[String] = []
		
		/// The privacy level for the uploaded video
		
		public enum PrivacyStatus : String, Codable, CaseIterable
		{
			case `private`
			case `public`
			case unlisted
		}
		
		public var privacyStatus:PrivacyStatus = .private

		/// Specifies whether YouTube applies automatic color correction to the video
		
		public var autoLevels:Bool = false
		
		/// Specifies whether YouTube applies motion stabilization to the video
		
		public var stabilize:Bool = false
		
		/// Creates an Item struct
		
		public init(url:URL, title:String = "", description:String = "", categoryID:String = "", tags:[String] = [], privacyStatus:PrivacyStatus = .private, autoLevels:Bool = false, stabilize:Bool = false)
		{
			self.url = url
			self.title = title
			self.description = description
			self.categoryID = categoryID
			self.tags = tags
			self.privacyStatus = privacyStatus
			self.autoLevels = autoLevels
			self.stabilize = stabilize
		}
	}
	

//----------------------------------------------------------------------------------------------------------------------


	// MARK: -
	
	public struct Category
	{
		/// The localized name of the category (suitable for displaying in the user interface)
		
		public var localizedName:String = ""
		
		/// The unique identifier for a category
		
		public var identifier:String = ""
	}
	
	
	/// Retrieves the list of categories that are known to YouTube. Specify a language code like "en" or "de"
	/// to localize the names.
	
	public func categories(for languageCode:String, completionHandler: ([Category])->Void)
	{
		// TODO: implement

		let sample = Category(localizedName:"Reisen & Events", identifier:"19")
		completionHandler([sample])
	}
	

//----------------------------------------------------------------------------------------------------------------------


	// MARK: -
	
	public enum Error : Swift.Error
	{
		case invalidAccessToken
        case fileAccessError
        case userCanceled
        case uploadAlreadyInProgress
        case uploadFailed(reason: String)
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
	private var uploadURL: URL? = nil
	private var uploadTask: URLSessionUploadTask? = nil
    private var retryCount = 0


//----------------------------------------------------------------------------------------------------------------------


	// MARK: - Public API

	/// Starts the upload process
	
	public func upload(_ item:Item, notifySubscribers:Bool = true) throws
	{
        // FIXME: uploadItem can be modified from the background queue
        guard self.uploadItem == nil else
        {
            throw Error.uploadAlreadyInProgress
        }
 		guard let accessToken = self.accessToken else
        {
            throw Error.invalidAccessToken
        }
		guard let fileSize = item.url.fileSize else
        {
            throw Error.fileAccessError
        }
        
        self.uploadItem = item

		// Notify delegate that upload is about to start, so that UI can be updated.
		
        self.delegate?.onMainThread { $0.willStartUpload() }

        // TODO: Pass through notifySubscribers option
  
        let videoCreationRequest = BXYouTubeNetworkHelpers.videoCreationRequest(for: item, ofSize: fileSize, accessToken: accessToken)
  
        let creationTask = self.foregroundSession.dataTask(with: videoCreationRequest)
        {
        	[weak self] (data, response, error) in
			
            guard let self = self else { return }
            
            if let error = error
            {
                self._resetState()
                self.delegate?.onMainThread { $0.didFinishUpload(error: Error.other(underlyingError: error)) }
            }
            else if let httpResponse = response as? HTTPURLResponse
            {
                if httpResponse.statusCode == 200,
                   let uploadLocation = httpResponse.allHeaderFields["Location"] as? String,
                   let uploadURL = URL(string: uploadLocation)
                {
                    self.delegate?.onMainThread { $0.didStartUpload() }

                    self.uploadURL = uploadURL
                    self._startUploadTask()
                }
                else if let data = data,
                        let jsonObj = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any],
                        let errorObj = jsonObj["error"] as? [String: Any],
                        let errorMessage = errorObj["message"] as? String
                {
                    self._resetState()
                    self.delegate?.onMainThread { $0.didFinishUpload(error: Error.uploadFailed(reason: errorMessage)) }
                }
            }
            else
            {
                self._resetState()
                self.delegate?.onMainThread { $0.didFinishUpload(error: Error.other(underlyingError: nil)) }
            }
        }
        
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
            self.delegate?.onMainThread { $0.didFinishUpload(error: Error.userCanceled) }
        }
    }
	
 
    // MARK: - Internal Methods
	
	private func _startUploadTask()
	{
        assert(OperationQueue.current == self.queue, "BXYouTubeUploadController.\(#function) may only be called on self.queue")
 
        self.uploadTask = nil
 
		guard let accessToken = self.accessToken else { return }
		guard let item = self.uploadItem else { return }
		guard let fileSize = item.url.fileSize else { return }
		guard let uploadURL = self.uploadURL else { return }

        // Upload task may not be created on self.queue (which has a concurrency of 1 and therefore blocks).
        DispatchQueue.main.async
        {
            let uploadRequest = BXYouTubeNetworkHelpers.videoUploadRequest(for: item, ofSize: fileSize, location: uploadURL, accessToken: accessToken)
            let uploadTask = self.backgroundSession.uploadTask(with: uploadRequest, fromFile: item.url)
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
        // TODO: Map URLSession Error to our own Error type
		
		if let statusCode = (task.response as? HTTPURLResponse)?.statusCode,
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
                self.delegate?.onMainThread { $0.didFinishUpload(error: Error.uploadFailed(reason:"Too many retries!")) }
			}
		}
		
		// Everything finished successfully!
		
		else
		{
            self._resetState()
            self.delegate?.onMainThread { $0.didFinishUpload(error: nil) }
		}
		
    }
}


extension BXYouTubeUploadController: URLSessionDelegate
{
    // None of the regular URLSessionDelegate methods are implemented as we don't expect to need them.
}


//----------------------------------------------------------------------------------------------------------------------


// MARK: -

/// The BXYouTubeSharingDelegate notifies the client app of upload progress. All delegate calls are guaranteed
/// to be called on the main queue.

public protocol BXYouTubeSharingDelegate : BXMainThreadDelegate
{
	func willStartUpload()			// Called immediately, can be used to disable UI
	func didStartUpload()			// Called asynchronously once communication with YouTube is established
	func didContinueUpload(progress: Progress)
	func didFinishUpload(error: Error?)
}

public extension BXYouTubeSharingDelegate
{
	func willStartUpload() {}
	func didStartUpload() {}
	func didContinueUpload(progress: Progress) {}
	func didFinishUpload(error: Error?) {}
}


//----------------------------------------------------------------------------------------------------------------------
