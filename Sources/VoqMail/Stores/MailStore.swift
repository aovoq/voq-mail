//
//  MailStore.swift
//  VoqMail
//
//  Observable inbox state for the running app: the fetched messages plus the
//  loading/error flags the UI reflects. Replaces the SampleData the views used
//  to read. Single account, INBOX only for now (issues #6–#8 broaden this).
//

import Foundation
import Observation

@Observable
@MainActor
final class MailStore {
    private(set) var messages: [MailMessage] = []
    private(set) var isLoading = false
    var errorMessage: String?

    private let client = GmailClient()

    /// Unread count for the INBOX sidebar badge.
    var inboxUnreadCount: Int {
        messages.reduce(0) { $0 + ($1.isRead ? 0 : 1) }
    }

    /// Loads the INBOX message list. `token` supplies a valid access token (it may
    /// refresh), so token failures are captured here alongside fetch failures.
    func loadInbox(token: @escaping @Sendable () async throws -> String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let accessToken = try await token()
            let fetched = try await client.messages(
                labelID: "INBOX", maxResults: 30, concurrency: 5, accessToken: accessToken)
            messages = fetched
                .map { MailMessage(gmail: $0, mailboxID: "inbox") }
                .sorted { $0.receivedAt > $1.receivedAt }
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
