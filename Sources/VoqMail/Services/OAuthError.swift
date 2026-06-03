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
    /// A refresh token was rejected as expired or revoked (`invalid_grant`). The
    /// trigger for the graceful re-authentication flow (issue #11) — distinct from
    /// `tokenRequestFailed` so a transient 5xx is never mistaken for a dead token.
    case refreshTokenExpired
    /// Gmail rejected a freshly-refreshed access token with 401. This means retrying
    /// the cached token cannot recover; the user needs to sign in again.
    case accessTokenRejected
}

extension OAuthError {
    /// Whether this failure means the account must be re-signed-in: its stored
    /// credential is gone or has been rejected. Such errors are owned by the
    /// re-auth banner (issue #11) — callers flag the account and suppress the raw
    /// error rather than retrying it or painting it over the mail UI.
    var requiresReauthentication: Bool {
        switch self {
        case .refreshTokenExpired, .noRefreshToken, .accessTokenRejected: return true
        default: return false
        }
    }
}
