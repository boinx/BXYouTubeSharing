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
	
	enum Error : Swift.Error
	{
		case invalidAccessToken
        case fileAccessError
		// ...
		case unknownError
	}
	
	
//----------------------------------------------------------------------------------------------------------------------


	// MARK: -

	/// A unique identifier for an upload operation. Store it if you want to cancel the upload later.
	
	public typealias UploadID = String
	
    /**
     Mapping from URLSessionTask ids to our own upload IDs.
     NOTE: May only be accessed from self.queue to avoid race conditions!
     */
    fileprivate var currentUploadIDs: [Int: UploadID] = [:]
	
	/// Starts the upload process
	
	@discardableResult public func upload(_ item:Item, notifySubscribers:Bool = true) -> UploadID?
	{
		guard let fileSize = item.url.fileSize,
              let accessToken = self.accessToken
        else { return nil }
        
        let srcURL = item.url
  
        let uploadID = UUID().uuidString
  
        // TODO: Pass through notifySubscribers option
  
        let videoCreationRequest = BXYouTubeNetworkHelpers.videoCreationRequest(for: item, ofSize: fileSize, accessToken: accessToken)
  
        let creationTask = self.foregroundSession.dataTask(with: videoCreationRequest)
        { [weak self] (data, response, error) in
            if let self = self,
               let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let uploadLocation = httpResponse.allHeaderFields["Location"] as? String,
               let uploadURL = URL(string: uploadLocation)
            {            
                let videoUploadRequest = BXYouTubeNetworkHelpers.videoUploadRequest(for: item, ofSize: fileSize, location: uploadURL, accessToken: accessToken)
                let task = self.backgroundSession.uploadTask(with: videoUploadRequest, fromFile: srcURL)
                
                self.currentUploadIDs[task.taskIdentifier] = uploadID
                
                self.delegate?.didStartUpload(identifier: uploadID)
                
                task.resume()
            }
        }
        creationTask.resume()

		return uploadID
	}
	
	
	/// Cancels the upload with the specified UploadID
	
	public func cancelUpload(with identifier: UploadID)
	{
        self.queue.addOperation
        {
            guard let taskId = self.currentUploadIDs.first(where: { $0.value == identifier })?.key else { return }
        
            self.backgroundSession.getAllTasks()
            { tasks in
                tasks.first(where: { $0.taskIdentifier == taskId })?.cancel()
            }
        }
	}
 
    private lazy var queue: OperationQueue =
    {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
 
    private lazy var foregroundSession: URLSession =
    {
        return URLSession(configuration: .default, delegate: nil, delegateQueue: self.queue)
    }()
 
    private lazy var backgroundSession: URLSession =
    {
        let identifier = BXYouTubeNetworkHelpers.backgroundSessionIdentifier
        return URLSession(configuration: .background(withIdentifier: identifier), delegate: self, delegateQueue: self.queue)
    }()
}

extension BXYouTubeUploadController: URLSessionDelegate
{
    // None of the regular URLSessionDelegate methods are implemented as we don't expect to need them.
}

extension BXYouTubeUploadController: URLSessionTaskDelegate
{
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64)
    {
        guard let uploadID = self.currentUploadIDs[task.taskIdentifier] else { return }
        
        DispatchQueue.main.async
        { [weak self] in
            self?.delegate?.didContinueUpload(identifier: uploadID, progress: task.progress)
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Swift.Error?)
    {
        guard let uploadID = self.currentUploadIDs.removeValue(forKey: task.taskIdentifier) else { return }
        
        // TODO: Map URLSession Error to our own Error type
        
        DispatchQueue.main.async
        { [weak self] in
            self?.delegate?.didFinishUpload(identifier: uploadID, error: nil)
        }
        
    }
}


//----------------------------------------------------------------------------------------------------------------------


// MARK: -

/// The BXYouTubeSharingDelegate notifies the client app of upload progress

public protocol BXYouTubeSharingDelegate : class
{
	func didStartUpload(identifier: BXYouTubeUploadController.UploadID)
	func didContinueUpload(identifier: BXYouTubeUploadController.UploadID, progress:Progress)
	func didFinishUpload(identifier: BXYouTubeUploadController.UploadID, error:Error?)
}

public extension BXYouTubeSharingDelegate
{
	func didStartUpload(identifier: BXYouTubeUploadController.UploadID) {}
	func didContinueUpload(identifier: BXYouTubeUploadController.UploadID, progress:Progress) {}
	func didFinishUpload(identifier: BXYouTubeUploadController.UploadID, error:Error?) {}
}


//----------------------------------------------------------------------------------------------------------------------
