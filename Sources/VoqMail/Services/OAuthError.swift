//
//  OAuthError.swift
//  VoqMail
//
//  Typed failures across the sign-in flow. Kept in one place so the UI can
//  distinguish "user just cancelled" from real failures worth surfacing.
//

import Foundation

enum OAuthError: Error {
    /// The user dismissed the consent sheet. Not worth surfacing as an error.
    case userCancelled
    /// ASWebAuthenticationSession refused to start.
    case sessionStartFailed
    /// The auth session returned without a callback URL.
    case missingCallbackURL
    /// The `state` returned by Google did not match the one we sent (possible CSRF).
    case stateMismatch
    /// The callback URL carried no authorization `code`.
    case missingAuthCode
    /// A token endpoint request failed; carries the HTTP status and body for logs.
    case tokenRequestFailed(status: Int, body: String)
    /// `users.getProfile` failed.
    case profileFetchFailed(status: Int)
    /// No refresh token is available for the account (none issued, or none stored).
    case noRefreshToken
}
