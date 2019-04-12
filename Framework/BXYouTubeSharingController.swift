//**********************************************************************************************************************
//
//  BXYouTubeSharingAppDelegate.swift
//  Copyright © 2019 Peter Baumgartner. All rights reserved.
//
//**********************************************************************************************************************


import Foundation


//----------------------------------------------------------------------------------------------------------------------


public class BXYouTubeSharingController
{

	/// Convenience singleton instance of this controller
	
	public static let shared = BXYouTubeSharingController()
	
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
		
		public var url:URL? = nil
		
		/// The video title
		
		public var title:String = ""

		/// The video description - this should also include any music credits
		
		public var description:String = ""
		
		/// The category identifier (valid identifiers need to be retrieved from YouTube)
		
		public var categoryID:String = ""
		
		/// An optional list of tags for the uploaded video
		
		public var tags:[String] = []
		
		/// The privacy level for the uploaded video
		
		public enum PrivacyStatus : String,Codable
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
		
		public init(url:URL? = nil, title:String = "", description:String = "", categoryID:String = "", tags:[String] = [], privacyStatus:PrivacyStatus = .private, autoLevels:Bool = false, stabilize:Bool = false)
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

		completionHandler([])
	}
	

//----------------------------------------------------------------------------------------------------------------------


	// MARK: -
	
	enum Error : Swift.Error
	{
		case invalidAccessToken
		// ...
		case unknown
	}
	
	
//----------------------------------------------------------------------------------------------------------------------


	// MARK: -

	/// A unique identifier for an upload operation. Store it if you want to cancel the upload later.
	
	public typealias UploadID = String
	
	
	/// Starts the upload process
	
	@discardableResult public func upload(_ item:Item, notifySubscribers:Bool = true) -> UploadID?
	{
		guard let srcURL = item.url else { return nil }

		// TODO: implement

		return UUID().uuidString 
	}
	
	
	/// Cancels the upload with the specified UploadID
	
	public func cancelUpload(with identifier:UploadID)
	{
		// TODO: implement
	}
}


//----------------------------------------------------------------------------------------------------------------------


// MARK: -

/// The BXYouTubeSharingDelegate notifies the client app of upload progress

public protocol BXYouTubeSharingDelegate : class
{
	func didStartUpload(identifier: BXYouTubeSharingController.UploadID)
	func didContinueUpload(identifier: BXYouTubeSharingController.UploadID, progress:Double)
	func didFinishUpload(identifier: BXYouTubeSharingController.UploadID, error:Error?)
}

public extension BXYouTubeSharingDelegate
{
	func didStartUpload(identifier: BXYouTubeSharingController.UploadID) {}
	func didContinueUpload(identifier: BXYouTubeSharingController.UploadID, progress:Double) {}
	func didFinishUpload(identifier: BXYouTubeSharingController.UploadID, error:Error?) {}
}


//----------------------------------------------------------------------------------------------------------------------
