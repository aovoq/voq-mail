//
//  MailStore.swift
//  VoqMail
//
//  Observable message-list state for the running app: the fetched messages for
//  the selected mailbox plus the loading/error flags the UI reflects. State is
//  partitioned by account id (issue #8): each account keeps its own messages,
//  paging cursor, and load generation, so switching accounts never lets one
//  account's late response surface on (or stomp) another's list. The UI-facing
//  properties reflect the *active* account — the one whose mailbox was last
//  loaded — so the views read `messages`/`isLoading`/… exactly as before.
//

import Foundation
import Observation

@Observable
@MainActor
final class MailStore {
    /// Per-account message-list state. Kept as one value so a mutation always
    /// writes the whole keyed entry back (`statesByAccount[id] = s`), which is
    /// what makes @Observable fire — mutating a field two levels deep would not.
    private struct AccountMessages {
        var messages: [MailMessage] = []
        /// The mailbox the current `messages` belong to, or `nil` before any load.
        var loaded: Mailbox?
        /// Token for the next page, or `nil` when exhausted / unloaded.
        var nextPageToken: String?
        /// Bumped on every `load`; lets a superseded load or stale page append drop
        /// its late results (the user switched mailboxes mid-fetch).
        var loadGeneration = 0
        var isLoading = false
        var isLoadingMore = false
        var errorMessage: String?
    }

    private var statesByAccount: [String: AccountMessages] = [:]
    /// The account whose state the computed properties below reflect. Set on every
    /// `load` to the loaded mailbox's account.
    private(set) var activeAccountID: String?

    /// How many messages to fetch per page.
    private static let pageSize = 30

    private let client = GmailClient()

    // MARK: - Active-account view

    private var active: AccountMessages {
        activeAccountID.flatMap { statesByAccount[$0] } ?? AccountMessages()
    }

    var messages: [MailMessage] { active.messages }
    /// True during the initial load of a mailbox (an empty list).
    var isLoading: Bool { active.isLoading }
    /// True while appending the next page to an already-loaded list.
    var isLoadingMore: Bool { active.isLoadingMore }
    var errorMessage: String? { active.errorMessage }
    /// The id of the mailbox the current `messages` belong to.
    var loadedMailboxID: Mailbox.ID? { active.loaded?.id }
    /// Whether another page can be appended via `loadMore`.
    var canLoadMore: Bool { active.nextPageToken != nil }

    private func state(for accountID: String) -> AccountMessages {
        statesByAccount[accountID] ?? AccountMessages()
    }

    /// Drops an account's message state (used when the account is removed).
    func purge(accountID: String) {
        statesByAccount[accountID] = nil
        if activeAccountID == accountID { activeAccountID = nil }
    }

    // MARK: - Loading

    /// Loads the given mailbox's first page for its account. `authorizer` owns token
    /// refresh and the Gmail-401 retry path, so stale cached access tokens recover
    /// before this store decides whether to surface a failure.
    func load(mailbox: Mailbox, authorizer: any GmailRequestAuthorizing) async {
        let accountID = mailbox.accountID
        activeAccountID = accountID

        var s = state(for: accountID)
        s.loadGeneration &+= 1
        let generation = s.loadGeneration
        s.isLoading = true
        s.errorMessage = nil
        if s.loaded?.id != mailbox.id {
            s.messages = []
            s.nextPageToken = nil
        }
        s.loaded = mailbox
        statesByAccount[accountID] = s
        defer {
            if var s = statesByAccount[accountID], s.loadGeneration == generation {
                s.isLoading = false
                statesByAccount[accountID] = s
            }
        }

        do {
            let page = try await authorizer.performGmailRequest(for: accountID) { accessToken in
                try await self.client.messages(
                    labelID: mailbox.gmailLabelID, maxResults: Self.pageSize,
                    pageToken: nil, concurrency: 5, accessToken: accessToken)
            }
            guard statesByAccount[accountID]?.loadGeneration == generation else { return }
            var s = state(for: accountID)
            s.messages = page.messages
                .map { MailMessage(gmail: $0, accountID: accountID, mailboxID: mailbox.id) }
                .sorted { $0.receivedAt > $1.receivedAt }
            s.nextPageToken = page.nextPageToken
            statesByAccount[accountID] = s
        } catch {
            // A cancellation is the expected outcome of switching mailboxes mid-load;
            // a lapsed token is already surfaced by the re-auth banner (issue #11).
            // Only a still-current failure that's neither is worth surfacing here.
            guard statesByAccount[accountID]?.loadGeneration == generation,
                  shouldSurface(error) else { return }
            var s = state(for: accountID)
            s.errorMessage = String(describing: error)
            statesByAccount[accountID] = s
        }
    }

