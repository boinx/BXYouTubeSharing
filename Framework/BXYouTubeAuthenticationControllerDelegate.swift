//
//  BXYouTubeAuthenticationControllerDelegate.swift
//  BXYouTubeSharing-Framework
//
//  Created by Stefan Fochler on 13.05.19.
//  Copyright © 2019 Boinx Software Ltd. & Imagine GbR. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------

public protocol BXYouTubeAuthenticationControllerDelegate: BXMainThreadDelegate
{
    func youTubeAuthenticationControllerWillLogIn(_ authenticationController: BXYouTubeAuthenticationController) -> Void
    func youTubeAuthenticationControllerDidLogIn(_ authenticationController: BXYouTubeAuthenticationController, error: BXYouTubeAuthenticationController.Error?) -> Void
    func youTubeAuthenticationControllerDidLogOut(_ authenticationController: BXYouTubeAuthenticationController) -> Void
}

public extension BXYouTubeAuthenticationControllerDelegate
{
    func youTubeAuthenticationControllerWillLogIn(_ authenticationController: BXYouTubeAuthenticationController) -> Void {}
    func youTubeAuthenticationControllerDidLogIn(_ authenticationController: BXYouTubeAuthenticationController, error: BXYouTubeAuthenticationController.Error?) -> Void {}
    func youTubeAuthenticationControllerDidLogOut(_ authenticationController: BXYouTubeAuthenticationController) -> Void {}
}
