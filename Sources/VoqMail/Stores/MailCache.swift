//
//  MailCache.swift
//  VoqMail
//
//  The @MainActor boundary between the stores and the SwiftData store. A thin,
//  typed wrapper over one `ModelContext` (the container's `mainContext`) that
//  reads/writes the cache rows as the app's value types — so `MailStore` and
//  `LabelStore` never touch `@Model` instances or the context directly.
//
//  Confined to the main actor on purpose: `ModelContext` is not Sendable, and the
//  stores that own a `MailCache` are already `@MainActor`, so cache reads/writes
//  happen in the same hop as the stores' own whole-value writes. Caching is a
//  best-effort side channel — the network stays the source of truth — so failures
//  degrade to "no cache" rather than surfacing as errors.
//

import Foundation
import SwiftData

@MainActor
struct MailCache {
    let context: ModelContext

    // MARK: - Messages

    /// The cached list rows for one mailbox: the account's messages carrying the
    /// mailbox's Gmail label, newest first, capped at `limit`. Returns the value
    /// type the UI uses, tagged with the requested `mailboxID`.
    func messages(accountID: String, labelID: String, mailboxID: String, limit: Int) -> [MailMessage] {
        let rows = fetchMessages(accountID: accountID)
        return rows
            .filter { $0.labelIds.contains(labelID) }
            .sorted { $0.receivedAt > $1.receivedAt }
            .prefix(limit)
            .map { $0.toMailMessage(mailboxID: mailboxID) }
    }

    /// Inserts or updates each message by its composite cache key (write-through
    /// after a network load / page / sync). Grouped by account so the existing-row
    /// lookup uses the simple per-account fetch, never a multi-account predicate.
    func upsert(_ messages: [MailMessage]) {
        guard !messages.isEmpty else { return }
        for (accountID, group) in Dictionary(grouping: messages, by: \.accountID) {
            var existing = indexByCacheID(fetchMessages(accountID: accountID))
            for m in group {
                let key = CachedMessage.cacheID(accountID: accountID, gmailID: m.id)
                if let row = existing[key] {
                    row.threadId = m.threadId
                    row.labelIds = m.labelIds
                    row.sender = m.sender
                    row.senderAddress = m.senderAddress
                    row.recipients = m.recipients
                    row.subject = m.subject
                    row.preview = m.preview
                    row.receivedAt = m.receivedAt
                    row.rfcMessageID = m.rfcMessageID
                    row.rfcReferences = m.rfcReferences
                } else {
                    // Seed the new row back into the index so a duplicate id later in
                    // the same batch updates it rather than inserting a second row that
                    // would collide on the unique cacheID.
                    let row = CachedMessage(message: m)
                    context.insert(row)
                    existing[key] = row
                }
            }
        }
        save()
    }

