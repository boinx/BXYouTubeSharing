//**********************************************************************************************************************
//
//  BXYouTubeSharingViewController.swift
//  Copyright © 2019 Boinx Software Ltd. & Imagine GbR. All rights reserved.
//
//**********************************************************************************************************************


import UIKit
import MobileCoreServices
import BXYouTubeSharing


//----------------------------------------------------------------------------------------------------------------------


class BXYouTubeSharingViewController : UIViewController,UIDocumentPickerDelegate,BXYouTubeSharingDelegate,UIPickerViewDataSource,UIPickerViewDelegate
{
	// Outlets
	
	@IBOutlet weak var selectFileButton:UIButton!
	@IBOutlet weak var urlField:UITextField!
	@IBOutlet weak var titleField:UITextField!
	@IBOutlet weak var descriptionField:UITextView!
	@IBOutlet weak var tagsField:UITextField!
	@IBOutlet weak var categoryPicker:UIPickerView!
	@IBOutlet weak var privacyPicker:UIPickerView!
	@IBOutlet weak var shareButton:UIButton!
	@IBOutlet weak var progressView:UIProgressView!

	/// The URL of the selected file
	
	var url:URL? = nil

	/// The list of YouTube categories
	
	var categories:[BXYouTubeUploadController.Category] = []
	{
		didSet { categoryPicker.reloadAllComponents() }
	}
	
	/// The list of YouTube privacy statuses
	
	var privacyStatuses:[BXYouTubeUploadController.Item.PrivacyStatus] = BXYouTubeUploadController.Item.PrivacyStatus.allCases
	
	/// This token identifies the upload
	
	var uploadID: BXYouTubeUploadController.UploadID? = nil
	

//----------------------------------------------------------------------------------------------------------------------

	
	override func viewDidLoad()
	{
		super.viewDidLoad()
		
		self.progressView.progress = 0.0
		
		BXYouTubeUploadController.shared.categories(for:"en")
		{
			categories in
			self.categories = categories
		}
	}


//----------------------------------------------------------------------------------------------------------------------


	/// Selects a movie file
	
	@IBAction func selectFile(_ sender:Any!)
	{
		let picker = UIDocumentPickerViewController(documentTypes:[kUTTypeMovie as String], in:.import)
		picker.delegate = self
		self.present(picker, animated:true, completion:nil)
	}
	
	
	/// Stores the URL of the selected file and enables the Share button
	
   	func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
    {
		self.url = urls.first
		self.didPickFile()
    }

	func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController)
	{
		self.url = nil
		self.didPickFile()
	}

	func didPickFile()
	{
		self.urlField.text = url?.path ?? "None Selected"
		self.shareButton.isEnabled = url != nil
	}


//----------------------------------------------------------------------------------------------------------------------


    func numberOfComponents(in pickerView: UIPickerView) -> Int
    {
		return 1
    }

	func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int
	{
		if pickerView === categoryPicker
		{
			return self.categories.count
		}
		else if pickerView === privacyPicker
		{
			return 3
		}
		
		return 0
	}
	
   func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String?
   {
		if pickerView === categoryPicker
		{
			return self.categories[row].localizedName
		}
		else if pickerView === privacyPicker
		{
			return self.privacyStatuses[row].rawValue
		}
	
		return nil
   }
	

//----------------------------------------------------------------------------------------------------------------------


	/// Shares the selected file
	
	@IBAction func share(_ sender:Any!)
	{
		guard let url = url else { return }
		let title = titleField.text ?? ""
		let description = descriptionField.text ?? ""
		let tags = (tagsField.text ?? "").components(separatedBy:",").map { $0.trimmingCharacters(in:CharacterSet.whitespaces) }
		let privacyIndex = privacyPicker.selectedRow(inComponent:0)
		let privacyStatus = self.privacyStatuses[privacyIndex]
		let categoryIndex = categoryPicker.selectedRow(inComponent:0)
		let categoryID = self.categories[categoryIndex].identifier

		let controller = BXYouTubeUploadController.shared
		controller.accessToken = "•••••••••••••••••••••••••••"
		controller.delegate = self

		let item = BXYouTubeUploadController.Item(
			url:url,
			title:title,
			description:description,
			categoryID:categoryID,
			tags:tags,
			privacyStatus:privacyStatus)
		
		self.uploadID = controller.upload(item)
	}


//----------------------------------------------------------------------------------------------------------------------


	func didStartUpload(identifier: BXYouTubeUploadController.UploadID)
	{

	}
	
	func didContinueUpload(identifier: BXYouTubeUploadController.UploadID, progress:Double)
	{
		self.progressView.progress = Float(progress)
	}
	
	func didFinishUpload(identifier: BXYouTubeUploadController.UploadID, error:Error?)
	{
		if let error = error
		{
			print("Error: \(error)")
		}
		
		self.uploadID = nil
	}

}


//----------------------------------------------------------------------------------------------------------------------

