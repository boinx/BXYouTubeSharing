//
//  DispatchQueue+backgroundQueue.swift
//  BXYouTubeSharing-Framework
//
//  Created by Stefan Fochler on 25.04.19.
//  Copyright © 2019 Boinx Software Ltd. & Imagine GbR. All rights reserved.
//

import Foundation

internal extension DispatchQueue
{
    static let background: DispatchQueue = DispatchQueue(label: "com.boinx.BXYouTubeSharing.genericWorkQueue", qos: .default, attributes: [.concurrent], autoreleaseFrequency: .inherit)
}
