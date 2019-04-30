//
//  BXKeychain.swift
//  BXYouTubeSharing-Framework
//
//  Created by Stefan Fochler on 30.04.19.
//  Copyright © 2019 Boinx Software Ltd. & Imagine GbR. All rights reserved.
//

import Foundation
import Security

struct BXKeychain
{
    static func data(forKey identifier: String) -> Data?
    {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecAttrLabel as String: identifier,
                                    kSecReturnData as String: true]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        print("Loaded keychain data for identifier \(identifier) with result: \(self.stringForStatus(status))")
        
        return item as? Data
    }
    
    static func set(_ data: Data, forKey identifier: String)
    {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrLabel as String: identifier,
                                    kSecValueData as String: data as CFData]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        print("Wrote keychain data for identifier \(identifier) with result: \(self.stringForStatus(status))")
    }
    
    static private func stringForStatus(_ status: OSStatus) -> String
    {
        var statusString: String = "\(status)"
        
        if #available(iOS 11.3, *)
        {
            if let errorMessage = SecCopyErrorMessageString(status, nil)
            {
                statusString = errorMessage as String
            }
        }
        
        return statusString
    }
}
