//
//  MailStore.swift
//  VoqMail
//
//  Observable message-list state for the running app: the fetched messages for
//  the selected mailbox plus the loading/error flags the UI reflects. Single
//  account for now (issue #8 broadens this).
//

import Foundation
import Observation

@Observable
@MainActor
final class MailStore {
    private(set) var messages: [MailMessage] = []
    private(set) var isLoading = false
    /// The mailbox the current `messages` belong to, or `nil` before any load.
    private(set) var loadedMailboxID: Mailbox.ID?
    var errorMessage: String?

    private let client = GmailClient()
    /// Bumped on every `load`; lets a superseded load (the user switched mailboxes
    /// mid-fetch) drop its late results instead of overwriting the current ones.
    private var loadGeneration = 0

    /// Loads the given mailbox's message list. `token` supplies a valid access
    /// token (it may refresh), so token failures are captured here alongside fetch
    /// failures. Switching mailboxes clears the stale list before the new load.
    func load(mailbox: Mailbox, token: @escaping @Sendable () async throws -> String) async {
        loadGeneration &+= 1
        let generation = loadGeneration
        isLoading = true
        errorMessage = nil
        if loadedMailboxID != mailbox.id { messages = [] }
        loadedMailboxID = mailbox.id
        defer { if generation == loadGeneration { isLoading = false } }

        do {
            let accessToken = try await token()
            let fetched = try await client.messages(
                labelID: mailbox.gmailLabelID, maxResults: 30, concurrency: 5, accessToken: accessToken)
            guard generation == loadGeneration else { return }
            messages = fetched
                .map { MailMessage(gmail: $0, mailboxID: mailbox.id) }
                .sorted { $0.receivedAt > $1.receivedAt }
        } catch {
            // A cancellation is the expected outcome of switching mailboxes mid-load;
            // only a still-current, non-cancelled failure is worth surfacing.
            guard generation == loadGeneration, !isCancellation(error) else { return }
            errorMessage = String(describing: error)
        }
    }
}

/// Whether an error is a cancellation — expected when a mailbox/message switch
/// tears down the superseded request — rather than a real failure to surface.
private func isCancellation(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    let nsError = error as NSError
    return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
}
