//**********************************************************************************************************************
//
//  BXYouTubeAuthenticationController+PromiseKit.swift
//  Copyright ©2019 Boinx Software Ltd. & Imagine GbR. All rights reserved.
//
//**********************************************************************************************************************


#if canImport(PromiseKit)

import PromiseKit

public extension BXYouTubeAuthenticationController
{

	/// Request an accessToken. This triggers the login process to YouTube if the accessToken was not yet available.
	/// An expired accessToken is automatically renewed if possible.
	
	func accessToken() -> Promise<String>
	{
		return Promise
		{
			seal in

			self.requestAccessToken()
			{
				(accessToken,error) in

				if let error = error
				{
					seal.reject(error)
				}
				else if let accessToken = accessToken
				{
					seal.fulfill(accessToken)
				}
				else
				{
					seal.reject(BXYouTubeAuthenticationController.Error.notLoggedIn)
				}
			}
		}
	}
	
	
	/// Requests the account info for the currently logged in user.
	
	func accountInfo() -> Promise<AccountInfo>
    {
		return Promise
		{
			seal in

			self.requestAccountInfo()
			{
				(accountInfo,error) in

				if let error = error
				{
					seal.reject(error)
				}
				else if let accountInfo = accountInfo
				{
					seal.fulfill(accountInfo)
				}
				else
				{
					seal.reject(BXYouTubeAuthenticationController.Error.notLoggedIn)
				}
			}
		}
    }

}

#endif


//----------------------------------------------------------------------------------------------------------------------

