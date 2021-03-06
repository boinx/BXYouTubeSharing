//**********************************************************************************************************************
//
//  BXYouTubeSharingViewController.swift
//  Copyright © 2019 Peter Baumgartner. All rights reserved.
//
//**********************************************************************************************************************


import UIKit
import MobileCoreServices
import BXYouTubeSharing


//----------------------------------------------------------------------------------------------------------------------


class BXYouTubeSharingViewController : UIViewController,UIDocumentPickerDelegate,BXYouTubeSharingDelegate
{
	// Outlets
	
	@IBOutlet weak var shareButton:UIButton!
	@IBOutlet weak var urlLabel:UILabel!

	/// The URL of the selected file
	
	var url:URL? = nil

	/// This token identifies the upload
	
	var uploadToken:Any? = nil
	

//----------------------------------------------------------------------------------------------------------------------


	/// Selects a movie file
	
	@IBAction func selectFile(_ sender:Any!)
	{
		let picker = UIDocumentPickerViewController(documentTypes:[kUTTypeMovie as String], in:.import)
		picker.delegate = self
		self.present(picker, animated:true, completion:nil)
	}
	
	
	/// Store the URL of the selected file and enables the Share button
	
   	func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
    {
		self.url = urls.first
		self.updateUserInterface()
    }

	func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController)
	{
		self.url = nil
		self.updateUserInterface()
	}

	func updateUserInterface()
	{
		self.urlLabel.text = url?.path ?? "None Selected"
		self.shareButton.isEnabled = url != nil
	}


//----------------------------------------------------------------------------------------------------------------------


	/// Shares the selected file
	
	@IBAction func share(_ sender:Any!)
	{
		guard let url = url else { return }
		
		let controller = BXYouTubeSharingController.shared
		controller.delegate = self
		controller.currentViewController = self

		controller.credentials = BXYouTubeSharingController.Credentials(
			clientID:"UUID.apps.googleusercontent.com",
			clientSecret:"UUID",
			account:"johndoe",
			password:"•••••••")

		controller.item = BXYouTubeSharingController.Item(
			url:url,
			title:"My Slideshow",
			description:"Memories of my last vacation",
			categoryID:"Travel",
			isPrivate:false)
		
		controller.startUpload()
	}


//----------------------------------------------------------------------------------------------------------------------


	func didStartUpload(token:Any)
	{
		self.uploadToken = token
	}
	
	func didContinueUpload(token:Any,progress:Double)
	{
		// Display progress
	}
	
	func didFinishUpload(token:Any,error:Error?)
	{
		if let error = error
		{
			print("Error: \(error)")
		}
		
		self.uploadToken = nil
	}

}


//----------------------------------------------------------------------------------------------------------------------

