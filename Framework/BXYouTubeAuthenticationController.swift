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


public protocol BXYouTubeAuthenticationControllerDelegate: BXMainThreadDelegate
{
    func youTubeAuthenticationControllerWillLogIn(_ authenticationController: BXYouTubeAuthenticationController) -> Void
    func youTubeAuthenticationControllerDidLogIn(_ authenticationController: BXYouTubeAuthenticationController, error: BXYouTubeAuthenticationController.Error?) -> Void
}

public extension BXYouTubeAuthenticationControllerDelegate
{
	func youTubeAuthenticationControllerWillLogIn(_ authenticationController: BXYouTubeAuthenticationController) -> Void {}
}


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
        self.accessToken = self.loadAccessToken()
	}
 
    public weak var delegate: BXYouTubeAuthenticationControllerDelegate? = nil
	
	private let clientID: String
	private let clientSecret: String
    private let redirectURI: String
    
    private static let scope: Set<String> = [
        "https://www.googleapis.com/auth/youtube.readonly",
        "https://www.googleapis.com/auth/youtube.upload"
    ]


	/// Convenience singleton instance of this controller. It is not instantiated automatically, because
	/// its init() needs the clientID and clientSecret arguments, thich are unique to the host app.
	
	public static var shared: BXYouTubeAuthenticationController? = nil
	

//----------------------------------------------------------------------------------------------------------------------


	/// The name of the logged in user
	
	public private(set) var user: String? = nil
	
 
    private enum KeychainPurpose: String
    {
        case refreshToken
        case accessToken
    }
    
    private func keychainIdentifier(for purpose: KeychainPurpose) -> String
    {
        return "\(Bundle.main.bundleIdentifier ?? "untitledApp").BXYouTubeSharing.\(self.clientID).\(purpose.rawValue)".replacingOccurrences(of: ".", with: "_")
    }

    /// Save to keychain
    private var refreshToken: String? = nil
    {
        didSet
        {
            let identifier = self.keychainIdentifier(for: .refreshToken)
            if let refreshToken = self.refreshToken
            {
                if let data = refreshToken.data(using: .utf8)
                {
                    //BXKeychain.set(data, forKey: identifier)
                    UserDefaults.standard.set(data, forKey: identifier)
                }
            }
            else
            {
                //BXKeychain.deleteData(forKey: identifier)
                UserDefaults.standard.removeObject(forKey: identifier)
            }
        }
    }
    
    private func loadRefreshToken() -> String?
    {
        let identifier = self.keychainIdentifier(for: .refreshToken)
        if //let data = BXKeychain.data(forKey: identifier),
           let data = UserDefaults.standard.data(forKey: identifier),
           let refreshToken = String(data: data, encoding: .utf8)
        {
            return refreshToken
        }

        return nil
    }
    
    private struct AccessToken: Codable
    {
        let value: String
        let expirationDate: Date
        
        var isExpired: Bool
        {
            return Date() >= self.expirationDate.addingTimeInterval(-5 * 60)
        }
    }
    
    /// The currently valid access token for the user
    private var accessToken: AccessToken? = nil
    {
        didSet
        {
            let identifier = self.keychainIdentifier(for: .accessToken)
            if let accessToken = self.accessToken
            {
                if let data = try? JSONEncoder().encode(accessToken)
                {
                    //BXKeychain.set(data, forKey: identifier)
                    UserDefaults.standard.set(data, forKey: identifier)
                }
                else
                {
                    assertionFailure("Unable to encode access token \(accessToken)")
                }
            }
            else
            {
                //BXKeychain.deleteData(forKey: identifier)
                UserDefaults.standard.removeObject(forKey: identifier)
            }
        }
    }
    
    private func loadAccessToken() -> AccessToken?
    {
        let identifier = self.keychainIdentifier(for: .accessToken)
        if //let data = BXKeychain.data(forKey: identifier),
           let data = UserDefaults.standard.data(forKey: identifier),
           let accessToken = try? JSONDecoder().decode(AccessToken.self, from: data)
        {
            return accessToken
        }

        return nil
    }
    
    public func reset()
    {
        self.accessToken = nil
        self.refreshToken = nil
    }
    
    @discardableResult
    public func login() -> Bool
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
    
    public func handleOAuthResponse(returnURL: URL) -> Bool
    {
        if let urlComponents = URLComponents(url: returnURL, resolvingAgainstBaseURL: false),
           returnURL.pathComponents.last == "BXYouTubeSharing"
        {
            // complete authentication
            
            if let scope = urlComponents.queryItems?.first(where: { $0.name == "scope" })?.value
            {
                // Validate scope only if present.
                let scopeSet = Set(scope.components(separatedBy: " "))
                
                if BXYouTubeAuthenticationController.scope != scopeSet
                {
                    self.delegate?.onMainThread { $0.youTubeAuthenticationControllerDidLogIn(self, error: Error.authenticationFailed(reason: "insufficient permission")) }
                    return true
                }
            }
            
            if let error = urlComponents.queryItems?.first(where: { $0.name == "error" })?.value
            {
                self.delegate?.onMainThread { $0.youTubeAuthenticationControllerDidLogIn(self, error: Error.authenticationFailed(reason: error)) }
                return true
            }
            
            guard let code = urlComponents.queryItems?.first(where: { $0.name == "code" })?.value else
            {
                self.delegate?.onMainThread { $0.youTubeAuthenticationControllerDidLogIn(self, error: Error.authenticationFailed(reason: "invalid response")) }
                return true
            }
            
            let authorizationURLComponents = URLComponents(string: "https://www.googleapis.com/oauth2/v4/token")!
            //authorizationURLComponents.queryItems = BXAccountsOAuthQueryBuilder.accessTokenQueryItems(clientID: self.clientID, clientSecret: self.clientSecret, redirectURI: self.redirectURI, authCode: code)
            let url = authorizationURLComponents.url!
            
            var request = URLRequest(url: url)
            request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpMethod = "POST"
            
            let bodyObject: [String : Any] = [
                "grant_type": "authorization_code",
                "client_id": self.clientID,
                "code": code,
                "redirect_uri": self.redirectURI
            ]
            request.httpBody = try! JSONSerialization.data(withJSONObject: bodyObject, options: [])
            
            let task = self.foregroundSession.dataTask(with: request)
            {
                (data, _, error) in
                
                if let error = error
                {
                    self.delegate?.onMainThread { $0.youTubeAuthenticationControllerDidLogIn(self, error: Error.other(underlyingError: error)) }
                    return
                }
                else if let data = data,
                        let payload = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
                {
                    if let accessTokenValue = payload["access_token"] as? String,
                       let refreshToken = payload["refresh_token"] as? String,
                       let expiresInSeconds = payload["expires_in"] as? Int
                    {
                        // Valid Data
                        self.refreshToken = refreshToken
                        self.accessToken = AccessToken(value: accessTokenValue, expirationDate: Date(timeIntervalSinceNow: TimeInterval(expiresInSeconds)))
                        
                        self.delegate?.onMainThread { $0.youTubeAuthenticationControllerDidLogIn(self, error: nil) }
                        return
                    }
                    else if let errorDescription = payload["error_description"] as? String
                    {
                        // YouTube API Error
                        self.delegate?.onMainThread { $0.youTubeAuthenticationControllerDidLogIn(self, error: Error.authenticationFailed(reason: errorDescription)) }
                        return
                    }
                }
                
                self.delegate?.onMainThread { $0.youTubeAuthenticationControllerDidLogIn(self, error: Error.authenticationFailed(reason: "invalid response")) }
                return
            }
            task.resume()
            
            // Open app request was handled by this framework.
            return true
        }
        
        // Host app needs to handle request.
        return false
    }


