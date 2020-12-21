//
//  BXYouTubeNetworkHelpers.swift
//  BXYouTubeSharing-Framework
//
//  Created by Stefan Fochler on 12.04.19.
//  Copyright © 2019 Boinx Software Ltd. & Imagine GbR. All rights reserved.
//

import Foundation


/// OAuth Request Parameters taken from https://tools.ietf.org/html/rfc6749
internal struct OAuthParams
{
    static let responseType = "response_type"
    static let clientID = "client_id"
    static let clientSecret = "client_secret"
    static let redirectURI = "redirect_uri"
    static let scope = "scope"
    static let state = "state"
    static let grantType = "grant_type"
    static let code = "code"
    static let refreshToken = "refresh_token"
    static let accessToken = "access_token"
}


internal class BXYouTubeNetworkHelpers
{
    static let backgroundSessionIdentifier = "com.boinx.BXYouTubeSharing.backgroundSession"
    
    
    // MARK: - Authentication
    
    static func authenticationURL(clientID: String, redirectURI: String, scope: String) -> URL?
    {
        var urlComponents = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        
        urlComponents.queryItems = [
            URLQueryItem(name: OAuthParams.responseType, value: "code"),
            URLQueryItem(name: OAuthParams.clientID, value: clientID),
            URLQueryItem(name: OAuthParams.redirectURI, value: redirectURI),
            URLQueryItem(name: OAuthParams.scope, value: scope)
        ]
        
        return urlComponents.url
    }
    
    static func accessTokenRequest(clientID: String, clientSecret: String? = nil, redirectURI: String, authCode: String) -> URLRequest
    {
        let url = URL(string: "https://www.googleapis.com/oauth2/v4/token")!
        var request = URLRequest(url: url)
        
        request.httpMethod = "POST"
        
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        var bodyObject: [String: Any] = [
            OAuthParams.grantType: "authorization_code",
            OAuthParams.clientID: clientID,
			OAuthParams.code: authCode,
            OAuthParams.redirectURI: redirectURI
       ]
        
        if let clientSecret = clientSecret
        {
			bodyObject[OAuthParams.clientSecret] = clientSecret
        }
        
        request.httpBody = try! JSONSerialization.data(withJSONObject: bodyObject, options: [])
        
        return request
    }
    
    static func refreshAccessTokenRequest(clientID: String, refreshToken: String) -> URLRequest
    {
        let url = URL(string: "https://www.googleapis.com/oauth2/v4/token")!
        var request = URLRequest(url: url)
        
        request.httpMethod = "POST"
        
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        let bodyObject: [String: Any] = [
            OAuthParams.grantType: "refresh_token",
            OAuthParams.clientID: clientID,
            OAuthParams.refreshToken: refreshToken
        ]
        request.httpBody = try! JSONSerialization.data(withJSONObject: bodyObject, options: [])
        
        return request
    }
    
    static func channelInfoRequest(accessToken: String) -> URLRequest
    {
        var urlComponents = URLComponents(string: "https://www.googleapis.com/youtube/v3/channels")!
        
        urlComponents.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "mine", value: "true")
        ]
        
        var request = URLRequest(url: urlComponents.url!)
        
        // Set request headers for authentication and propper content types.
        request.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        return request
    }
    
    
    // MARK: - Video Uploading
    
    static func videoCreationRequest(for item: BXYouTubeUploadController.Item, ofSize fileSize: Int, accessToken: String, notifySubscribers: Bool) -> URLRequest
    {
        var urlComponents = URLComponents(string: "https://www.googleapis.com/upload/youtube/v3/videos")!
        
        urlComponents.queryItems = [
            URLQueryItem(name: "part", value: "snippet,status"),
            URLQueryItem(name: "uploadType", value: "resumable"),
            // Using capitalized boolean values as described on https://developers.google.com/youtube/v3/docs/videos/insert
            URLQueryItem(name: "notifySubscribers", value: notifySubscribers ? "True" : "False")
        ]
        
        var request = URLRequest(url: urlComponents.url!)
        
        request.httpMethod = "POST"
        
        // Set request headers for authentication and propper content types.
        request.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("\(fileSize)", forHTTPHeaderField: "X-Upload-Content-Length")
        request.setValue("application/octet-stream", forHTTPHeaderField: "X-Upload-Content-Type")
        
        // Set request body containing the item's metadata
        let body = [
            "snippet": [
                "title": item.title,
                "description": item.description,
                "tags": item.tags,
                "categoryId": item.categoryID
            ],
            "status": [
                "privacyStatus": item.privacyStatus.rawValue
            ]
        ]
        request.httpBody = try! JSONSerialization.data(withJSONObject: body, options: [])
        
        return request
    }
    
    static func videoUploadRequest(for item: BXYouTubeUploadController.Item, ofSize fileSize: Int, location: URL, accessToken: String) -> URLRequest
    {
        var request = URLRequest(url: location)
        
        request.httpMethod = "PUT"
        
        // Set request headers for authentication and propper content types.
        request.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("\(fileSize)", forHTTPHeaderField: "Content-Length")
        
        return request
    }
    
    
    // MARK: - Read-only API Access
    
    static func categoriesRequest(languageCode: String, accessToken: String) -> URLRequest
    {
        var urlComponents = URLComponents(string: "https://www.googleapis.com/youtube/v3/videoCategories")!
        
        urlComponents.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "regionCode", value: Locale.current.regionCode),
            URLQueryItem(name: "hl", value: languageCode)
        ]
        
        var request = URLRequest(url: urlComponents.url!)
        
        // Set request headers for authentication and propper content types.
        request.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        return request
    }
}
