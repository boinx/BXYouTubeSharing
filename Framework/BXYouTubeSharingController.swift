//**********************************************************************************************************************
//
//  BXYouTubeSharingAppDelegate.swift
//  Copyright © 2019 Peter Baumgartner. All rights reserved.
//
//**********************************************************************************************************************


import Foundation
#if os(iOS)
import UIKit
#endif


//----------------------------------------------------------------------------------------------------------------------


public class BXYouTubeSharingController
{

	/// The Credential identify both the host application and the user.
	///
	/// Without this info uploading to YouTube is not possible. More info at:
	/// https://developers.google.com/youtube/v3/
	/// http://www.codingtofu.com/post/68053276589/posting-video-to-youtube

	public struct Credentials : Codable
	{
		/// Host application identifier
		
		public var clientID:String = ""
		
		/// Host application secret
		
		public var clientSecret:String = ""
		
		/// User account
		
		public var account:String = ""
		
		/// User password
		
		public var password:String = ""
		
		/// Creates a Credentials struct
		
		public init(clientID:String = "", clientSecret:String = "", account:String = "", password:String = "")
		{
			self.clientID = clientID
			self.clientSecret = clientSecret
			self.account = account
			self.password = password
		}
	}
	
	public var credentials = Credentials()


//----------------------------------------------------------------------------------------------------------------------


	/// An Item specifies the movie file to be uploaded and the metadata that needs to be attached
	
	public struct Item : Codable
	{
		// File to upload
		
		public var url:URL? = nil
		
		// The video title
		
		public var title:String = ""

		// The video description - this should also include any music credits
		
		public var description:String = ""
		
		// The category identifier (valid identifiers need to be retrieved from YouTube)
		
		public var categoryID:String = ""
		
		// Set to true if this video should only be visible to the logged in user
		
		public var isPrivate:Bool = false

		/// Creates an Item struct
		
		public init(url:URL? = nil, title:String = "", description:String = "", categoryID:String = "", isPrivate:Bool = false)
		{
			self.url = url
			self.title = title
			self.description = description
			self.categoryID = categoryID
			self.isPrivate = isPrivate
		}
	}
	
	public var item = Item()
	

//----------------------------------------------------------------------------------------------------------------------


	// A singleton instance of this controller
	
	public static let shared = BXYouTubeSharingController()
	
	// Delegate for UI feedback
	
	public weak var delegate:BXYouTubeSharingDelegate? = nil
	
	// Optionally set a reference to the current UIViewController
	
	public weak var currentViewController:UIViewController? = nil
	
	
//----------------------------------------------------------------------------------------------------------------------


	// Starts the upload process
	
	@discardableResult public func startUpload() -> Any?
	{
		guard let srcURL = self.item.url else { return nil }

		// This is just a temporary dummy implementation (delete later)
		
		let controller = UIDocumentPickerViewController(urls:[srcURL], in:.moveToService)
		controller.allowsMultipleSelection = false
		currentViewController?.present(controller,animated:true, completion:nil)
		
		// TODO: implement

		return UUID().uuidString
	}
	
	public func cancelUpload(token:Any)
	{
		// TODO: implement
	}
}


//----------------------------------------------------------------------------------------------------------------------


/// The BXYouTubeSharingDelegate notifies the client app of upload progress

public protocol BXYouTubeSharingDelegate : class
{
	func didStartUpload(token:Any)
	func didContinueUpload(token:Any,progress:Double)
	func didFinishUpload(token:Any,error:Error?)
}

public extension BXYouTubeSharingDelegate
{
	func didStartUpload(token:Any) {}
	func didContinueUpload(token:Any,progress:Double) {}
	func didFinishUpload(token:Any,error:Error?) {}
}


//----------------------------------------------------------------------------------------------------------------------
