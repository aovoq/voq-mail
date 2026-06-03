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

/// Runs Gmail API calls with account-owned token recovery. The generic method lets
/// each store keep its Gmail-specific result type while centralizing the 401 →
/// refresh → re-authentication decision in AccountStore.
@MainActor
protocol GmailRequestAuthorizing: AnyObject {
    func performGmailRequest<T>(
        for email: String,
        _ operation: @MainActor @escaping @Sendable (String) async throws -> T
    ) async throws -> T
}

@Observable
@MainActor
final class AccountStore: GmailRequestAuthorizing {
    /// Accounts shown as signed in.
    private(set) var accounts: [Account] = []
    /// True while a consent flow is in progress (drives the button state).
    private(set) var isAuthenticating = false
    /// Last failure worth showing, or nil. User-cancellation is not recorded.
    var lastError: String?
    /// Accounts whose refresh token was rejected (expired or revoked). They stay in
    /// `accounts` so the UI keeps showing them, but flagged so a re-login banner
    /// appears and their failed loads aren't silent (issue #11).
    private(set) var accountsNeedingReauth: Set<String> = []

    private let tokenProvider = TokenProvider()
    private let keychain = KeychainTokenStore()
    private let profiles = GmailProfileService()
    private let webAuth = WebAuthenticationSession()

    /// Per-account purge hook, run after an account is removed. Wired once at
    /// composition (ContentView) so this store can drive the per-account store
    /// slices' cleanup without depending on those stores itself (issue #8).
    var onAccountRemoved: ((String) -> Void)?
    /// Per-account hook, run after a lapsed account is re-authenticated, so the
    /// stores that errored out on the dead token can reload. Wired in ContentView
    /// alongside `onAccountRemoved`, for the same reason (issue #11).
    var onAccountReauthenticated: ((String) -> Void)?

    /// Launches the OAuth consent flow and adds the resulting account, returning the
    /// signed-in address (nil if cancelled or failed). `loginHint` pre-selects an
    /// address on the consent screen — passed by `reauthenticate` so re-signing a
    /// lapsed account targets the right one.
    @discardableResult
    func addAccount(loginHint: String? = nil) async -> String? {
        guard !isAuthenticating else { return nil }
        isAuthenticating = true
        lastError = nil
        defer { isAuthenticating = false }

        do {
            let authenticator = AccountAuthenticator(webAuth: webAuth)
            let (account, tokens) = try await authenticator.signIn(loginHint: loginHint)
            await tokenProvider.store(tokens, for: account.email)
            upsert(account)
            // A fresh token clears any re-auth flag; if this *was* a re-auth, let the
            // stores that errored on the dead token reload (issue #11).
            if accountsNeedingReauth.remove(account.email) != nil {
                onAccountReauthenticated?(account.email)
            }
            return account.email
        } catch OAuthError.userCancelled {
            // Sheet dismissed — nothing to report.
            return nil
        } catch {
            lastError = String(describing: error)
            return nil
        }
    }

    /// Re-runs the consent flow for a lapsed account, pinned to its address. Reuses
    /// `addAccount`: signing back into the same id refreshes its Keychain item,
    /// clears the re-auth flag, and triggers a reload. `login_hint` is only a hint,
    /// so if the user picks a different account the lapsed one stays flagged — say
    /// so rather than leaving its banner row silently unchanged (issue #11).
    func reauthenticate(_ email: String) async {
        let signedInAs = await addAccount(loginHint: email)
        if let signedInAs, signedInAs != email {
            lastError = "Signed in as \(signedInAs); \(email) still needs re-authentication."
        }
    }

    /// Whether `email` is flagged for re-authentication (its refresh token lapsed).
    func needsReauthentication(_ email: String) -> Bool {
        accountsNeedingReauth.contains(email)
    }

