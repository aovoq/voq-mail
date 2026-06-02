//
//  Mailbox.swift
//  VoqMail
//
//  A mail folder shown in the sidebar (Inbox, Sent, …). A plain value type with
//  no behavior; its demo data lives in SampleData.swift.
//

import Foundation

/// A mail folder shown in the sidebar. Backed by a Gmail label (issue #6); the
/// demo data in SampleData.swift fills the same fields for previews/reference.
struct Mailbox: Identifiable, Hashable {
    /// Stable identifier used to track the sidebar selection. For real mailboxes
    /// it is the composite `"\(accountID)|\(gmailLabelID)"` so the same Gmail
    /// label id (e.g. "INBOX") in two accounts does not collide in the selection,
    /// the collapsed set, or any flat collection. (SampleData uses simpler ids.)
    let id: String
    /// The account (email) this mailbox belongs to. Threads multi-account state
    /// through the stores and decides which token fetches its messages.
    let accountID: String
    /// Display name, e.g. "Inbox". For nested user labels this is the trailing
    /// path segment ("Sub" for "Work/Sub"), not the full path.
    let title: String
    /// SF Symbol name for the row's icon.
    let systemImage: String
    /// The Gmail label id this mailbox maps to (e.g. "INBOX", "Label_42"). Used to
    /// list the label's messages and fetch its unread count. Stays the bare label
    /// id (the API and the default-Inbox match rely on it), distinct from `id`.
    let gmailLabelID: String
    /// True for Gmail's built-in labels (INBOX/SENT/…), false for user labels.
    let isSystem: Bool
    /// The parent mailbox's id for a nested user label ("Work" for "Work/Sub"), or
    /// `nil` for a top-level mailbox. Drives the sidebar's disclosure hierarchy.
    let parentID: Mailbox.ID?
    /// Unread message count; `nil` hides the badge (also used when the count is 0).
    let unreadCount: Int?
}

extension Mailbox {
    /// Finds the sample mailbox with the given id, or `nil` if `id` is `nil`/unknown.
    ///
    /// Centralizes the `samples.first { $0.id == … }` lookup that the layout and
    /// the reference demos would otherwise each re-implement.
    static func sample(for id: Mailbox.ID?) -> Mailbox? {
        samples.first { $0.id == id }
    }
}
