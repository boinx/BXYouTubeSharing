//**********************************************************************************************************************
//
//  BXYouTubeUploadController.swift
//  Copyright © 2019 Boinx Software Ltd. & Imagine GbR. All rights reserved.
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


	// MARK: -

	/// Starts the upload process
	
	public func upload(_ item:Item, notifySubscribers:Bool = true)
	{
 		guard let accessToken = self.accessToken else { return }
		guard let fileSize = item.url.fileSize else { return }

		// Notifiy delegate that upload is about to start, so that UI can be updated
		
		self.delegate?.willStartUpload()

        // TODO: Pass through notifySubscribers option
  
        let videoCreationRequest = BXYouTubeNetworkHelpers.videoCreationRequest(for: item, ofSize: fileSize, accessToken: accessToken)
  
        let creationTask = self.foregroundSession.dataTask(with: videoCreationRequest)
        {
        	[weak self] (data, response, error) in
			
            if let self = self,
               let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let uploadLocation = httpResponse.allHeaderFields["Location"] as? String,
               let uploadURL = URL(string: uploadLocation)
            {
            	DispatchQueue.main.async { self.delegate?.didStartUpload() }

				self.uploadItem = item
				self.uploadURL = uploadURL
				self.uploadTask = self.startUploadTask()
            }
        }
		
        creationTask.resume()
	}
	
	
	private func startUploadTask() -> URLSessionUploadTask?
	{
		guard let accessToken = self.accessToken else { return nil }
		guard let item = self.uploadItem else { return nil }
		guard let fileSize = item.url.fileSize else { return nil }
		guard let uploadURL = self.uploadURL else { return nil }

		let videoUploadRequest = BXYouTubeNetworkHelpers.videoUploadRequest(for: item, ofSize: fileSize, location:uploadURL, accessToken: accessToken)
		let uploadTask = self.backgroundSession.uploadTask(with: videoUploadRequest, fromFile: item.url)
		uploadTask.resume()

		return uploadTask
	}
	
	
//----------------------------------------------------------------------------------------------------------------------


	/// Cancels the upload
	
	public func cancel()
	{
		self.uploadTask?.cancel()

		self.retryCount = 0
		self.uploadItem = nil
		self.uploadURL = nil
		self.uploadTask = nil

		self.delegate?.didFinishUpload(error: BXYouTubeUploadController.Error.userCanceled)
	}
}


//----------------------------------------------------------------------------------------------------------------------


extension BXYouTubeUploadController: URLSessionDelegate
{
    // None of the regular URLSessionDelegate methods are implemented as we don't expect to need them.
}


extension BXYouTubeUploadController: URLSessionTaskDelegate
{
	// Notify our client of the upload progress
	
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64)
    {
        DispatchQueue.main.async
        {
        	[weak self] in
            self?.delegate?.didContinueUpload(progress: task.progress)
        }
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
					self?.uploadTask = self?.startUploadTask()
				}
			}
			
			// After a certain number of retries we finally give up
			
			else
			{
				DispatchQueue.main.async
				{
					[weak self] in
					
					let error = BXYouTubeUploadController.Error.uploadFailed(reason:"Too many retries!")
					self?.delegate?.didFinishUpload(error: error)

					self?.uploadItem = nil
					self?.uploadURL = nil
					self?.uploadTask = nil
				}
			}
		}
		
		// Everything finished successfully!
		
		else
		{
			DispatchQueue.main.async
			{
				[weak self] in
				
				self?.delegate?.didFinishUpload(error: nil)

				self?.uploadItem = nil
				self?.uploadURL = nil
				self?.uploadTask = nil
			}
		}
		
    }
}


//----------------------------------------------------------------------------------------------------------------------


// MARK: -

/// The BXYouTubeSharingDelegate notifies the client app of upload progress. All delegate calls are guaranteed
/// to be called on the main queue.

public protocol BXYouTubeSharingDelegate : class
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