//----------------------------------------------------------------------------------------------------------------------


	/// Possible errors when trying to login to YouTube
	
	public enum Error : Swift.Error
	{
		case unknownClient
        case notLoggedIn
        case authenticationFailed(reason: String)
        case other(underlyingError: Swift.Error?)
	}
	
	
//----------------------------------------------------------------------------------------------------------------------


	// MARK: -
 
    private var refreshTokenRequestIsInFlight = false
    private var completionHandlers: [(String?,Error?)->Void] = []
    
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

    public var authenticationURL: URL?
    {
        var urlComponents = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        
        urlComponents.queryItems = BXAccountsOAuthQueryBuilder.authenticationQueryItems(clientID: self.clientID, redirectURI: self.redirectURI, scope: BXYouTubeAuthenticationController.scope.joined(separator: " "))
        
        return urlComponents.url
    }
    
	public func requestAccessToken(completionHandler: @escaping (String?,Error?)->Void)
	{
        self.queue.addOperation
        {
            if let storedAccessToken = self.accessToken, !storedAccessToken.isExpired
            {
                DispatchQueue.main.async
                {
                    completionHandler(storedAccessToken.value, nil)
                }
                
                return
            }
            
            print("RENEW ACCESS TOKEN NOW!!!")
            return
        
            self.completionHandlers.append(completionHandler)
            
            // Renew access token
            if self.refreshTokenRequestIsInFlight
            {
                return
            }
            else
            {
                self.refreshTokenRequestIsInFlight = true

                DispatchQueue.background.async
                {
//                    let refreshRequest = BXYouTubeNetworkHelpers.tokenRefreshRequest()
//                    self.foregroundSession.dataTask(with: refreshRequest)
//                    { (data, response, error) in
//                        // on: self.queue
//
//                        let accessToken: AccessToken? = AccessToken(value: "bla", creationTime: Date())
//
//                        self.accessToken = accessToken
//
//                        self.refreshTokenRequestIsInFlight = false
//
//                        let handlers = self.completionHandlers
//                        self.completionHandlers = []
//                        DispatchQueue.main.async
//                        {
//                            handlers.forEach { $0(accessToken?.value, error) }
//                        }
//                    }
                }
            }
        }
	}

}
	

//----------------------------------------------------------------------------------------------------------------------
