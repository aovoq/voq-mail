//
//  Mailbox.swift
//  VoqMail
//
//  A mail folder shown in the sidebar (Inbox, Sent, …). A plain value type with
//  no behavior; its demo data lives in SampleData.swift.
//

import Foundation

/// A mail folder shown in the sidebar.
struct Mailbox: Identifiable, Hashable {
    /// Stable identifier used to track the sidebar selection.
    let id: String
    /// Display name, e.g. "Inbox".
    let title: String
    /// SF Symbol name for the row's icon.
    let systemImage: String
    /// Unread badge count; `nil` hides the badge.
    let count: Int?
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
