//
//  OAuthConfiguration.swift
//  VoqMail
//
//  Static Google OAuth client settings the app reads at launch. These come from
//  the iOS-type OAuth client created in Google Cloud (issue #1). An iOS client is
//  a *public* client: it has no client secret, so the client ID below is not a
//  secret and is safe to keep in the repository.
//
//  The redirect uses the client's reversed client ID as a custom URL scheme. That
//  same scheme must be registered in the app's Info.plist (CFBundleURLTypes); the
//  build script writes it from `redirectScheme` so the two never drift.
//

import Foundation

/// Google OAuth settings for the External / Testing Gmail client.
enum OAuthConfiguration {
    /// OAuth client ID issued by Google Cloud for the iOS-type client.
    static let clientID =
        "1023809986523-4os0v0qhf63kp1l25k1ifotj88fcltgb.apps.googleusercontent.com"

    /// Reversed client ID, used as the custom URL scheme for the redirect.
    ///
    /// Derived from `clientID` by dropping the `.apps.googleusercontent.com`
    /// suffix and prefixing `com.googleusercontent.apps.`. Kept as a stored
    /// constant so the build script can read it without parsing Swift.
    static let redirectScheme =
        "com.googleusercontent.apps.1023809986523-4os0v0qhf63kp1l25k1ifotj88fcltgb"

    /// Full redirect URI handed to Google and matched on the callback.
    ///
    /// Google's recommended shape for installed/iOS clients is
    /// `<reversed-client-id>:/oauth2redirect`.
    static let redirectURI = "\(redirectScheme):/oauth2redirect"

    /// Scopes requested on the consent screen.
    ///
    /// `gmail.modify` covers reading plus read/label mutations; `gmail.send`
    /// covers sending. `openid`/`email`/`profile` identify the signed-in account.
    static let scopes = [
        "https://www.googleapis.com/auth/gmail.modify",
        "https://www.googleapis.com/auth/gmail.send",
        "openid",
        "email",
        "profile",
    ]
}