    /// Reloads the account's currently-loaded mailbox from scratch. Used after a
    /// re-auth so the message list recovers on its own, without the user having to
    /// switch mailboxes to re-fire the view's load (issue #11). A no-op unless this
    /// account is the active one: `load` sets `activeAccountID`, so reloading a
    /// non-visible account here would swap its messages under the current header.
    /// A non-active account's list reloads naturally when the user navigates to it.
    func reloadActive(accountID: String, authorizer: any GmailRequestAuthorizing) async {
        guard activeAccountID == accountID, let mailbox = state(for: accountID).loaded else { return }
        await load(mailbox: mailbox, authorizer: authorizer)
    }

    /// Appends the next page to the account's current mailbox list. No-op when a
    /// load is in flight or there is no further page; stops paging once the token
    /// runs out.
    func loadMore(accountID: String, authorizer: any GmailRequestAuthorizing) async {
        var s = state(for: accountID)
        guard !s.isLoading, !s.isLoadingMore,
              let mailbox = s.loaded,
              let pageToken = s.nextPageToken else { return }
        let generation = s.loadGeneration
        s.isLoadingMore = true
        s.errorMessage = nil
        statesByAccount[accountID] = s
        defer {
            if var s = statesByAccount[accountID] {
                s.isLoadingMore = false
                statesByAccount[accountID] = s
            }
        }

        do {
            let page = try await authorizer.performGmailRequest(for: accountID) { accessToken in
                try await self.client.messages(
                    labelID: mailbox.gmailLabelID, maxResults: Self.pageSize,
                    pageToken: pageToken, concurrency: 5, accessToken: accessToken)
            }
            // A mailbox switch since this page was requested invalidates the append.
            guard statesByAccount[accountID]?.loadGeneration == generation else { return }
            var s = state(for: accountID)
            let existing = Set(s.messages.map(\.id))
            let added = page.messages
                .map { MailMessage(gmail: $0, accountID: accountID, mailboxID: mailbox.id) }
                .filter { !existing.contains($0.id) }
            s.messages = (s.messages + added).sorted { $0.receivedAt > $1.receivedAt }
            s.nextPageToken = page.nextPageToken
            statesByAccount[accountID] = s
        } catch {
            guard statesByAccount[accountID]?.loadGeneration == generation,
                  shouldSurface(error) else { return }
            var s = state(for: accountID)
            s.errorMessage = String(describing: error)
            statesByAccount[accountID] = s
        }
    }

    // MARK: - Read state

    /// Flips the read state of a message in the given account, or no-ops if it is
    /// already in `read`.
    func toggleRead(messageID: MailMessage.ID, accountID: String, authorizer: any GmailRequestAuthorizing) async {
        guard let message = state(for: accountID).messages.first(where: { $0.id == messageID }) else { return }
        await setRead(!message.isRead, messageID: messageID, accountID: accountID, authorizer: authorizer)
    }

    /// Sets a message read or unread by adding/removing Gmail's `UNREAD` label. The
    /// UI updates optimistically (bold flips immediately); a failed modify rolls the
    /// label set back. A no-op when the message is already in the requested state.
    func setRead(_ read: Bool, messageID: MailMessage.ID, accountID: String, authorizer: any GmailRequestAuthorizing) async {
        var s = state(for: accountID)
        guard let index = s.messages.firstIndex(where: { $0.id == messageID }),
              s.messages[index].isRead != read else { return }

        let previous = s.messages[index].labelIds
        s.messages[index].labelIds = read
            ? previous.filter { $0 != "UNREAD" }
            : previous + ["UNREAD"]
        statesByAccount[accountID] = s

        do {
            try await authorizer.performGmailRequest(for: accountID) { accessToken in
                try await self.client.modifyLabels(
                    messageID: messageID,
                    addLabelIDs: read ? [] : ["UNREAD"],
                    removeLabelIDs: read ? ["UNREAD"] : [],
                    accessToken: accessToken)
            }
        } catch {
            // A cancellation (the message was deselected before the modify returned)
            // leaves the optimistic state in place rather than reverting it.
            guard !isCancellation(error) else { return }
            var s = state(for: accountID)
            if let index = s.messages.firstIndex(where: { $0.id == messageID }) {
                s.messages[index].labelIds = previous
            }
            if (error as? OAuthError)?.requiresReauthentication != true {
                s.errorMessage = String(describing: error)
            }
            statesByAccount[accountID] = s
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

/// Whether a load failure is worth showing in the list. Cancellations are
/// expected churn; a lapsed credential is owned by the re-auth banner (issue
/// #11), so neither should paint a red error over the messages.
private func shouldSurface(_ error: Error) -> Bool {
    if (error as? OAuthError)?.requiresReauthentication == true { return false }
    return !isCancellation(error)
}
