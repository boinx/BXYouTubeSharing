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
    static func data(forKey identifier:String) -> Data?
    {
        let query: [String:Any] =
        [
			kSecClass as String: kSecClassGenericPassword,
			kSecMatchLimit as String: kSecMatchLimitOne,
			kSecAttrAccount as String: identifier,
			kSecReturnData as String: true
		]
        
        var item: CFTypeRef? = nil
        let _ = SecItemCopyMatching(query as CFDictionary, &item)
        return item as? Data
    }
    
    static func set(_ data:Data, forKey identifier:String, name:String? = nil)
    {
        var updateQuery:[String:Any] =
        [
			kSecClass as String: kSecClassGenericPassword,
        	kSecAttrAccount as String: identifier
		]
        
        if let name = name
        {
			updateQuery[kSecAttrComment as String] = name
//			updateQuery[kSecAttrLabel as String] = name
        }
        
        var status = SecItemUpdate(updateQuery as CFDictionary, [kSecValueData as String: data as CFData] as CFDictionary)
        var actionPerformed = "Updated"
        
        if status == errSecItemNotFound
        {
            var addQuery:[String:Any] =
            [
				kSecClass as String: kSecClassGenericPassword,
				kSecAttrAccount as String: identifier,
				kSecValueData as String: data as CFData
			]
            
			if let name = name
			{
				addQuery[kSecAttrComment as String] = name
				addQuery[kSecAttrLabel as String] = name
			}
			
            status = SecItemAdd(addQuery as CFDictionary, nil)
            actionPerformed = "Added"
        }
		
        if status != noErr
        {
        	print("\(actionPerformed) keychain data for identifier \(identifier) with result: \(self.stringForStatus(status))")
		}
    }
    
    static func deleteData(forKey identifier: String)
    {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: identifier]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != noErr
        {
        	print("Deleted keychain data for identifier \(identifier) with result: \(self.stringForStatus(status))")
		}
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
