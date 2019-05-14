//**********************************************************************************************************************
//
//  BXYouTubeSharingAppDelegate.swift
//  Copyright © 2019 Boinx Software Ltd. & Imagine GbR. All rights reserved.
//
//**********************************************************************************************************************


import UIKit
import BXYouTubeSharing

//----------------------------------------------------------------------------------------------------------------------


@UIApplicationMain

class BXYouTubeSharingAppDelegate: UIResponder, UIApplicationDelegate
{
	var window: UIWindow?


	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
	{
        // Check upload status
        BXYouTubeUploadController.shared.checkUploadStatus
        {
            (result) in
            
            switch result
            {
            case .none:
                break
                
            case .failed(let uploadItem, let error):
                // Alert with error reason
                break
            
            case .completed(let uploadItem, let url):
                // Alert with open URL in browser button
                break
                
            case .progress(let uploadItem, let progress):
                // Modal upload progress
                break
            }
        }
		return true
	}
 
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool
    {
        let clientID = "70625101626-ip65lgpfgofvmuhdesmkafoosnosuura.apps.googleusercontent.com"
        let redirectURI = "com.googleusercontent.apps.70625101626-ip65lgpfgofvmuhdesmkafoosnosuura:/BXYouTubeSharing"

        BXYouTubeAuthenticationController.shared = BXYouTubeAuthenticationController(clientID: clientID, clientSecret: "", redirectURI: redirectURI)
        
        return true
    }

	func applicationWillResignActive(_ application: UIApplication)
	{
        print("Application will resign active")
	}

	func applicationDidEnterBackground(_ application: UIApplication)
	{
        print("Application did enter background")
	}

	func applicationWillEnterForeground(_ application: UIApplication)
	{
        print("Application will enter foreground")
	}

	func applicationDidBecomeActive(_ application: UIApplication)
	{
        print("Application did become active")
	}

	func applicationWillTerminate(_ application: UIApplication)
	{
        print("Application will terminate")
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
        // TODO: Decide if this is needed.
        BXYouTubeUploadController.shared.checkUploadStatus()
        {
            (result) in
            
            switch result
            {
            case .none:
                break
            
            case .failed(let uploadItem, let error):
                // Local notification
                break
            
            case .completed(let uploadItem, let url):
                // Local notification
                break
            
            case .progress(let uploadItem, let progress):
                // Ignore progress event (shouldn't happen anyway in handleEventsForBackgroundURLSession)
                break
            }
            
            completionHandler()
        }
    }
}


//----------------------------------------------------------------------------------------------------------------------
