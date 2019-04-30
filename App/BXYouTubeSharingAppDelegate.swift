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
		return true
	}
 
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool
    {

        BXYouTubeAuthenticationController.shared = BXYouTubeAuthenticationController(clientID: clientID, clientSecret: "", redirectURI: redirectURI)
        
        return true
    }

	func applicationWillResignActive(_ application: UIApplication)
	{

	}

	func applicationDidEnterBackground(_ application: UIApplication)
	{

	}

	func applicationWillEnterForeground(_ application: UIApplication)
	{

	}

	func applicationDidBecomeActive(_ application: UIApplication)
	{

	}

	func applicationWillTerminate(_ application: UIApplication)
	{

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
}


//----------------------------------------------------------------------------------------------------------------------
