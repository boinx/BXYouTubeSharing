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


// Youtube Developer Dashboard - Project Settings
// https://console.developers.google.com/projectselector2/apis/api/youtube/overview


//----------------------------------------------------------------------------------------------------------------------


public class BXYouTubeAuthenticationController
{
	/// Creates a new instance of this controller with the specified clientID uniquely identifying the host application.
    /// - parameter clientID: See Youtube Developer Dashboard.
    /// - parameter clientSecret: See Youtube Developer Dashboard.
    /// - parameter redirectURI: See Youtube Developer Dashboard.
	/// - parameter redirectURIStateValue: The state value which can be used to dynamically attach a value to the oauth request.
    ///
    /// Youtube Developer Dashboard:
    /// https://console.developers.google.com/projectselector2/apis/api/youtube/overview
    /// Documentation:
    /// https://developers.google.com/youtube/v3/guides/auth/server-side-web-apps
    
    public init(clientID: String, clientSecret: String? = nil, redirectURI: String, redirectURIStateValue: String? = nil)
	{
		self.clientID = clientID
		self.clientSecret = clientSecret
        self.redirectURI = redirectURI
        self.redirectURIStateValue = redirectURIStateValue
        
        self.storedRefreshToken = self._loadRefreshToken()
        self.storedAccessToken = self._loadAccessToken()
	}
 
 	/// Convenience singleton instance of this controller. It is not instantiated automatically, because
	/// its init() needs the clientID and redirectURI arguments, thich are unique to the host app.
	
	public static var shared: BXYouTubeAuthenticationController? = nil
	
	/// The delegate is notified about status changes
	
	public weak var delegate: BXYouTubeAuthenticationControllerDelegate? = nil
	
	
//----------------------------------------------------------------------------------------------------------------------


	/// Possible errors when trying to login to YouTube
	
	public enum Error : Swift.Error, Equatable
	{
		case unknownClient
        case notLoggedIn
        case invalidAccount
        case youTubeAPIError(reason: String)
        case other(underlyingError: String)
	}
	
	
//----------------------------------------------------------------------------------------------------------------------


	private let clientID: String
	private let clientSecret: String?
    private let redirectURI: String
    private let redirectURIStateValue: String?
    
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
    
    /// Youtube scopes can be found:
    /// https://developers.google.com/identity/protocols/oauth2/scopes
    
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
        self.storedAccessToken = nil
        self.storedRefreshToken = nil
        self.delegate?.onMainThread { $0.youTubeAuthenticationControllerDidLogOut(self) }
    }
	

