//
//  CacheModels.swift
//  VoqMail
//
//  The SwiftData persistence layer (issue #12). Three @Model classes mirror the
//  app's value types so messages, labels, and the per-account history checkpoint
//  survive a relaunch and can paint instantly before the network responds.
//
//  Deliberately kept as a *separate* persistence mirror rather than annotating
//  `MailMessage`/`Mailbox` themselves: those are value-semantic structs the whole
//  UI, the reply builder, and the sample data depend on, so turning them into
//  reference-type @Model classes would ripple everywhere. The adapters below
//  convert between the stored rows and the in-memory structs at the cache
//  boundary, leaving the rest of the app untouched.
//
//  Threading: @Model instances and their ModelContext are not Sendable, so they
//  are only ever touched from the @MainActor stores (see MailCache). The network
//  layer returns plain value types; nothing crosses the TokenProvider actor.
//

import Foundation
import SwiftData

/// One cached message row, keyed globally by `cacheID` = `"\(accountID)|\(gmailID)"`
/// because Gmail message ids are not unique across accounts (issue #8). A message
/// is stored once per account; which mailboxes show it is derived from `labelIds`
/// (a mailbox lists the account rows whose `labelIds` contains its Gmail label),
/// so no per-mailbox duplication is needed. Body/attachments are intentionally not
/// cached — they are fetched on demand by `MessageContentStore` when a message is
/// opened, mirroring what `MailStore` holds for a list row.
@Model
final class CachedMessage {
    @Attribute(.unique) var cacheID: String
    var accountID: String
    var gmailID: String
    var threadId: String
    var labelIds: [String]
    var sender: String
    var senderAddress: String
    var recipients: [String]
    var subject: String
    var preview: String
    var receivedAt: Date
    var rfcMessageID: String?
    var rfcReferences: String?

    init(
        accountID: String, gmailID: String, threadId: String, labelIds: [String],
        sender: String, senderAddress: String, recipients: [String], subject: String,
        preview: String, receivedAt: Date, rfcMessageID: String?, rfcReferences: String?
    ) {
        self.cacheID = "\(accountID)|\(gmailID)"
        self.accountID = accountID
        self.gmailID = gmailID
        self.threadId = threadId
        self.labelIds = labelIds
        self.sender = sender
        self.senderAddress = senderAddress
        self.recipients = recipients
        self.subject = subject
        self.preview = preview
        self.receivedAt = receivedAt
        self.rfcMessageID = rfcMessageID
        self.rfcReferences = rfcReferences
    }

    /// The composite cache key for an (account, message id) pair.
    static func cacheID(accountID: String, gmailID: String) -> String {
        "\(accountID)|\(gmailID)"
    }
}

extension CachedMessage {
    convenience init(message m: MailMessage) {
        self.init(
            accountID: m.accountID, gmailID: m.id, threadId: m.threadId, labelIds: m.labelIds,
            sender: m.sender, senderAddress: m.senderAddress, recipients: m.recipients,
            subject: m.subject, preview: m.preview, receivedAt: m.receivedAt,
            rfcMessageID: m.rfcMessageID, rfcReferences: m.rfcReferences)
    }

    /// Rebuilds the in-memory list row. `mailboxID` is supplied by the caller for
    /// the mailbox being read (it is composite `"\(accountID)|\(labelID)"`), since a
    /// stored message is not bound to a single mailbox. The body defaults to a
    /// plain-text rendering of the preview, exactly as a freshly-listed row does.
    func toMailMessage(mailboxID: String) -> MailMessage {
        MailMessage(
            id: gmailID, sender: sender, senderAddress: senderAddress, recipients: recipients,
            subject: subject, preview: preview, htmlBody: nil, receivedAt: receivedAt,
            labelIds: labelIds, attachments: [], threadId: threadId,
            rfcMessageID: rfcMessageID, rfcReferences: rfcReferences,
            mailboxID: mailboxID, accountID: accountID)
    }
}

/// One cached sidebar mailbox row, a direct mirror of `Mailbox`. `cacheID` is the
/// mailbox's own composite id (`"\(accountID)|\(gmailLabelID)"`), already globally
/// unique. Stored verbatim so the sidebar rebuilds without re-deriving hierarchy.
@Model
final class CachedLabel {
    @Attribute(.unique) var cacheID: String
    var accountID: String
    var title: String
    var systemImage: String
    var gmailLabelID: String
    var isSystem: Bool
    var parentID: String?
    var unreadCount: Int?
    /// Position in the sidebar's flat, display-ordered list (system labels in their
    /// fixed order, then user labels by path). Persisted so a cache-first rebuild
    /// keeps the order a plain fetch would otherwise lose.
    var order: Int

    init(
        cacheID: String, accountID: String, title: String, systemImage: String,
        gmailLabelID: String, isSystem: Bool, parentID: String?, unreadCount: Int?,
        order: Int
    ) {
        self.cacheID = cacheID
        self.accountID = accountID
        self.title = title
        self.systemImage = systemImage
        self.gmailLabelID = gmailLabelID
        self.isSystem = isSystem
        self.parentID = parentID
        self.unreadCount = unreadCount
        self.order = order
    }
}

extension CachedLabel {
    convenience init(mailbox m: Mailbox, order: Int) {
        self.init(
            cacheID: m.id, accountID: m.accountID, title: m.title, systemImage: m.systemImage,
            gmailLabelID: m.gmailLabelID, isSystem: m.isSystem, parentID: m.parentID,
            unreadCount: m.unreadCount, order: order)
    }

    func toMailbox() -> Mailbox {
        Mailbox(
            id: cacheID, accountID: accountID, title: title, systemImage: systemImage,
            gmailLabelID: gmailLabelID, isSystem: isSystem, parentID: parentID,
            unreadCount: unreadCount)
    }
}

/// The incremental-sync checkpoint for one account (issue #13): the `historyId`
/// to resume `users.history.list` from. One row per account, keyed by `accountID`.
@Model
final class SyncState {
    @Attribute(.unique) var accountID: String
    /// The last `historyId` the cache is known to reflect. `nil` until the first
    /// full load seeds it; cleared on a 404 to force a full re-sync.
    var lastHistoryId: String?

    init(accountID: String, lastHistoryId: String? = nil) {
        self.accountID = accountID
        self.lastHistoryId = lastHistoryId
    }
}