    /// One cached message as a list row for the given mailbox, or `nil` if absent.
    /// Used when a history label change brings an already-cached message into the
    /// active mailbox and the in-memory list needs to materialize it.
    func message(accountID: String, gmailID: String, mailboxID: String) -> MailMessage? {
        let key = CachedMessage.cacheID(accountID: accountID, gmailID: gmailID)
        var descriptor = FetchDescriptor<CachedMessage>(predicate: #Predicate { $0.cacheID == key })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor).first)?.toMailMessage(mailboxID: mailboxID)
    }

    /// Whether a message is already cached for the account (so a history diff can
    /// skip hydrating it and just relabel the existing row).
    func hasMessage(accountID: String, gmailID: String) -> Bool {
        let key = CachedMessage.cacheID(accountID: accountID, gmailID: gmailID)
        var descriptor = FetchDescriptor<CachedMessage>(predicate: #Predicate { $0.cacheID == key })
        descriptor.fetchLimit = 1
        return ((try? context.fetch(descriptor))?.isEmpty == false)
    }

    /// The cached Gmail labels for one message, or `nil` when the message is not
    /// cached. Used to apply Gmail history label deltas when the history message
    /// omits its full label set.
    func labelIds(accountID: String, gmailID: String) -> [String]? {
        let key = CachedMessage.cacheID(accountID: accountID, gmailID: gmailID)
        var descriptor = FetchDescriptor<CachedMessage>(predicate: #Predicate { $0.cacheID == key })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor).first)?.labelIds
    }

    /// Replaces the stored label set of one message (a history label add/remove).
    /// A no-op if the message isn't cached.
    func setLabels(accountID: String, gmailID: String, labelIds: [String]) {
        let key = CachedMessage.cacheID(accountID: accountID, gmailID: gmailID)
        var descriptor = FetchDescriptor<CachedMessage>(predicate: #Predicate { $0.cacheID == key })
        descriptor.fetchLimit = 1
        guard let row = try? context.fetch(descriptor).first else { return }
        row.labelIds = labelIds
        save()
    }

    /// Deletes the given messages for an account (a history `messagesDeleted`).
    func deleteMessages(accountID: String, gmailIDs: Set<String>) {
        guard !gmailIDs.isEmpty else { return }
        let keys = Set(gmailIDs.map { CachedMessage.cacheID(accountID: accountID, gmailID: $0) })
        for row in fetchMessages(accountID: accountID) where keys.contains(row.cacheID) {
            context.delete(row)
        }
        save()
    }

    /// Drops every cached message for an account (account removal, issue #8).
    func deleteAllMessages(accountID: String) {
        for row in fetchMessages(accountID: accountID) { context.delete(row) }
        save()
    }

    // MARK: - Labels (sidebar mailboxes)

    /// The cached sidebar mailboxes for one account, in their stored display order.
    func mailboxes(accountID: String) -> [Mailbox] {
        let descriptor = FetchDescriptor<CachedLabel>(
            predicate: #Predicate { $0.accountID == accountID },
            sortBy: [SortDescriptor(\.order)])
        return ((try? context.fetch(descriptor)) ?? []).map { $0.toMailbox() }
    }

    /// Replaces an account's cached mailboxes wholesale (a label load returns the
    /// full set, so replace also drops labels deleted server-side).
    func replaceMailboxes(_ mailboxes: [Mailbox], accountID: String) {
        let descriptor = FetchDescriptor<CachedLabel>(predicate: #Predicate { $0.accountID == accountID })
        for row in (try? context.fetch(descriptor)) ?? [] { context.delete(row) }
        for (index, mailbox) in mailboxes.enumerated() {
            context.insert(CachedLabel(mailbox: mailbox, order: index))
        }
        save()
    }

    /// Drops every cached mailbox for an account (account removal, issue #8).
    func deleteAllLabels(accountID: String) {
        let descriptor = FetchDescriptor<CachedLabel>(predicate: #Predicate { $0.accountID == accountID })
        for row in (try? context.fetch(descriptor)) ?? [] { context.delete(row) }
        save()
    }

    // MARK: - Sync checkpoint

    /// The incremental-sync checkpoint for an account, or `nil` if never seeded.
    func lastHistoryId(accountID: String) -> String? {
        syncState(accountID: accountID)?.lastHistoryId
    }

    /// Sets (or clears) the checkpoint, creating the row on first use.
    func setLastHistoryId(_ historyId: String?, accountID: String) {
        if let state = syncState(accountID: accountID) {
            state.lastHistoryId = historyId
        } else {
            context.insert(SyncState(accountID: accountID, lastHistoryId: historyId))
        }
        save()
    }

    /// Drops an account's checkpoint (account removal, issue #8).
    func deleteSyncState(accountID: String) {
        guard let state = syncState(accountID: accountID) else { return }
        context.delete(state)
        save()
    }

    // MARK: - Internals

    private func syncState(accountID: String) -> SyncState? {
        var descriptor = FetchDescriptor<SyncState>(predicate: #Predicate { $0.accountID == accountID })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func fetchMessages(accountID: String) -> [CachedMessage] {
        let descriptor = FetchDescriptor<CachedMessage>(predicate: #Predicate { $0.accountID == accountID })
        return (try? context.fetch(descriptor)) ?? []
    }

    private func indexByCacheID(_ rows: [CachedMessage]) -> [String: CachedMessage] {
        Dictionary(rows.map { ($0.cacheID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func save() {
        guard context.hasChanges else { return }
        try? context.save()
    }
}
