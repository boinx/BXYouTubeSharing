//
//  BXYouTubeNetworkHelpers.swift
//  BXYouTubeSharing-Framework
//
//  Created by Stefan Fochler on 12.04.19.
//  Copyright © 2019 Boinx Software Ltd. & Imagine GbR. All rights reserved.
//

import Foundation


internal class BXYouTubeNetworkHelpers
{
//    static var backgroundSession: URLSession =
//    {
//        let configuration = URLSessionConfiguration.background(withIdentifier: "com.boinx.BXYouTubeSharing.backgroundSession")
//        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
//    }()
    
    static let backgroundSessionIdentifier = "com.boinx.BXYouTubeSharing.backgroundSession"
    
    static func videoCreationRequest(for item: BXYouTubeUploadController.Item, ofSize fileSize: Int, accessToken: String) -> URLRequest
    {
        var urlComponents = URLComponents(string: "https://www.googleapis.com/upload/youtube/v3/videos")!
        
        urlComponents.queryItems = [
            URLQueryItem(name: "part", value: "snippet,status"),
            URLQueryItem(name: "uploadType", value: "resumable")
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
        
        // Set request headers for authentication and propper content types.
        request.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("\(fileSize)", forHTTPHeaderField: "Content-Length")
        
        return request
    }
}
