//
//  AccountStore.swift
//  VoqMail
//
//  Observable list of signed-in accounts and the actions that change it: adding
//  an account via OAuth, and restoring saved accounts on launch. UI-facing
//  state, so it lives on the main actor. Token mechanics are delegated to
//  TokenProvider; this type stays focused on what the UI observes.
//

import Foundation
import Observation

@Observable
@MainActor
final class AccountStore {
    /// Accounts shown as signed in.
    private(set) var accounts: [Account] = []
    /// True while a consent flow is in progress (drives the button state).
    private(set) var isAuthenticating = false
    /// Last failure worth showing, or nil. User-cancellation is not recorded.
    var lastError: String?

    private let tokenProvider = TokenProvider()
    private let keychain = KeychainTokenStore()
    private let profiles = GmailProfileService()
    private let webAuth = WebAuthenticationSession()

    /// Launches the OAuth consent flow and adds the resulting account.
    func addAccount() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        lastError = nil
        defer { isAuthenticating = false }

        do {
            let authenticator = AccountAuthenticator(webAuth: webAuth)
            let (account, tokens) = try await authenticator.signIn()
            await tokenProvider.store(tokens, for: account.email)
            upsert(account)
        } catch OAuthError.userCancelled {
            // Sheet dismissed — nothing to report.
        } catch {
            lastError = String(describing: error)
        }
    }

    /// Restores accounts saved in the Keychain: refresh each token and fetch its
    /// address so the app shows signed-in state without a re-login. A single
    /// account that fails to restore does not block the others; surfacing a
    /// re-auth prompt for it is issue #11.
    func restoreAccounts() async {
        do {
            for email in try keychain.storedAccountEmails() {
                do {
                    let token = try await tokenProvider.accessToken(for: email)
                    let address = try await profiles.emailAddress(accessToken: token)
                    upsert(Account(email: address, displayName: nil))
                } catch {
                    lastError = String(describing: error)
                }
            }
        } catch {
            lastError = String(describing: error)
        }
    }

    /// A valid access token for an account, for use by Gmail API calls (#4+).
    func accessToken(for email: String) async throws -> String {
        try await tokenProvider.accessToken(for: email)
    }

    private func upsert(_ account: Account) {
        if !accounts.contains(where: { $0.id == account.id }) {
            accounts.append(account)
        }
    }
}
