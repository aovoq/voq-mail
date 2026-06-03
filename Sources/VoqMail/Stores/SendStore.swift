//
//  SendStore.swift
//  VoqMail
//
//  Per-account send-in-flight state for the composer. Sending is partitioned by
//  account id (issue #8): switching the active account/mailbox while a send is in
//  flight must never let one account's completion surface on — or stomp —
//  another's UI. The view reads the active account's slice; a stale completion is
//  dropped via a per-account load-generation guard rather than written back.
//

import Foundation
import Observation

@Observable
@MainActor
final class SendStore {
    /// One account's send lifecycle. Held as a whole value and written back as a
    /// unit so `@Observable` fires (never mutate a nested field in place).
    struct State: Equatable {
        var isSending = false
        var errorMessage: String?
    }

    private var statesByAccount: [String: State] = [:]
    /// Bumped on each send start/reset per account; a suspended send compares its
    /// captured generation before writing so a stale result is dropped.
    private var generations: [String: Int] = [:]

    private let sender = MailSender()

    func state(for accountID: String) -> State {
        statesByAccount[accountID] ?? State()
    }

    func isSending(accountID: String) -> Bool {
        state(for: accountID).isSending
    }

    func errorMessage(accountID: String) -> String? {
        state(for: accountID).errorMessage
    }

    /// Clears an account's send state (e.g. on cancel or opening a fresh draft).
    /// Bumps the generation so an in-flight send's completion is dropped.
    func reset(accountID: String) {
        generations[accountID, default: 0] += 1
        statesByAccount[accountID] = State()
    }

    /// Drops an account's send state when the account is removed (issue #8 delete).
    func purge(accountID: String) {
        generations[accountID, default: 0] += 1
        statesByAccount[accountID] = nil
    }

    /// Sends the draft. Returns `true` on success so the caller can close the
    /// sheet. Writes back `isSending`/`errorMessage` only if no newer send/reset
    /// has superseded this one for the same account.
    func send(
        _ draft: MailDraft,
        authorizer: any GmailRequestAuthorizing
    ) async -> Bool {
        let accountID = draft.accountID
        generations[accountID, default: 0] += 1
        let generation = generations[accountID]!
        statesByAccount[accountID] = State(isSending: true, errorMessage: nil)

        do {
            try await authorizer.performGmailRequest(for: accountID) { accessToken in
                try await self.sender.send(draft, accessToken: accessToken)
            }
            guard isCurrent(accountID, generation) else { return false }
            statesByAccount[accountID] = State(isSending: false, errorMessage: nil)
            return true
        } catch {
            guard isCurrent(accountID, generation) else { return false }
            statesByAccount[accountID] = State(isSending: false, errorMessage: Self.message(for: error))
            return false
        }
    }

    private func isCurrent(_ accountID: String, _ generation: Int) -> Bool {
        generations[accountID] == generation
    }

    /// A reader-facing send-failure line. A Gmail HTTP error is reduced to its
    /// status (the raw response body is too noisy for the composer); anything else
    /// falls back to the system-localized description.
    private static func message(for error: Error) -> String? {
        if (error as? OAuthError)?.requiresReauthentication == true { return nil }
        if case let GmailError.requestFailed(status, _) = error {
            return "Couldn't send the message (HTTP \(status)). Please try again."
        }
        return "Couldn't send the message: \(error.localizedDescription)"
    }
}
