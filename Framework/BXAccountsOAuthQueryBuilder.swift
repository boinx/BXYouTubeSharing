//
//  BXAccountsOAuthQueryBuilder.swift
//  BXAccounts
//
//  Created by Stefan Fochler on 05.04.19.
//  Copyright © 2019 Boinx Software Ltd. All rights reserved.
//

import Foundation

/// OAuth Request Parameters taken from https://tools.ietf.org/html/rfc6749
fileprivate struct OAuthParams
{
    static let responseType = "response_type"
    static let clientID = "client_id"
    static let clientSecret = "client_secret"
    static let redirectURI = "redirect_uri"
    static let scope = "scope"
    static let state = "state"
    static let grantType = "grant_type"
    static let code = "code"
    static let refreshToken = "refresh_token"
    static let accessToken = "access_token"
}

internal struct BXAccountsOAuthQueryBuilder
{
    /**
     URL query items for the authentication URL used in the first phase of the OAuth 2.0 login flow.
     
     The parameters used strictly follow the information given on https://tools.ietf.org/html/rfc6749#section-4.1.1
     
     For the state parameter, the main bundle's version is used which allows targetted redirects to the correct
     application instance if multiple versions are present on the user's system.
     */
    static func authenticationQueryItems(clientID: String, redirectURI: String, scope: String? = nil) -> [URLQueryItem]
    {
        var items = [
            URLQueryItem(name: OAuthParams.responseType, value: "code"),
            URLQueryItem(name: OAuthParams.clientID, value: clientID),
            URLQueryItem(name: OAuthParams.redirectURI, value: redirectURI),
            URLQueryItem(name: OAuthParams.state, value: self.bundleVersion),
        ]
        
        if let scope = scope
        {
            items.append(URLQueryItem(name: OAuthParams.scope, value: scope))
        }
        
        return items
    }
    
    /**
     URL query items for the access token URL used in the second phase of the OAuth 2.0 login flow.
     
     The parameters follow the informiation given on https://tools.ietf.org/html/rfc6749#section-4.1.3 with the addition
     of `client_secret` which is not necessarily required for our type of application (public native app) but may still
     be required by some services.
     
     **Note**: the `redirectURI` is not used for redirecting the user agent to our application, since requests that
     obtain the aceess token are sent directly. However, the spec says that we must include the same redirect URI that
     was used to obtain the authorization code.
     */
    static func accessTokenQueryItems(clientID: String, clientSecret: String, redirectURI: String, authCode: String) -> [URLQueryItem]
    {
        return [
            URLQueryItem(name: OAuthParams.grantType, value: "authorization_code"),
            URLQueryItem(name: OAuthParams.code, value: authCode),
            URLQueryItem(name: OAuthParams.redirectURI, value: redirectURI),
            URLQueryItem(name: OAuthParams.clientID, value: clientID),
            URLQueryItem(name: OAuthParams.clientSecret, value: clientSecret),
        ]
    }
    
    /**
     URL query items for the refresh access token URL used to refresh a previously aquired access token.
     
     The parameters follow the information given on https://tools.ietf.org/html/rfc6749#section-6 with the addition of
     `client_id` and `client_secret` which are not necessarily required but may still be required by some services.
     */
    static func refreshTokenQueryItems(clientID: String, clientSecret: String, refreshToken: String) -> [URLQueryItem]
    {
        return [
            URLQueryItem(name: OAuthParams.grantType, value: "refresh_token"),
            URLQueryItem(name: OAuthParams.refreshToken, value: refreshToken),
            URLQueryItem(name: OAuthParams.clientID, value: clientID),
            URLQueryItem(name: OAuthParams.clientSecret, value: clientSecret),
        ]
    }
    
    private static let bundleVersion: String =
    {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }()
}
