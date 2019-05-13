//
//  AccessToken.swift
//  BXYouTubeSharing-Framework
//
//  Created by Stefan Fochler on 13.05.19.
//  Copyright © 2019 Boinx Software Ltd. & Imagine GbR. All rights reserved.
//

import Foundation


/// This struct holds the accessToken String and its expiration info

internal struct AccessToken: Codable
{
    let value: String
    let expirationDate: Date
    
    var isExpired: Bool
    {
        return Date() >= self.expirationDate.addingTimeInterval(-5 * 60)
    }
}
