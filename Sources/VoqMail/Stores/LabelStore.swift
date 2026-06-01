//
//  LabelStore.swift
//  VoqMail
//
//  Observable sidebar state: the Gmail labels mapped to `Mailbox` rows the
//  sidebar shows. Labels arrive from `users.labels.list` (ids/names only), so the
//  unread badges need a follow-up `labels.get` per displayed label; both run
//  through GmailClient. Single account for now (issue #8 broadens this).
//

import Foundation
import Observation

@Observable
@MainActor
final class LabelStore {
    /// The mailboxes shown in the sidebar, flat with `parentID` wiring the
    /// hierarchy. System mailboxes come first in a fixed order, then user labels
    /// sorted by full path so a parent precedes its children.
    private(set) var mailboxes: [Mailbox] = []
    private(set) var isLoading = false
    var errorMessage: String?

    private let client = GmailClient()

    /// Loads the account's labels and their unread counts. `token` supplies a valid
    /// access token (it may refresh), so token failures surface here too.
    func loadLabels(token: @escaping @Sendable () async throws -> String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let accessToken = try await token()
            let all = try await client.labels(accessToken: accessToken)
            let displayed = Self.displayedLabels(from: all)
            // The list endpoint omits counts, so fetch them only for what we show.
            let detailed = try await client.labels(
                ids: displayed.map(\.id), concurrency: 5, accessToken: accessToken)
            let unreadByID = Dictionary(
                detailed.map { ($0.id, $0.messagesUnread ?? 0) },
                uniquingKeysWith: { first, _ in first })
            mailboxes = Self.mailboxes(from: displayed, unreadByID: unreadByID)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    // MARK: - Mapping

    /// The system labels we surface, in display order, with a friendly title and
    /// icon. Gmail exposes many system labels that aren't browsable folders
    /// (UNREAD, CHAT, …); listing an allowlist keeps the sidebar to real folders.
    private static let systemLabels: [(id: String, title: String, icon: String)] = [
        ("INBOX", "Inbox", "tray.fill"),
        ("STARRED", "Starred", "star.fill"),
        ("IMPORTANT", "Important", "tag.fill"),
        ("SENT", "Sent", "paperplane.fill"),
        ("DRAFT", "Drafts", "doc.fill"),
        ("SPAM", "Spam", "xmark.bin.fill"),
        ("TRASH", "Trash", "trash.fill"),
        ("CATEGORY_PERSONAL", "Personal", "person.crop.circle"),
        ("CATEGORY_SOCIAL", "Social", "person.2.fill"),
        ("CATEGORY_PROMOTIONS", "Promotions", "megaphone.fill"),
        ("CATEGORY_UPDATES", "Updates", "bell.fill"),
        ("CATEGORY_FORUMS", "Forums", "bubble.left.and.bubble.right.fill"),
    ]

    /// The subset of `all` we render, in display order: allowed system labels (in
    /// `systemLabels` order) followed by every user label sorted by path.
    private static func displayedLabels(from all: [GmailLabel]) -> [GmailLabel] {
        let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let system = systemLabels.compactMap { byID[$0.id] }
        let user = all
            .filter { $0.type == "user" }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return system + user
    }

    /// Builds the sidebar mailboxes from the displayed labels, attaching unread
    /// counts and wiring user-label parentage from the `/`-separated names.
    private static func mailboxes(
        from labels: [GmailLabel], unreadByID: [String: Int]
    ) -> [Mailbox] {
        func badge(_ id: String) -> Int? {
            let unread = unreadByID[id] ?? 0
            return unread == 0 ? nil : unread
        }

        let userLabels = labels.filter { $0.type == "user" }
        let idByName = Dictionary(
            userLabels.map { ($0.name, $0.id) }, uniquingKeysWith: { first, _ in first })
        // A label is a parent if any other user label's path nests under it.
        let parentNames = Set(userLabels.compactMap { label -> String? in
            let comps = label.name.split(separator: "/")
            guard comps.count > 1 else { return nil }
            return comps.dropLast().joined(separator: "/")
        })

        let titleByID = Dictionary(
            systemLabels.map { ($0.id, ($0.title, $0.icon)) }, uniquingKeysWith: { first, _ in first })

        return labels.map { label in
            if let system = titleByID[label.id] {
                return Mailbox(
                    id: label.id, title: system.0, systemImage: system.1,
                    gmailLabelID: label.id, isSystem: true, parentID: nil,
                    unreadCount: badge(label.id))
            }

            let comps = label.name.split(separator: "/").map(String.init)
            let parentPath = comps.dropLast().joined(separator: "/")
            let hasChildren = parentNames.contains(label.name)
            return Mailbox(
                id: label.id,
                title: comps.last ?? label.name,
                systemImage: hasChildren ? "folder.fill" : "tag.fill",
                gmailLabelID: label.id,
                isSystem: false,
                parentID: parentPath.isEmpty ? nil : idByName[parentPath],
                unreadCount: badge(label.id))
        }
    }
}
