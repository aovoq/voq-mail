//
//  PKCE.swift
//  VoqMail
//
//  PKCE (RFC 7636) verifier/challenge generation for the S256 method, plus the
//  base64url helper and a random-string generator used for the OAuth `state`.
//

import Foundation
import CryptoKit
import Security

/// A PKCE verifier/challenge pair (S256). Create one per authorization request.
struct PKCE {
    let verifier: String
    let challenge: String

    init() {
        verifier = RandomString.urlSafe()
        challenge = Self.challenge(for: verifier)
    }

    private static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }
}

/// Generates URL-safe random strings (PKCE verifier, OAuth `state`).
enum RandomString {
    /// `byteCount` random bytes, base64url-encoded. 32 bytes ≈ 43 chars, within
    /// the PKCE verifier's 43–128 character range.
    static func urlSafe(byteCount: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }
}

extension Data {
    /// base64url without padding (RFC 4648 §5), as OAuth and PKCE require.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
