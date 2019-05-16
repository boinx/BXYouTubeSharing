//**********************************************************************************************************************
//
//  BXYouTubeSharingAppDelegate.swift
//  Copyright © 2019 Boinx Software Ltd. & Imagine GbR. All rights reserved.
//
//**********************************************************************************************************************


import UIKit
import BXYouTubeSharing
import UserNotifications

//----------------------------------------------------------------------------------------------------------------------


fileprivate extension UIApplication
{
    var rootViewController: UIViewController?
    {
        return self.keyWindow?.rootViewController
    }
}

@UIApplicationMain

class BXYouTubeSharingAppDelegate: UIResponder, UIApplicationDelegate
{
	var window: UIWindow?


	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
	{
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { (success, error) in
            if let error = error
            {
                print("Error requesting notification permissions: \(error.localizedDescription)")
            }
        }
        
        NSLog("AppDelegate: didFinishLaunchingWithOptions")
 
        // Check upload status
        BXYouTubeUploadController.shared.checkUploadStatus()
        {
            (result) in
            
            NSLog("Returned from didFinishLaunching...checkUploadStatus with result=\(String(describing: result)).")
            
            switch result
            {
            case .none:
                break
                
            case .failed(let uploadItem, let error)?:
                // Alert with error reason
                
                NSLog("didFinishLaunchingWithOptions, upload failed")
                
                let alert = UIAlertController(title: "Upload of \(uploadItem.title) failed", message: "Upload failed with reason: \(error.localizedDescription)", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                application.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
                
                break
            
            case .completed(let uploadItem, let url)?:
                // Alert with open URL in browser button
                
                NSLog("didFinishLaunchingWithOptions, upload completed")
                
                let alert = UIAlertController(title: "Upload of \(uploadItem.title) completed", message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                alert.addAction(UIAlertAction(title: "Open in YouTube", style: .default, handler: { _ in
                    application.open(url, options: [:], completionHandler: nil)
                }))
                application.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
                
                break
                
            case .progress(let uploadItem, let progress)?:
                // Modal upload progress
                
                NSLog("didFinishLaunchingWithOptions, upload in progress")
                
                let alert = UIAlertController(title: "Upload of \(uploadItem.title) at \(Int(progress.fractionCompleted * 100))%, come back later.", message: nil, preferredStyle: .alert)
                // NOTE: Generally, this would not be dismissable, but it is for the sake of usability of this demo app.
                alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                application.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
                
                break
            }
        }
		return true
	}
 
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool
    {
        let clientID = "70625101626-ip65lgpfgofvmuhdesmkafoosnosuura.apps.googleusercontent.com"
        let redirectURI = "com.googleusercontent.apps.70625101626-ip65lgpfgofvmuhdesmkafoosnosuura:/BXYouTubeSharing"

        BXYouTubeAuthenticationController.shared = BXYouTubeAuthenticationController(clientID: clientID, redirectURI: redirectURI)
        
        return true
    }

	func applicationWillResignActive(_ application: UIApplication)
	{
        NSLog("Application will resign active")
	}

	func applicationDidEnterBackground(_ application: UIApplication)
	{
        NSLog("Application did enter background")
	}

	func applicationWillEnterForeground(_ application: UIApplication)
	{
        NSLog("Application will enter foreground")
	}

	func applicationDidBecomeActive(_ application: UIApplication)
	{
        NSLog("Application did become active")
	}

	func applicationWillTerminate(_ application: UIApplication)
	{
        NSLog("Application will terminate")
	}
 
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool
    {
        if BXYouTubeAuthenticationController.shared?.handleOAuthResponse(returnURL: url) ?? false
        {
            return true
        }
        
        // Perform own URL handlers
        
        return false
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void)
    {
        NSLog("AppDelegate: handleEventsForBackgroundURLSession")
        
        BXYouTubeUploadController.shared.checkUploadStatus()
        {
            (result) in
            
            NSLog("Returned from handleEventsForBackgroundURLSession...checkUploadStatus with result=\(String(describing: result))")
            
            switch result
            {
            case .failed(let uploadItem, let error)?:
                // Local notification
                
                NSLog("handleEventsForBackgroundURLSession, upload failed")
                
                let content = UNMutableNotificationContent()
                content.title = "Uploading \"\(uploadItem.title)\" to YouTube failed!"
                content.subtitle = "Subtitle"
                content.body = "Body"
                let notificationRequest = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(notificationRequest, withCompletionHandler: nil)
                
                break
            
            case .completed(let uploadItem, let url)?:
                // Local notification
                
                NSLog("handleEventsForBackgroundURLSession, upload failed")
                
                let content = UNMutableNotificationContent()
                content.title = "Uploading \"\(uploadItem.title)\" to YouTube succeeded!"
                content.subtitle = "Subtitle"
                content.body = "Body"
                let notificationRequest = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(notificationRequest, withCompletionHandler: nil)
                
                break
            
            default:
                break
            }
            
            completionHandler()
        }
    }
}


//----------------------------------------------------------------------------------------------------------------------