    /// Restores accounts saved in the Keychain: refresh each token and fetch its
    /// address so the app shows signed-in state without a re-login. A single
    /// account that fails to restore does not block the others.
    func restoreAccounts() async {
        do {
            let emails = try keychain.storedAccountEmails()
            // Show the saved accounts immediately from their Keychain emails (the
            // account id) so the sidebar labels and message list can paint from the
            // cache without waiting on the network (issue #12). The refresh below then
            // confirms each credential and corrects the display address.
            for email in emails { upsert(Account(email: email, displayName: nil)) }
            for email in emails {
                // The provisional upsert above makes the account removable before its
                // refresh/profile fetch finishes. If the user removed it during a prior
                // iteration's await, skip it — re-upserting would resurrect an account
                // whose Keychain item and caches were just purged (issue #8/#12).
                guard accounts.contains(where: { $0.id == email }) else { continue }
                do {
                    let token = try await accessToken(for: email)
                    let address = try await profiles.emailAddress(accessToken: token)
                    // Re-check after the awaits: removal may have happened during them.
                    guard accounts.contains(where: { $0.id == email }) else { continue }
                    upsert(Account(email: address, displayName: nil))
                } catch let error as OAuthError where error.requiresReauthentication {
                    // The saved credential lapsed (Testing-mode 7-day expiry, revoked,
                    // or missing). Keep the account visible and flagged — `accessToken`
                    // already added it to `accountsNeedingReauth` — so the UI prompts a
                    // re-login instead of the account silently vanishing (issue #11) —
                    // unless it was removed mid-restore, in which case stay removed.
                    guard accounts.contains(where: { $0.id == email }) else { continue }
                    upsert(Account(email: email, displayName: nil))
                } catch {
                    lastError = String(describing: error)
                }
            }
        } catch {
            lastError = String(describing: error)
        }
    }

    /// Removes an account: deletes its Keychain refresh token, drops its cached
    /// access token, removes it from the signed-in list, then runs the registered
    /// `onAccountRemoved` hook to purge the per-account store slices. Deleting by
    /// `id` — the same normalized address `storedAccountEmails()` returns —
    /// guarantees the Keychain item is hit, so the account does not reappear on
    /// relaunch.
    func removeAccount(_ id: String) async {
        do {
            try keychain.deleteRefreshToken(for: id)
        } catch {
            lastError = String(describing: error)
        }
        await tokenProvider.clearCache(for: id)
        accounts.removeAll { $0.id == id }
        // Drop any re-auth flag too, else the banner would keep prompting for an
        // account that no longer exists and its button would re-add it (issue #11).
        accountsNeedingReauth.remove(id)
        onAccountRemoved?(id)
    }

    /// A valid access token for an account, for use by Gmail API calls (#4+). This
    /// is the single point every token refresh passes through, so a refresh that
    /// finds the stored credential dead (expired/revoked/missing) flags the account
    /// here — no caller can swallow that silently (issue #11).
    func accessToken(for email: String) async throws -> String {
        do {
            return try await tokenProvider.accessToken(for: email)
        } catch let error as OAuthError where error.requiresReauthentication {
            // Don't flag an account that is no longer signed in — e.g. one removed
            // during a launch restore that was still awaiting its token — or the flag
            // would orphan a row that no longer exists (issue #8).
            if accounts.contains(where: { $0.id == email }) {
                accountsNeedingReauth.insert(email)
            }
            throw error
        }
    }

    /// Executes one Gmail API operation. If Gmail rejects the cached access token
    /// with 401, drop that cache entry, refresh once, and retry the operation. If
    /// refresh proves the credential is gone, or Gmail still rejects the fresh token,
    /// flag the account for the shared re-authentication UI instead of leaving the
    /// individual store to paint a raw HTTP error.
    func performGmailRequest<T>(
        for email: String,
        _ operation: @MainActor @escaping @Sendable (String) async throws -> T
    ) async throws -> T {
        let token = try await accessToken(for: email)
        do {
            let result = try await operation(token)
            accountsNeedingReauth.remove(email)
            return result
        } catch let error as GmailError where error.isUnauthorized {
            await tokenProvider.clearCache(for: email)
            let refreshed = try await accessToken(for: email)
            do {
                let result = try await operation(refreshed)
                accountsNeedingReauth.remove(email)
                return result
            } catch let retryError as GmailError where retryError.isUnauthorized {
                await tokenProvider.clearCache(for: email)
                accountsNeedingReauth.insert(email)
                throw OAuthError.accessTokenRejected
            }
        }
    }

    private func upsert(_ account: Account) {
        if !accounts.contains(where: { $0.id == account.id }) {
            accounts.append(account)
        }
    }
}
