//
//  URL+fileSize.swift
//  BXYouTubeSharing-Framework
//
//  Created by Stefan Fochler on 12.04.19.
//  Copyright © 2019 Boinx Software Ltd. & Imagine GbR. All rights reserved.
//

import Foundation

internal extension URL
{
    var fileSize: Int?
    {
        if let attributes = try? self.resourceValues(forKeys: [.fileSizeKey])
        {
            return attributes.fileSize
        }
        return nil
    }
}
