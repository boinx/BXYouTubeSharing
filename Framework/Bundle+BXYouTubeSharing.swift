//**********************************************************************************************************************
//
//  Bundle+BXYouTubeSharing.swift
//	Adds convenience methods to Bundle
//  Copyright ©2019 Peter Baumgartner. All rights reserved.
//
//**********************************************************************************************************************


import Foundation


//----------------------------------------------------------------------------------------------------------------------


public extension Bundle
{
	/// Returns the bundle for BXYouTubeSharing.framework
	
	class var BXYouTubeSharing:Bundle
	{
		return Bundle(for:BXYouTubeSharingMarker.self)
	}
}

private class BXYouTubeSharingMarker { }


//----------------------------------------------------------------------------------------------------------------------
