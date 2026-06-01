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

    /// Loads the given mailbox's message list. `token` supplies a valid access
    /// token (it may refresh), so token failures are captured here alongside fetch
    /// failures. Switching mailboxes clears the stale list before the new load.
    func load(mailbox: Mailbox, token: @escaping @Sendable () async throws -> String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        if loadedMailboxID != mailbox.id { messages = [] }
        loadedMailboxID = mailbox.id
        defer { isLoading = false }

        do {
            let accessToken = try await token()
            let fetched = try await client.messages(
                labelID: mailbox.gmailLabelID, maxResults: 30, concurrency: 5, accessToken: accessToken)
            messages = fetched
                .map { MailMessage(gmail: $0, mailboxID: mailbox.id) }
                .sorted { $0.receivedAt > $1.receivedAt }
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
