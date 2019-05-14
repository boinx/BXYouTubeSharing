//
//  UploadItem.swift
//  BXYouTubeSharing-Framework
//
//  Created by Stefan Fochler on 13.05.19.
//  Copyright © 2019 Boinx Software Ltd. & Imagine GbR. All rights reserved.
//

import Foundation

/// An Item specifies the movie file to be uploaded and the metadata that needs to be attached

extension BXYouTubeUploadController
{
    public struct Item : Codable
    {
        /// File to upload
        
        public var fileURL:URL
        
        /// The video title
        
        public var title:String = ""

        /// The video description - this should also include any music credits
        
        public var description:String = ""
        
        /// The category identifier (valid identifiers need to be retrieved from YouTube)
        
        public var categoryID:String = ""
        
        /// An optional list of tags for the uploaded video
        
        public var tags:[String] = []
        
        /// The privacy level for the uploaded video
        
        public enum PrivacyStatus : String, Codable, CaseIterable
        {
            case `private`
            case `public`
            case unlisted
            
            #warning("TODO: return localized names")
            
            public var localizedName : String
            {
                return self.rawValue
            }
        }
        
        public var privacyStatus:PrivacyStatus = .private

        /// Specifies whether YouTube applies automatic color correction to the video
        
        public var autoLevels:Bool = false
        
        /// Specifies whether YouTube applies motion stabilization to the video
        
        public var stabilize:Bool = false


        internal var uploadReponseData: Data = Data()
        internal var webURL: URL? = nil
        internal var taskID: Int? = nil
        
        /// Creates an Item struct
        
        public init(fileURL:URL, title:String = "", description:String = "", categoryID:String = "", tags:[String] = [], privacyStatus:PrivacyStatus = .private, autoLevels:Bool = false, stabilize:Bool = false)
        {
            self.fileURL = fileURL
            self.title = title
            self.description = description
            self.categoryID = categoryID
            self.tags = tags
            self.privacyStatus = privacyStatus
            self.autoLevels = autoLevels
            self.stabilize = stabilize
        }
    }
}
