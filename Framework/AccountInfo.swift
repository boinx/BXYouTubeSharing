//
//  AccountInfo.swift
//  BXYouTubeSharing-Framework
//
//  Created by Stefan Fochler on 13.05.19.
//  Copyright © 2019 Boinx Software Ltd. & Imagine GbR. All rights reserved.
//

import Foundation

public struct AccountInfo
{
    public let identifier: String
    public let name: String
    public let url: URL

    init(identifier: String, name: String, url: URL)
    {
        self.identifier = identifier
        self.name = name
        self.url = url
    }

    /**
     Sample dict:
 
     {
      "kind": "youtube#channel",
      "etag": "\"XpPGQXPnxQJhLgs6enD_n8JR4Qk/AaGabVLbNTUeguA4YaJDTwKdKv4\"",
      "id": "UC4erAZFCJ_PLjf2bbYsvbFg",
      "snippet": {
        "title": "BoinxSoftwareLtd",
        "description": "We make cool photo and video software for Mac, iPhone, iPad and Apple TV.",
        "customUrl": "boinxsoftwareltd",
        "publishedAt": "2007-09-13T13:12:57.000Z",
        "thumbnails": {
          "default": {
            "url": "https://yt3.ggpht.com/a/AGF-l7-1r4qJFWgQLOo55m53PqG-w9zmBX3EFfBn=s88-mo-c-c0xffffffff-rj-k-no",
            "width": 88,
            "height": 88
          },
          "medium": {
            "url": "https://yt3.ggpht.com/a/AGF-l7-1r4qJFWgQLOo55m53PqG-w9zmBX3EFfBn=s240-mo-c-c0xffffffff-rj-k-no",
            "width": 240,
            "height": 240
          },
          "high": {
            "url": "https://yt3.ggpht.com/a/AGF-l7-1r4qJFWgQLOo55m53PqG-w9zmBX3EFfBn=s800-mo-c-c0xffffffff-rj-k-no",
            "width": 800,
            "height": 800
          }
        },
        "localized": {
          "title": "BoinxSoftwareLtd",
          "description": "We make cool photo and video software for Mac, iPhone, iPad and Apple TV."
        },
        "country": "DE"
      }
    }
    */
    init?(withResponse dict: [String: Any])
    {
        guard let identifier = dict["id"] as? String,
              let snippet = dict["snippet"] as? [String: Any],
              let name = snippet["title"] as? String
        else
        {
            return nil
        }
        
        var url = URL(string: "https://www.youtube.com/channel/")!
        let customURL = snippet["customUrl"] as? String
        url.appendPathComponent(customURL ?? identifier)
        
        self.init(identifier: identifier, name: name, url: url)
    }
}
