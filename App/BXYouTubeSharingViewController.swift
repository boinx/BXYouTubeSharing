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


class BXYouTubeSharingViewController : UIViewController, UIDocumentPickerDelegate, UIPickerViewDataSource, UIPickerViewDelegate
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
    @IBOutlet weak var openInYouTubeButton: UIButton!
    
	/// The URL of the selected file
	
	var fileURL:URL? = nil

	/// The list of YouTube categories
	
	var categories:[BXYouTubeUploadController.Category] = []
	{
		didSet { categoryPicker.reloadAllComponents() }
	}
	
	/// The list of YouTube privacy statuses
	
	var privacyStatuses:[BXYouTubeUploadController.Item.PrivacyStatus] = BXYouTubeUploadController.Item.PrivacyStatus.allCases
	
    var webURL: URL? = nil

//----------------------------------------------------------------------------------------------------------------------

	
	override func viewDidLoad()
	{
		super.viewDidLoad()
		
		self.progressView.progress = 0.0
		
		self.loadCategories()
        self.updateOpenInYouTubeButton()
  
        self.fileURL = Bundle.main.url(forResource: "movie", withExtension: "mov")
        self.shareButton.isEnabled = true
	}
 
    private func loadCategories()
    {
        BXYouTubeUploadController.shared.categories(for: "fr", completionHandler: { (categories, error) in
            if let error = error
            {
                print("error fetching categories \(error)")
            }
            else if !categories.isEmpty
            {
                self.categories = categories
            }
        })
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
		self.fileURL = urls.first
		self.didPickFile()
    }

	func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController)
	{
		self.fileURL = nil
		self.didPickFile()
	}

	func didPickFile()
	{
		self.urlField.text = fileURL?.path ?? "None Selected"
		self.shareButton.isEnabled = fileURL != nil
	}
 
    private func updateOpenInYouTubeButton()
    {
        self.openInYouTubeButton.isEnabled = (self.webURL != nil)
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

    @IBAction func login(_ sender: Any)
    {
        let controller = BXYouTubeAuthenticationController.shared!
        
        controller.delegate = self
        
        controller.login()
    }
    
    @IBAction func reset(_ sender: Any)
    {
        BXYouTubeAuthenticationController.shared!.reset()
    }
    
    @IBAction func openInYouTube(_ sender: Any)
    {
        if let url = self.webURL
        {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    /// Shares the selected file
	
	@IBAction func share(_ sender:Any!)
	{
		guard let url = fileURL else { return }
		let title = titleField.text ?? ""
		let description = descriptionField.text ?? ""
		let tags = (tagsField.text ?? "").components(separatedBy:",").map { $0.trimmingCharacters(in:CharacterSet.whitespaces) }
		let privacyIndex = privacyPicker.selectedRow(inComponent:0)
		let privacyStatus = self.privacyStatuses[privacyIndex]
		let categoryIndex = categoryPicker.selectedRow(inComponent:0)
		let categoryID = self.categories[categoryIndex].identifier

		let controller = BXYouTubeUploadController.shared
		controller.delegate = self

		let item = BXYouTubeUploadController.Item(
			fileURL:url,
			title:title,
			description:description,
			categoryID:categoryID,
			tags:tags,
			privacyStatus:privacyStatus)
   
        print("User clicked share button, request access token.")
		
        BXYouTubeAuthenticationController.shared!.requestAccessToken
        {
            (accessToken, error) in
            
            assert(error == nil, "\(error!)")
            
            print("Got access token, start upload")
            
            controller.accessToken = accessToken
            try! controller.upload(item)
        }
		
	}
 
    private var loginAlert: UIAlertController?
}

//----------------------------------------------------------------------------------------------------------------------



extension BXYouTubeSharingViewController: BXYouTubeAuthenticationControllerDelegate
{
    func youTubeAuthenticationControllerWillLogIn(_ authenticationController: BXYouTubeAuthenticationController)
    {
        if self.loginAlert != nil { return }
    
        let alert = UIAlertController(title: "Logging in with Safari", message: "Please complete the login process to YouTube in Safari.",  preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Go to Safari", style: .default, handler: { (action) in
            self.loginAlert = nil;
            BXYouTubeAuthenticationController.shared!.login()
        }))
    
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
            self.loginAlert = nil;
            alert.dismiss(animated: true, completion: nil)
        }))
    
        self.loginAlert = alert
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
        {
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func youTubeAuthenticationControllerDidLogIn(_ authenticationController: BXYouTubeAuthenticationController, error: BXYouTubeAuthenticationController.Error?)
    {
        self.loadCategories()
        
        self.loginAlert?.dismiss(animated: true, completion: {
            self.loginAlert = nil
            
            if let error = error
            {
                let errorAlert = UIAlertController(title: "Login Error", message: error.localizedDescription, preferredStyle: .alert)
                self.present(errorAlert, animated: true, completion: nil)
            }
        })
    }
}

extension BXYouTubeSharingViewController: BXYouTubeSharingDelegate
{
	func didStartUpload()
	{
        print("Did Start upload")
	}
 
    func didContinueUpload(progress: Progress)
    {
        self.progressView.observedProgress = progress
    }
	
	func didFinishUpload(url: URL?, error:Error?)
	{
        self.progressView.observedProgress = nil
        
        print("Did finish upload, url: \(url?.absoluteString ?? "(none)")")
        
        self.webURL = url
        
        self.updateOpenInYouTubeButton()
        
		if let error = error
		{
			print("Error: \(error)")
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------

