//
//  WebAuthenticationSession.swift
//  VoqMail
//
//  Wraps ASWebAuthenticationSession as a single async call and supplies the
//  window it anchors to (macOS requires a presentation context provider). The
//  session is retained for the duration of the flow.
//

import AppKit
import AuthenticationServices

@MainActor
final class WebAuthenticationSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    /// Held so the system session isn't deallocated mid-flow.
    private var session: ASWebAuthenticationSession?

    /// Opens `url` in an auth sheet and resumes with the redirect URL once the
    /// flow lands on `callbackScheme`.
    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                self?.session = nil
                if let error {
                    if let authError = error as? ASWebAuthenticationSessionError,
                       authError.code == .canceledLogin {
                        continuation.resume(throwing: OAuthError.userCancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: OAuthError.missingCallbackURL)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self
            self.session = session
            if !session.start() {
                self.session = nil
                continuation.resume(throwing: OAuthError.sessionStartFailed)
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? ASPresentationAnchor()
    }
}
