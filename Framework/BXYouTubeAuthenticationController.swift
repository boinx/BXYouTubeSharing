//**********************************************************************************************************************
//
//  BXYouTubeAuthenticationController.swift
//  Copyright ©2019 Boinx Software Ltd. & Imagine GbR. All rights reserved.
//
//**********************************************************************************************************************


import Foundation

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#else
#error("Unsupported platform")
#endif


//----------------------------------------------------------------------------------------------------------------------


public class BXYouTubeAuthenticationController
{
	/// Creates a new instance of this controller with the specified clientID/clientSecret uniquely identifying
	/// the host application.
	
	public init(clientID: String, clientSecret: String, redirectURI: String)
	{
		self.clientID = clientID
		self.clientSecret = clientSecret
        self.redirectURI = redirectURI
  
        self.refreshToken = self.loadRefreshToken()
        self.accessToken = self._loadAccessToken()
	}
 
 	/// Convenience singleton instance of this controller. It is not instantiated automatically, because
	/// its init() needs the clientID and clientSecret arguments, thich are unique to the host app.
	
	public static var shared: BXYouTubeAuthenticationController? = nil
	
	/// The delegate is notified about status changes
	
	public weak var delegate: BXYouTubeAuthenticationControllerDelegate? = nil
	
	
//----------------------------------------------------------------------------------------------------------------------


	/// Possible errors when trying to login to YouTube
	
	public enum Error : Swift.Error, Equatable
	{
		case unknownClient
        case notLoggedIn
        case youTubeAPIError(reason: String)
        case other(underlyingError: String)
	}
	
	
//----------------------------------------------------------------------------------------------------------------------


	private let clientID: String
	private let clientSecret: String
    private let redirectURI: String
    
    private lazy var foregroundSession: URLSession =
    {
        return URLSession(configuration: .default, delegate: nil, delegateQueue: self.queue)
    }()
	
