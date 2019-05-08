//**********************************************************************************************************************
//
//  BXYouTubeUploadController+PromiseKit.swift
//  Copyright ©2019 Boinx Software Ltd. & Imagine GbR. All rights reserved.
//
//**********************************************************************************************************************


#if canImport(PromiseKit)

import PromiseKit

public extension BXYouTubeUploadController
{

	/// Request an accessToken. This triggers the login process to YouTube if the accessToken was not yet available.
	/// An expired accessToken is automatically renewed if possible.
	/// - parameter languageCode: The category names are requested for a particular language like "en", "de", or "fr"
	/// - parameter maxRetries: The maximum number of retries before giving up in case there is a problem
	/// - returns: A list of Categories
	
	func categories(for languageCode:String, maxRetries: Int = 3) -> Promise<[Category]>
	{
		return Promise
		{
			seal in

			self.categories(for: languageCode, maxRetries: maxRetries)
			{
				(categories,error) in

				if let error = error
				{
					seal.reject(error)
				}
				else
				{
					seal.fulfill(categories)
				}
			}
		}
	}
	
}

#endif


//----------------------------------------------------------------------------------------------------------------------

