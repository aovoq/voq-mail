//
//  OAuthTokens.swift
//  VoqMail
//
//  Token types for the OAuth flow: the JSON shape returned by Google's token
//  endpoint, and the in-memory access token with its expiry. Refresh tokens are
//  persisted in the Keychain (see KeychainTokenStore); access tokens are not.
//

import Foundation

/// The token endpoint's JSON response (authorization-code exchange or refresh).
struct TokenResponse: Decodable {
    let accessToken: String
    /// Present on the initial exchange (with `access_type=offline`); often absent
    /// on a plain refresh, which is why we never overwrite a stored one with nil.
    let refreshToken: String?
    let expiresIn: Int
    let idToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case idToken = "id_token"
    }
}

/// An access token held in memory together with its expiry. Never persisted.
struct AccessToken {
    let value: String
    let expiresAt: Date

    /// Considered usable until shortly before expiry, to avoid sending a token
    /// that lapses mid-request.
    func isValid(asOf now: Date) -> Bool {
        now < expiresAt.addingTimeInterval(-60)
    }
}