//----------------------------------------------------------------------------------------------------------------------


	/// This helper function can be called from the application(_:,open:,options:) function of the AppDelegate class
	/// to complete the OAuth process.
	/// - parameter returnURL: The callback URL that is returns control to the calling application after spending time in the web browser
	/// - returns: True if the URL was part of the OAuth process. The AppDelegate needs to handle the URL itself if false was returned.
	
    public func handleOAuthResponse(returnURL: URL) -> Bool
    {
        let lastURLPath = returnURL.pathComponents.last
        guard let urlComponents = URLComponents(url: returnURL, resolvingAgainstBaseURL: false),
              // "BXYouTubeSharing" backward compatibility for iOS (FM iPad).
              // "oauth" compatibility for macOS (FM6 - server side redirect).
              lastURLPath == "BXYouTubeSharing" || lastURLPath == "oauth"
        else
        {
            // Host app needs to handle request.
            return false
        }
		
        // Request will be handled by this framework.
		
        if let scope = urlComponents.queryItems?.first(where: { $0.name == "scope" })?.value
        {
			var isScopeValid = true
			
			for part in BXYouTubeAuthenticationController.scope
			{
				if !scope.contains(part)
				{
					isScopeValid = false
					break
				}
			}
			
			if !isScopeValid
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
		
        let request = BXYouTubeNetworkHelpers.accessTokenRequest(clientID: self.clientID, clientSecret:self.clientSecret, redirectURI: self.redirectURI, authCode: code)
        let task = self.foregroundSession.dataTask(with: request)
        {
            (data, _, errorR) in
			
            if let error = errorR
            {
                self.delegate?.onMainThread { $0.youTubeAuthenticationControllerDidLogIn(self, error: Error.other(underlyingError: error.localizedDescription)) }
                return
            }
            else if let data = data
            {
                let (accessToken, refreshToken, errorE) = self._extractValues(from: data)
				
                if let error = errorE
                {
                    // YouTube API Error
                    self.delegate?.onMainThread { $0.youTubeAuthenticationControllerDidLogIn(self, error: Error.youTubeAPIError(reason: error)) }
                    return
                }
				else if let accessToken = accessToken,
                   let refreshToken = refreshToken
                {
                    // Valid Data
                    self.storedAccessToken = accessToken
                    self.storedRefreshToken = refreshToken
					
                    self.delegate?.onMainThread { $0.youTubeAuthenticationControllerDidLogIn(self, error: nil) }
                    return
                }
                else
                {
                    let errorReason = "Youtube did not provide a refresh token, which is unacceptable."
                    assertionFailure(errorReason)
                    self.delegate?.onMainThread { $0.youTubeAuthenticationControllerDidLogIn(self, error: Error.youTubeAPIError(reason: errorReason)) }
                    return
                }

            }
			
            self.delegate?.onMainThread { $0.youTubeAuthenticationControllerDidLogIn(self, error: Error.youTubeAPIError(reason: "invalid response")) }
        }
		
		// If app is not fully in foreground state, we need to wait before starting the task. This avoid
		// an obscure error that is mentioned at: https://github.com/AFNetworking/AFNetworking/issues/4279
		
		self._whenInForeground(start:task)
		
        return true
    }
	
	
	/// Helper function that waits before starting a task until the app is fully in the foreground state.
	/// Must not be called from a background thread!
	
	private func _whenInForeground(start task:URLSessionDataTask, delay:Double = 0.1, maxRetryCount:Int = 100)
	{
		#if os(iOS)
		
		if UIApplication.shared.applicationState == .active || maxRetryCount == 0
		{
			task.resume()
		}
		else
		{
			DispatchQueue.main.asyncAfter(deadline: .now()+delay)
			{
				self._whenInForeground(start: task, maxRetryCount: maxRetryCount-1)
			}
		}
		
		#else
		
		task.resume()
		
		#endif
	}
	
    private var authenticationURL: URL?
    {
        let scope = BXYouTubeAuthenticationController.scope.joined(separator: " ")
        return BXYouTubeNetworkHelpers.authenticationURL(clientID: self.clientID, redirectURI: self.redirectURI, scope: scope, redirectURIStateValue: self.redirectURIStateValue)
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
		
        guard let storedAccessToken = self.storedAccessToken, let storedRefreshToken = self.storedRefreshToken else
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
            let refreshRequest = BXYouTubeNetworkHelpers.refreshAccessTokenRequest(clientID: self.clientID, clientSecret:self.clientSecret, refreshToken: storedRefreshToken)
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
                        self.storedAccessToken = accessToken
                    }

                    let responseAccessToken: String? = self.storedAccessToken?.value
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
	
	
//---------------------------------------------------------------------------------------------------------------------
	
	/// The current AccessToken for the user
	
    private var storedAccessToken: AccessToken? = nil
    {
        didSet
        {
            let identifier = self.keychainIdentifier(for: .accessToken)
            if let accessToken = self.storedAccessToken
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
	

    private var storedRefreshToken: String? = nil
    {
        didSet
        {
            let identifier = self.keychainIdentifier(for: .refreshToken)
			
            if let refreshToken = self.storedRefreshToken
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
    
    private func _loadRefreshToken() -> String?
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
            
			DispatchQueue.background.async // Dispatch to background queue because we can't create the dataTask on self.queue
            {
                let task = self.foregroundSession.dataTask(with: request)
                {
                    (data,response,error) in
					
                    if let error = error
                    {
                        DispatchQueue.main.async
                        {
                            completionHandler(nil, Error.other(underlyingError: error.localizedDescription))
                        }
                        return
                    }
                    else if let data = data,
                            let payload = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String:Any]
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
                        else
                        {
							// Oops, this account has no channels. Report an error
							
                            DispatchQueue.main.async
                            {
                                completionHandler(nil,Error.invalidAccount)
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