    private lazy var queue: OperationQueue =
    {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    private static let scope: Set<String> = [
        "https://www.googleapis.com/auth/youtube.readonly",
        "https://www.googleapis.com/auth/youtube.upload"
    ]

	/// The name of the logged in user
	
//	public private(set) var user: String? = nil
	

//----------------------------------------------------------------------------------------------------------------------


	// MARK: - Login & Logout
	
	
	/// Starts the OAuth based login process to YouTube
	
    @discardableResult public func logIn() -> Bool
    {
        guard let url = self.authenticationURL else
        {
            print("Fail")
            return false
        }
		
        self.delegate?.onMainThread { $0.youTubeAuthenticationControllerWillLogIn(self) }
		
        #if os(macOS)
        return NSWorkspace.shared.open(url)
        #elseif os(iOS)
        UIApplication.shared.open(url, options: [:])
        return true
        #endif
    }
	

//----------------------------------------------------------------------------------------------------------------------


	/// Logs out the user from YouTube
	
    public func logOut()
    {
        self.accessToken = nil
        self.refreshToken = nil
        self.delegate?.onMainThread { $0.youTubeAuthenticationControllerDidLogOut(self) }
    }
	

//----------------------------------------------------------------------------------------------------------------------


	/// This helper function can be called from the application(_:,open:,options:) function of the AppDelegate class
	/// to complete the OAuth process.
	/// - parameter returnURL: The callback URL that is returns control to the calling application after spending time in the web browser
	/// - returns: True if the URL was part of the OAuth process. The AppDelegate needs to handle the URL itself if false was returned.
	
    public func handleOAuthResponse(returnURL: URL) -> Bool
    {
        guard let urlComponents = URLComponents(url: returnURL, resolvingAgainstBaseURL: false),
              returnURL.pathComponents.last == "BXYouTubeSharing"
        else
        {
            // Host app needs to handle request.
            return false
        }
		
        // Request will be handled by this framework.
		
        if let scope = urlComponents.queryItems?.first(where: { $0.name == "scope" })?.value
        {
            // Validate scope only if present.
            let scopeSet = Set(scope.components(separatedBy: " "))
			
            if BXYouTubeAuthenticationController.scope != scopeSet
            {
                self.delegate?.onMainThread { $0.youTubeAuthenticationControllerDidLogIn(self, error: Error.youTubeAPIError(reason: "insufficient permission")) }
                return true
            }
        }
		
        if let error = urlComponents.queryItems?.first(where: { $0.name == "error" })?.value
        {
            self.delegate?.onMainThread { $0.youTubeAuthenticationControllerDidLogIn(self, error: Error.youTubeAPIError(reason: error)) }
            return true
        }
		
        guard let code = urlComponents.queryItems?.first(where: { $0.name == "code" })?.value else
        {
            self.delegate?.onMainThread { $0.youTubeAuthenticationControllerDidLogIn(self, error: Error.youTubeAPIError(reason: "invalid response")) }
            return true
        }
		
        let request = BXYouTubeNetworkHelpers.accessTokenRequest(clientID: self.clientID, redirectURI: self.redirectURI, authCode: code)
        let task = self.foregroundSession.dataTask(with: request)
        {
            (data, _, error) in
			
            if let error = error
            {
                self.delegate?.onMainThread { $0.youTubeAuthenticationControllerDidLogIn(self, error: Error.other(underlyingError: error.localizedDescription)) }
                return
            }
            else if let data = data
            {
                let (accessToken, refreshToken, error) = self._extractValues(from: data)
				
                if let accessToken = accessToken,
                   let refreshToken = refreshToken
                {
                    // Valid Data
                    self.accessToken = accessToken
                    self.refreshToken = refreshToken
					
                    self.delegate?.onMainThread { $0.youTubeAuthenticationControllerDidLogIn(self, error: nil) }
                    return
                }
                else if let error = error
                {
                    // YouTube API Error
                    self.delegate?.onMainThread { $0.youTubeAuthenticationControllerDidLogIn(self, error: Error.youTubeAPIError(reason: error)) }
                    return
                }
            }
			
            self.delegate?.onMainThread { $0.youTubeAuthenticationControllerDidLogIn(self, error: Error.youTubeAPIError(reason: "invalid response")) }
        }
		
        task.resume()
		
        return true
    }
	
	
    private var authenticationURL: URL?
    {
        let scope = BXYouTubeAuthenticationController.scope.joined(separator: " ")
        return BXYouTubeNetworkHelpers.authenticationURL(clientID: self.clientID, redirectURI: self.redirectURI, scope: scope)
    }
	
	
//----------------------------------------------------------------------------------------------------------------------


	// MARK: - AccessToken
	

	/// Requests an AccessToken. This automatically triggers the login process if the user is currently logged out.
	/// If an AccessToken is available but is expired (or soon to expire) then the AccessToken is automatically
	/// renewed.
	/// - parameter completionHandler: The handler either returns the accessToken String or an Error
	
	public func requestAccessToken(_ completionHandler: @escaping (String?,Error?)->Void)
	{
        self.queue.addOperation
        {
            self._requestAccessToken(completionHandler)
        }
	}
	
	
//----------------------------------------------------------------------------------------------------------------------


	/// Requests the current accessToken if available. If the current accessToken is expired or soon to expire,
	/// it will be automatically renewed.
	/// - parameter completionHandler: The handler either returns the accessToken String or an Error

    private func _requestAccessToken(_ completionHandler: @escaping (String?, Error?) -> Void)
    {
        assert(OperationQueue.current == self.queue, "BXYouTubeAuthenticationController.\(#function) may only be called on self.queue")
		
        guard let storedAccessToken = self.accessToken, let storedRefreshToken = self.refreshToken else
        {
            DispatchQueue.main.async
            {
                completionHandler(nil, .notLoggedIn)
            }
            return
        }
		
        if !storedAccessToken.isExpired
        {
            DispatchQueue.main.async
            {
                completionHandler(storedAccessToken.value, nil)
            }
            return
        }
		
        self.completionHandlers.append(completionHandler)

        // Renew access token
        if self.refreshAccessTokenRequestIsInFlight
        {
            return
        }
		
        self.refreshAccessTokenRequestIsInFlight = true

        DispatchQueue.background.async
        {
            let refreshRequest = BXYouTubeNetworkHelpers.refreshAccessTokenRequest(clientID: self.clientID, refreshToken: storedRefreshToken)
            let task = self.foregroundSession.dataTask(with: refreshRequest)
            {
                (data, response, error) in
                // on: self.queue
				
                self.refreshAccessTokenRequestIsInFlight = false
				
                if let error = error
                {
                    self._callAccessTokenCompletionHandlers(accessToken: nil, error: Error.other(underlyingError: error.localizedDescription))
                    return
                }
                else if let data = data
                {
                    let (accessToken, _, errorReason) = self._extractValues(from: data)
					
                    if let accessToken = accessToken
                    {
                        self.accessToken = accessToken
                    }

                    let responseAccessToken: String? = self.accessToken?.value
                    var responseError: Error? = nil
					
                    if let errorReason = errorReason
                    {
                        responseError = Error.youTubeAPIError(reason: errorReason)
                    }
					
                    self._callAccessTokenCompletionHandlers(accessToken: responseAccessToken, error: responseError)
                    return
                }
				
                self._callAccessTokenCompletionHandlers(accessToken: nil, error: Error.youTubeAPIError(reason: "invalid response"))
            }
            task.resume()
        }
    }
	

//----------------------------------------------------------------------------------------------------------------------


 	/// Loads the last known AccessToken from the users keychain
	
   private func _loadAccessToken() -> AccessToken?
    {
        let identifier = self.keychainIdentifier(for: .accessToken)
        if let data = BXKeychain.data(forKey: identifier),
           let accessToken = try? JSONDecoder().decode(AccessToken.self, from: data)
        {
            return accessToken
        }

        return nil
    }
	
	
	/// Helper function that extracts various info from received Data
	
    private func _extractValues(from data: Data) -> (accessToken: AccessToken?, refreshToken: String?, error: String?)
    {
        var accessToken: AccessToken? = nil
        var refreshToken: String? = nil
        var error: String? = nil
		
        if let payload = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
        {
            if let accessTokenValue = payload["access_token"] as? String,
               let expiresInSeconds = payload["expires_in"] as? Int
            {
                accessToken = AccessToken(value: accessTokenValue, expirationDate: Date(timeIntervalSinceNow: TimeInterval(expiresInSeconds)))
            }
			
            refreshToken = payload["refresh_token"] as? String
			
            error = payload["error_description"] as? String
        }
		
        return (
            accessToken: accessToken,
            refreshToken: refreshToken,
            error: error
        )
    }


	/// Calls the completionHandlers for all requests that have accumulated lately
	
    private func _callAccessTokenCompletionHandlers(accessToken: String?, error: Error?)
    {
        let handlers = self.completionHandlers
        self.completionHandlers = []
		
        DispatchQueue.main.async
        {
            handlers.forEach { $0(accessToken, error) }
        }
    }
	
	
//----------------------------------------------------------------------------------------------------------------------


	/// This struct holds the accessToken String and its expiration info
	
	private struct AccessToken: Codable
    {
        let value: String
        let expirationDate: Date
		
        var isExpired: Bool
        {
            return Date() >= self.expirationDate.addingTimeInterval(-5 * 60)
        }
    }
	
	/// The current AccessToken for the user
	
    private var accessToken: AccessToken? = nil
    {
        didSet
        {
            let identifier = self.keychainIdentifier(for: .accessToken)
            if let accessToken = self.accessToken
            {
                if let data = try? JSONEncoder().encode(accessToken)
                {
                    BXKeychain.set(data, forKey: identifier)
                }
                else
                {
                    assertionFailure("Unable to encode access token \(accessToken)")
                }
            }
            else
            {
                BXKeychain.deleteData(forKey: identifier)
            }
        }
    }
	
	/// Returns true if a new accessToken is currently being retrieved. In this case additional request are
	/// redundant and will be suppressed.
	
    private var refreshAccessTokenRequestIsInFlight = false
	
	/// Each request has a completionHandler. Since the host app can issue multiple requests, all completionHandlers
	/// are executed once the result has been received from the YouTube server.
	
    private var completionHandlers: [(String?,Error?)->Void] = []
	

//----------------------------------------------------------------------------------------------------------------------


	// MARK: - RefreshToken
	

    private var refreshToken: String? = nil
    {
        didSet
        {
            let identifier = self.keychainIdentifier(for: .refreshToken)
			
            if let refreshToken = self.refreshToken
            {
                if let data = refreshToken.data(using: .utf8)
                {
                    BXKeychain.set(data, forKey: identifier)
                }
            }
            else
            {
                BXKeychain.deleteData(forKey: identifier)
            }
        }
    }
    
    private func loadRefreshToken() -> String?
    {
        let identifier = self.keychainIdentifier(for: .refreshToken)
        if let data = BXKeychain.data(forKey: identifier),
           let refreshToken = String(data: data, encoding: .utf8)
        {
            return refreshToken
        }

        return nil
    }
	
	
//----------------------------------------------------------------------------------------------------------------------


	// MARK: - AccountInfo
	
	
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
	
    public func requestAccountInfo(_ completionHandler: @escaping (AccountInfo?, Error?) -> Void)
    {
        self.queue.addOperation
        {
            self._requestAccountInfo(completionHandler)
        }
    }
	
    private func _requestAccountInfo(_ completionHandler: @escaping (AccountInfo?, Error?) -> Void)
    {
        assert(OperationQueue.current == self.queue, "BXYouTubeAuthenticationController.\(#function) may only be called on self.queue")
		
        self._requestAccessToken
        {
            (accessToken, error) in
			
            if let error = error
            {
                DispatchQueue.main.async
                {
                    completionHandler(nil, error)
                }
                return
            }
			
            guard let accessToken = accessToken else
            {
                DispatchQueue.main.async
                {
                    completionHandler(nil, Error.notLoggedIn)
                }
                return
            }
			
            let request = BXYouTubeNetworkHelpers.channelInfoRequest(accessToken: accessToken)
            // Dispatch to background queue because we can't create the dataTask on self.queue.
            DispatchQueue.background.async
            {
                let task = self.foregroundSession.dataTask(with: request)
                {
                    (data, _, error) in
					
                    if let error = error
                    {
                        DispatchQueue.main.async
                        {
                            completionHandler(nil, Error.other(underlyingError: error.localizedDescription))
                        }
                        return
                    }
                    else if let data = data,
                            let payload = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
                    {
                        if let errorDict = payload["error"] as? [String: Any],
                           let errorDescription = errorDict["message"] as? String
                        {
                            DispatchQueue.main.async
                            {
                                completionHandler(nil, Error.youTubeAPIError(reason: errorDescription))
                            }
                            return
                        }
                        else if let items = payload["items"] as? [[String: Any]]
                        {
                            // Extract assignable categories from items.
                            let accountInfo = items.lazy.compactMap({ AccountInfo(withResponse: $0) }).first
							
                            DispatchQueue.main.async
                            {
                                completionHandler(accountInfo, nil)
                            }
                            return
                        }
                    }
					
                    DispatchQueue.main.async
                    {
                        completionHandler(nil, Error.youTubeAPIError(reason: "Invalid response"))
                    }
                }
                task.resume()
            }
        }
    }


//----------------------------------------------------------------------------------------------------------------------


	// MARK: - Keychain Storage
	

 	private enum KeychainPurpose: String
    {
        case refreshToken
        case accessToken
    }
	
    private func keychainIdentifier(for purpose: KeychainPurpose) -> String
    {
        return "\(Bundle.main.bundleIdentifier ?? "untitledApp").BXYouTubeSharing.\(self.clientID).\(purpose.rawValue)".replacingOccurrences(of: ".", with: "_")
    }


}
	

//----------------------------------------------------------------------------------------------------------------------


// MARK: - Delegate

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


//----------------------------------------------------------------------------------------------------------------------
