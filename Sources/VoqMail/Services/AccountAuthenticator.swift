//
//  AccountAuthenticator.swift
//  VoqMail
//
//  Runs the end-to-end "add account" flow and returns the resulting Account
//  along with the freshly issued tokens:
//
//    PKCE → consent sheet → code exchange → profile fetch → Keychain save.
//
//  It owns the sequencing; the individual steps live in the services it calls.
//

import Foundation

@MainActor
struct AccountAuthenticator {
    var oauth = GoogleOAuthClient()
    var profiles = GmailProfileService()
    var keychain = KeychainTokenStore()
    let webAuth: WebAuthenticationSession

    /// Drives the full flow. The returned tokens let the caller seed an access
    /// token without an immediate refresh round-trip.
    func signIn() async throws -> (account: Account, tokens: TokenResponse) {
        let pkce = PKCE()
        let state = RandomString.urlSafe()

        let authURL = oauth.authorizationURL(pkce: pkce, state: state)
        let callbackURL = try await webAuth.authenticate(
            url: authURL, callbackScheme: OAuthConfiguration.redirectScheme)

        let (code, returnedState) = try parseCallback(callbackURL)
        guard returnedState == state else { throw OAuthError.stateMismatch }

        let tokens = try await oauth.exchangeCode(code, verifier: pkce.verifier)
        let email = try await profiles.emailAddress(accessToken: tokens.accessToken)

        guard let refreshToken = tokens.refreshToken else { throw OAuthError.noRefreshToken }
        try keychain.saveRefreshToken(refreshToken, for: email)

        return (Account(email: email, displayName: nil), tokens)
    }

    private func parseCallback(_ url: URL) throws -> (code: String, state: String?) {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        guard let code = items?.first(where: { $0.name == "code" })?.value else {
            throw OAuthError.missingAuthCode
        }
        return (code, items?.first(where: { $0.name == "state" })?.value)
    }
}
