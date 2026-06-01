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
    /// True during the initial load of a mailbox (an empty list).
    private(set) var isLoading = false
    /// True while appending the next page to an already-loaded list.
    private(set) var isLoadingMore = false
    var errorMessage: String?

    /// How many messages to fetch per page.
    private static let pageSize = 30

    private let client = GmailClient()
    /// The mailbox the current `messages` belong to, or `nil` before any load.
    private var loaded: Mailbox?
    /// Token for the next page, or `nil` when the list is exhausted / unloaded.
    private var nextPageToken: String?
    /// Bumped on every `load`; lets a superseded load or a stale page append (the
    /// user switched mailboxes mid-fetch) drop its late results.
    private var loadGeneration = 0

    /// The id of the mailbox the current `messages` belong to.
    var loadedMailboxID: Mailbox.ID? { loaded?.id }
    /// Whether another page can be appended via `loadMore`.
    var canLoadMore: Bool { nextPageToken != nil }

    /// Loads the given mailbox's first page. `token` supplies a valid access token
    /// (it may refresh), so token failures are captured here alongside fetch
    /// failures. Switching mailboxes clears the stale list before the new load.
    func load(mailbox: Mailbox, token: @escaping @Sendable () async throws -> String) async {
        loadGeneration &+= 1
        let generation = loadGeneration
        isLoading = true
        errorMessage = nil
        if loaded?.id != mailbox.id {
            messages = []
            nextPageToken = nil
        }
        loaded = mailbox
        defer { if generation == loadGeneration { isLoading = false } }

        do {
            let accessToken = try await token()
            let page = try await client.messages(
                labelID: mailbox.gmailLabelID, maxResults: Self.pageSize,
                pageToken: nil, concurrency: 5, accessToken: accessToken)
            guard generation == loadGeneration else { return }
            messages = page.messages
                .map { MailMessage(gmail: $0, mailboxID: mailbox.id) }
                .sorted { $0.receivedAt > $1.receivedAt }
            nextPageToken = page.nextPageToken
        } catch {
            // A cancellation is the expected outcome of switching mailboxes mid-load;
            // only a still-current, non-cancelled failure is worth surfacing.
            guard generation == loadGeneration, !isCancellation(error) else { return }
            errorMessage = String(describing: error)
        }
    }

    /// Appends the next page to the current mailbox's list. No-op when a load is in
    /// flight or there is no further page; stops paging once the token runs out.
    func loadMore(token: @escaping @Sendable () async throws -> String) async {
        guard !isLoading, !isLoadingMore,
              let mailbox = loaded,
              let pageToken = nextPageToken else { return }
        let generation = loadGeneration
        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }

        do {
            let accessToken = try await token()
            let page = try await client.messages(
                labelID: mailbox.gmailLabelID, maxResults: Self.pageSize,
                pageToken: pageToken, concurrency: 5, accessToken: accessToken)
            // A mailbox switch since this page was requested invalidates the append.
            guard generation == loadGeneration else { return }
            let existing = Set(messages.map(\.id))
            let added = page.messages
                .map { MailMessage(gmail: $0, mailboxID: mailbox.id) }
                .filter { !existing.contains($0.id) }
            messages = (messages + added).sorted { $0.receivedAt > $1.receivedAt }
            nextPageToken = page.nextPageToken
        } catch {
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
