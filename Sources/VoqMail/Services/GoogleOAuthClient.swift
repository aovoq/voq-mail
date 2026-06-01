//
//  GoogleOAuthClient.swift
//  VoqMail
//
//  Talks to Google's OAuth 2.0 endpoints: builds the authorization URL and
//  performs the authorization-code exchange and refresh. Stateless — it holds
//  no tokens and reads the client settings from OAuthConfiguration.
//

import Foundation

struct GoogleOAuthClient {
    static let authorizationEndpoint =
        URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    static let tokenEndpoint =
        URL(string: "https://oauth2.googleapis.com/token")!

    var session: URLSession = .shared

    /// Builds the authorization URL for the PKCE flow.
    ///
    /// `access_type=offline` + `prompt=consent` make Google return a refresh
    /// token on every run, which the rest of the flow depends on (issue #3).
    func authorizationURL(pkce: PKCE, state: String) -> URL {
        var components = URLComponents(
            url: Self.authorizationEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "client_id", value: OAuthConfiguration.clientID),
            .init(name: "redirect_uri", value: OAuthConfiguration.redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: OAuthConfiguration.scopes.joined(separator: " ")),
            .init(name: "code_challenge", value: pkce.challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "access_type", value: "offline"),
            .init(name: "prompt", value: "consent"),
            .init(name: "state", value: state),
        ]
        return components.url!
    }

    /// Exchanges an authorization code for tokens.
    func exchangeCode(_ code: String, verifier: String) async throws -> TokenResponse {
        try await postToken([
            "grant_type": "authorization_code",
            "code": code,
            "code_verifier": verifier,
            "client_id": OAuthConfiguration.clientID,
            "redirect_uri": OAuthConfiguration.redirectURI,
        ])
    }

    /// Trades a stored refresh token for a fresh access token.
    func refreshAccessToken(refreshToken: String) async throws -> TokenResponse {
        try await postToken([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": OAuthConfiguration.clientID,
        ])
    }

    private func postToken(_ fields: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: Self.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue(
            "application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncode(fields).data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw OAuthError.tokenRequestFailed(
                status: status, body: String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private static func formEncode(_ fields: [String: String]) -> String {
        fields.map { key, value in
            let encoded = value.addingPercentEncoding(
                withAllowedCharacters: .urlQueryValueAllowed) ?? value
            return "\(key)=\(encoded)"
        }
        .joined(separator: "&")
    }
}

extension CharacterSet {
    /// Unreserved characters for a form-urlencoded value; everything else escaped.
    static let urlQueryValueAllowed = CharacterSet(
        charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}
