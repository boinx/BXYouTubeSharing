//**********************************************************************************************************************
//
//  BXYouTubeAuthenticationController.swift
//  Copyright ©2019 Boinx Software Ltd. & Imagine GbR. All rights reserved.
//
//**********************************************************************************************************************


import Foundation


//----------------------------------------------------------------------------------------------------------------------


public class BXYouTubeAuthenticationController
{
	/// Creates a new instance of this controller with the specified clientID/clientSecret uniquely identifying
	/// the host application.
	
	public init(clientID: String, clientSecret: String)
	{
		self.clientID = clientID
		self.clientSecret = clientSecret
	}
	
	private let clientID: String
	private let clientSecret: String


	/// Convenience singleton instance of this controller. It is not instantiated automatically, because
	/// its init() needs the clientID and clientSecret arguments, thich are unique to the host app.
	
//	public static let shared: BXYouTubeAuthenticationController
	

//----------------------------------------------------------------------------------------------------------------------


	/// The name of the logged in user
	
	public private(set) var user: String? = nil
	
	/// The password of the logged in user
	
	public private(set) var password: String? = nil
	
	/// The currently valid access token for the user/password
	
	public private(set) var accessToken: String? = nil


//----------------------------------------------------------------------------------------------------------------------


	/// Possible errors when trying to login to YouTube
	
	public enum Error : Swift.Error
	{
        case networkError
		case invalidCredentials
	}
	
	
//----------------------------------------------------------------------------------------------------------------------


	// MARK: -

	
	/// Requests a new accessToken for the specified user/password
	
	public func requestAccessToken(user: String, password: String, completionHandler: @escaping (String?,Error?)->Void)
	{
		DispatchQueue.main.async
		{
			self.user = user
			self.password = password
			self.accessToken = "bla"
		
			completionHandler(self.accessToken,nil)
		}
	}
	
	
	/// Renews the current accessToken to if its remaining lifetime is below the specific mimimum duration (in seconds)
	
	public func renewAccessToken(withLifetimeLessThan minLifetime: Double, completionHandler: @escaping (String?,Error?)->Void) throws
	{
		guard let user = self.user else { throw Error.invalidCredentials }
		guard let password = self.password else { throw Error.invalidCredentials }
		
		let remainingLifetime = 60.0
		
		if remainingLifetime < minLifetime
		{
			self.requestAccessToken(user:user, password:password, completionHandler:completionHandler)
		}
	}

}
	

//----------------------------------------------------------------------------------------------------------------------
