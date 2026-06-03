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
import SwiftData

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

    /// The SwiftData-backed cache (issue #12). Nil until `attach(context:)` runs at
    /// app launch; cache reads/writes are no-ops while nil so previews work unattached.
    private var cache: MailCache?

    /// Accounts with a `historySync` in flight, so the focus and interval pollers
    /// (issue #13) firing together don't run the same diff twice.
    private var syncingAccounts: Set<String> = []

    /// Per-account removal counter, bumped by `purge`. A load/sync suspended at an
    /// await captures it and re-checks before any durable cache/checkpoint write, so
    /// an account removed mid-flight can't have its data re-persisted after sign-out
    /// (issue #8/#12). Distinct from `loadGeneration`, which lives inside the
    /// per-account state `purge` discards — this survives the purge.
    private var purgeGenerations: [String: Int] = [:]

    /// One-time latch so the background pollers (issue #13) start exactly once for the
    /// app's lifetime: `ContentView.task` can re-run (a second window, a re-created
    /// root view), and its pollers are unstructured Tasks that outlive the view, so
    /// without this every recreation would stack another duplicate set.
    private var pollingStarted = false

    /// Trips the polling latch. Returns true only on the first call, so the caller
    /// starts the pollers just once.
    func beginPolling() -> Bool {
        guard !pollingStarted else { return false }
        pollingStarted = true
        return true
    }

    /// Whether `accountID` was purged (signed out) since `purgeGen` was captured.
    private func wasPurged(_ accountID: String, since purgeGen: Int) -> Bool {
        (purgeGenerations[accountID] ?? 0) != purgeGen
    }

    /// Binds the store to the app's persistent cache. Called once at composition
    /// (ContentView) before any account restore, so the first load can paint from disk.
    func attach(context: ModelContext) {
        cache = MailCache(context: context)
    }

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

    /// Drops an account's message state (used when the account is removed). Also
    /// clears its cached messages and sync checkpoint so a removed account leaves
    /// nothing on disk to resurrect (issue #8 / #12).
    func purge(accountID: String) {
        purgeGenerations[accountID, default: 0] &+= 1
        statesByAccount[accountID] = nil
        if activeAccountID == accountID { activeAccountID = nil }
        cache?.deleteAllMessages(accountID: accountID)
        cache?.deleteSyncState(accountID: accountID)
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
        // Captured alongside the generation: `loadGeneration` lives inside the state
        // `purge` discards, so a remove+re-add resets it and a stale in-flight load
        // could match the re-added account's fresh generation. `purgeGen` survives the
        // purge, so the durable writes below also gate on it (issue #8).
        let purgeGen = purgeGenerations[accountID] ?? 0
        s.isLoading = true
        s.errorMessage = nil
        if s.loaded?.id != mailbox.id {
            s.messages = []
            s.nextPageToken = nil
        }
        s.loaded = mailbox
        statesByAccount[accountID] = s

        // Cache-first (issue #12): paint the stored rows immediately so the list
        // shows without waiting on the network — the fetch below becomes a
        // background refresh that overwrites them. Skipped when the list already
        // holds messages (a same-mailbox reload keeps them visible). Honors the
        // load generation like every write here.
        if let cache, s.messages.isEmpty {
            let cached = cache.messages(
                accountID: accountID, labelID: mailbox.gmailLabelID,
                mailboxID: mailbox.id, limit: Self.pageSize)
            if !cached.isEmpty, statesByAccount[accountID]?.loadGeneration == generation {
                var s = state(for: accountID)
                s.messages = cached
                s.isLoading = false
                statesByAccount[accountID] = s
            }
        }

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
            guard statesByAccount[accountID]?.loadGeneration == generation,
                  !wasPurged(accountID, since: purgeGen) else { return }
            let fresh = page.messages
                .map { MailMessage(gmail: $0, accountID: accountID, mailboxID: mailbox.id) }
                .sorted { $0.receivedAt > $1.receivedAt }
            var s = state(for: accountID)
            s.messages = fresh
            s.nextPageToken = page.nextPageToken
            statesByAccount[accountID] = s
            // Write through to the cache and seed the incremental-sync checkpoint
            // (issue #13) from the freshest message's historyId, only if none is set
            // yet — once seeded, `historySync` owns advancing it.
            cache?.upsert(fresh)
            // Release the loading state before the seed: an empty mailbox seeds the
            // checkpoint from getProfile (an extra await), and it should show its empty
            // state immediately rather than holding a spinner through that fetch.
            if var s = statesByAccount[accountID], s.loadGeneration == generation {
                s.isLoading = false
                statesByAccount[accountID] = s
            }
            await seedHistoryIdIfNeeded(accountID: accountID, authorizer: authorizer)
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
        let purgeGen = purgeGenerations[accountID] ?? 0
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
            // A mailbox switch (or an account removal that resets the generation) since
            // this page was requested invalidates the append and its cache write.
            guard statesByAccount[accountID]?.loadGeneration == generation,
                  !wasPurged(accountID, since: purgeGen) else { return }
            var s = state(for: accountID)
            let existing = Set(s.messages.map(\.id))
            let added = page.messages
                .map { MailMessage(gmail: $0, accountID: accountID, mailboxID: mailbox.id) }
                .filter { !existing.contains($0.id) }
            s.messages = (s.messages + added).sorted { $0.receivedAt > $1.receivedAt }
            s.nextPageToken = page.nextPageToken
            statesByAccount[accountID] = s
            cache?.upsert(added)
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
        // Keep the cached row's read state in step with the optimistic flip.
        cache?.setLabels(accountID: accountID, gmailID: messageID, labelIds: s.messages[index].labelIds)

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
            cache?.setLabels(accountID: accountID, gmailID: messageID, labelIds: previous)
        }
    }

    // MARK: - Incremental sync (issue #13)

    /// Pulls `users.history.list` from the account's saved checkpoint and applies
    /// the diff (new / deleted / relabelled messages) to the cache and — when this
    /// account is the active one — to the visible list, so new mail appears without
    /// a restart. A 404 (checkpoint older than Gmail's history retention) falls back
    /// to a full re-sync. When no checkpoint exists yet it re-establishes one by
    /// reloading the active mailbox, so a failed earlier reseed self-heals on a later poll.
    func historySync(accountID: String, authorizer: any GmailRequestAuthorizing) async {
        guard let cache, !syncingAccounts.contains(accountID) else { return }
        syncingAccounts.insert(accountID)
        defer { syncingAccounts.remove(accountID) }
        // No checkpoint yet — never seeded, or a full re-sync after a 404 failed before
        // it could reseed. Re-establish it by reloading the active mailbox (which seeds
        // on success); a still-failing reload leaves it nil to retry on the next poll,
        // rather than the early-return stalling sync for this account forever. A no-op
        // for non-active accounts, which reseed when the user next opens them.
        guard let startHistoryId = cache.lastHistoryId(accountID: accountID) else {
            await reloadActive(accountID: accountID, authorizer: authorizer)
            return
        }
        let generation = state(for: accountID).loadGeneration
        // Captured so a removal during any await below aborts the durable writes — a
        // signed-out account must not have its cache/checkpoint re-created (issue #8).
        let purgeGen = purgeGenerations[accountID] ?? 0

        do {
            let (records, newHistoryId) = try await authorizer.performGmailRequest(for: accountID) { accessToken in
                try await self.fetchHistory(startHistoryId: startHistoryId, accessToken: accessToken)
            }
            guard !wasPurged(accountID, since: purgeGen) else { return }
            guard !records.isEmpty else {
                if let newHistoryId { cache.setLastHistoryId(newHistoryId, accountID: accountID) }
                return
            }
            try await applyHistory(
                records, accountID: accountID, generation: generation,
                purgeGen: purgeGen, authorizer: authorizer)
            guard !wasPurged(accountID, since: purgeGen) else { return }
            cache.setLastHistoryId(newHistoryId ?? startHistoryId, accountID: accountID)
        } catch let error as GmailError where error.isHistoryGone {
            // The checkpoint is older than Gmail's ~1-week history retention. Clear it
            // and full-resync the visible mailbox; non-active accounts re-sync the next
            // time the user opens them (their `load` reseeds the checkpoint).
            guard !wasPurged(accountID, since: purgeGen) else { return }
            cache.setLastHistoryId(nil, accountID: accountID)
            await reloadActive(accountID: accountID, authorizer: authorizer)
        } catch {
            // Cancellation, a lapsed credential (owned by the re-auth banner, issue
            // #11), or a transient failure: leave the checkpoint so the next poll
            // retries the same diff rather than skipping it.
        }
    }

    /// Walks every page of the history diff under one token, returning the records
    /// and the newest `historyId` to checkpoint at.
    private func fetchHistory(
        startHistoryId: String, accessToken: String
    ) async throws -> (records: [GmailHistory], historyId: String?) {
        var records: [GmailHistory] = []
        var latestHistoryId: String?
        var pageToken: String?
        repeat {
            let page = try await client.history(
                startHistoryId: startHistoryId, pageToken: pageToken, accessToken: accessToken)
            records.append(contentsOf: page.history ?? [])
            latestHistoryId = page.historyId ?? latestHistoryId
            pageToken = page.nextPageToken
        } while pageToken != nil
        return (records, latestHistoryId)
    }

    /// Reduces the diff to deletions + each surviving message's current labels, then
    /// applies it to the cache and (if active) the in-memory list. Hydrates metadata
    /// only for messages not already cached; existing rows are just relabelled.
    private func applyHistory(
        _ records: [GmailHistory], accountID: String, generation: Int,
        purgeGen: Int, authorizer: any GmailRequestAuthorizing
    ) async throws {
        guard let cache else { return }

        // Fold the chronological records into a final state per message id.
        var deleted: Set<String> = []
        var currentLabels: [String: [String]] = [:]
        for record in records {
            for change in record.messagesDeleted ?? [] {
                deleted.insert(change.message.id)
                currentLabels[change.message.id] = nil
            }
            for change in record.messagesAdded ?? [] {
                deleted.remove(change.message.id)
                currentLabels[change.message.id] = change.message.labelIds ?? []
            }
            for change in (record.labelsAdded ?? []) + (record.labelsRemoved ?? []) {
                guard !deleted.contains(change.message.id) else { continue }
                currentLabels[change.message.id] =
                    change.message.labelIds ?? currentLabels[change.message.id] ?? []
            }
        }

        // Hydrate metadata for surviving messages we don't already hold. A per-id 404
        // (a message added then deleted after the snapshot) is skipped, but any other
        // failure throws out of here so `historySync` leaves the checkpoint un-advanced
        // and the same diff is retried next poll — a transient blip must not silently
        // drop a diff's worth of genuinely-new mail.
        let toHydrate = currentLabels.keys.filter { !cache.hasMessage(accountID: accountID, gmailID: $0) }
        var hydrated: [String: GmailMessage] = [:]
        if !toHydrate.isEmpty {
            let fetched = try await authorizer.performGmailRequest(for: accountID) { accessToken in
                try await self.client.messagesMetadata(
                    ids: Array(toHydrate), concurrency: 5, accessToken: accessToken)
            }
            hydrated = Dictionary(fetched.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        }

        // If the account was removed while hydrating, abort before any durable write —
        // `purge` already deleted its cache, and re-inserting here would resurrect a
        // signed-out account's message metadata on disk (issue #8). Everything from
        // here to the in-memory write runs without an await, so one check suffices.
        guard !wasPurged(accountID, since: purgeGen) else { return }

        // Authoritative final labels per surviving id: a freshly-fetched message's
        // labels are more current than the history snapshot, so they win. Built as a
        // separate map so nothing is mutated mid-iteration below.
        var finalLabels = currentLabels
        for (id, gmail) in hydrated {
            finalLabels[id] = gmail.labelIds ?? finalLabels[id] ?? []
        }

        // Apply to the cache: deletions, then insert (hydrated) or relabel (existing).
        cache.deleteMessages(accountID: accountID, gmailIDs: deleted)
        var upserts: [MailMessage] = []
        for (id, labels) in finalLabels {
            if let gmail = hydrated[id] {
                upserts.append(MailMessage(gmail: gmail, accountID: accountID, mailboxID: ""))
            } else {
                cache.setLabels(accountID: accountID, gmailID: id, labelIds: labels)
            }
        }
        cache.upsert(upserts)

        // Reflect the diff in the visible list only when this account is active and a
        // mailbox is loaded — mirrors `reloadActive`'s rule of not touching a
        // non-visible account's list. Honor the captured generation.
        guard activeAccountID == accountID,
              statesByAccount[accountID]?.loadGeneration == generation,
              let mailbox = statesByAccount[accountID]?.loaded else { return }
        let label = mailbox.gmailLabelID
        var s = state(for: accountID)
        var messages = s.messages
        messages.removeAll { deleted.contains($0.id) }
        for (id, labels) in finalLabels {
            let belongs = labels.contains(label)
            if let index = messages.firstIndex(where: { $0.id == id }) {
                if belongs { messages[index].labelIds = labels } else { messages.remove(at: index) }
            } else if belongs {
                if let gmail = hydrated[id] {
                    messages.append(MailMessage(gmail: gmail, accountID: accountID, mailboxID: mailbox.id))
                } else if let cached = cache.message(accountID: accountID, gmailID: id, mailboxID: mailbox.id) {
                    messages.append(cached)
                }
            }
        }
        s.messages = messages.sorted { $0.receivedAt > $1.receivedAt }
        statesByAccount[accountID] = s
    }

    /// Seeds the incremental-sync checkpoint after a full load, only if none is set yet
    /// — `historySync` owns advancing it from there. Seeds from the account-level
    /// `historyId` (`users.getProfile`), NOT from a message's historyId: a low-traffic
    /// mailbox's newest message can carry an id that already predates Gmail's history
    /// retention even though the account has newer changes elsewhere, which would make
    /// the very next `history.list` 404 and loop full reloads forever. getProfile always
    /// returns a currently-valid id (and covers an empty mailbox, which has no message id
    /// to seed from at all). The narrow window between the list and this call is
    /// re-applied idempotently on the next diff, or recovered by a full reload.
    private func seedHistoryIdIfNeeded(
        accountID: String, authorizer: any GmailRequestAuthorizing
    ) async {
        guard let cache, cache.lastHistoryId(accountID: accountID) == nil else { return }
        let purgeGen = purgeGenerations[accountID] ?? 0
        let fetched = try? await authorizer.performGmailRequest(for: accountID) { accessToken in
            try await self.client.profileHistoryId(accessToken: accessToken)
        }
        // The account may have been removed during the profile fetch; don't re-create a
        // checkpoint for it, and don't clobber a checkpoint a concurrent path just set.
        guard let historyId = fetched ?? nil,
              !wasPurged(accountID, since: purgeGen),
              cache.lastHistoryId(accountID: accountID) == nil else { return }
        cache.setLastHistoryId(historyId, accountID: accountID)
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
