//
//  BXYouTubeUploadControllerDelegate.swift
//  BXYouTubeSharing-Framework
//
//  Created by Stefan Fochler on 13.05.19.
//  Copyright © 2019 Boinx Software Ltd. & Imagine GbR. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------

/// The BXYouTubeUploadControllerDelegate notifies the client app of upload progress. All delegate calls are guaranteed
/// to be called on the main queue.

public protocol BXYouTubeUploadControllerDelegate : BXMainThreadDelegate
{
    func willStartUpload()            // Called immediately, can be used to disable UI
    func didStartUpload()            // Called asynchronously once communication with YouTube is established
    func didContinueUpload(progress: Float)
    func didFinishUpload(url: URL?, error: BXYouTubeUploadController.Error?)
}

public extension BXYouTubeUploadControllerDelegate
{
    func willStartUpload() {}
    func didStartUpload() {}
    func didContinueUpload(progress: Float) {}
    func didFinishUpload(url: URL?, error: BXYouTubeUploadController.Error?) {}
}
