//
//  TokenProvider.swift
//  VoqMail
//
//  Supplies valid access tokens, refreshing on expiry. Access tokens live only
//  here, in memory, keyed by account email; refresh tokens are read from the
//  Keychain on demand. Isolated as an actor because this is the shared token
//  source every Gmail API call will go through (issues #4 onward).
//

import Foundation

actor TokenProvider {
    private var oauth = GoogleOAuthClient()
    private let keychain = KeychainTokenStore()
    private var cache: [String: AccessToken] = [:]

    /// Seeds an access token obtained out of band (e.g. right after sign-in),
    /// avoiding an immediate refresh.
    func store(_ response: TokenResponse, for email: String) {
        cache[email] = AccessToken(
            value: response.accessToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn)))
    }

    /// A valid access token for `email`, refreshing via the stored refresh token
    /// when the cached one is missing or near expiry.
    func accessToken(for email: String) async throws -> String {
        if let cached = cache[email], cached.isValid(asOf: Date()) {
            return cached.value
        }
        guard let refreshToken = try keychain.refreshToken(for: email) else {
            throw OAuthError.noRefreshToken
        }
        let response = try await oauth.refreshAccessToken(refreshToken: refreshToken)
        let token = AccessToken(
            value: response.accessToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn)))
        cache[email] = token
        return token.value
    }
}
