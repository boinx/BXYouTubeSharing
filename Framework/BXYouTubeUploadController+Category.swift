//
//  Category.swift
//  BXYouTubeSharing-Framework
//
//  Created by Stefan Fochler on 13.05.19.
//  Copyright © 2019 Boinx Software Ltd. & Imagine GbR. All rights reserved.
//

import Foundation

extension BXYouTubeUploadController
{
    public struct Category
    {
        /// The localized name of the category (suitable for displaying in the user interface)

        public let localizedName: String

        /// The unique identifier for a category

        public let identifier: String

        public let assignable: Bool

        init(localizedName: String, identifier: String, assignable: Bool)
        {
            self.localizedName = localizedName
            self.identifier = identifier
            self.assignable = assignable
        }

        /**
         Sample dict:
     
         {
            "snippet": {
                "assignable": true,
                "channelId": "UCBR8-60-B28hp2BmDPdntcQ",
                "title": "Film & Animation"
            },
            "kind": "youtube#videoCategory",
            "etag": "\"XpPGQXPnxQJhLgs6enD_n8JR4Qk/Xy1mB4_yLrHy_BmKmPBggty2mZQ\"",
            "id": "1"
         }
        */
        init?(withResponse dict: [String: Any])
        {
            guard let id = dict["id"] as? String,
                  let snippet = dict["snippet"] as? [String: Any],
                  let title = snippet["title"] as? String,
                  let assignable = snippet["assignable"] as? Bool
            else { return nil }
            
            self.init(localizedName: title, identifier: id, assignable: assignable)
        }
    }
}
