//
//  LabelStore.swift
//  VoqMail
//
//  Observable sidebar state: the Gmail labels mapped to `Mailbox` rows the
//  sidebar shows. Labels arrive from `users.labels.list` (ids/names only), so the
//  unread badges need a follow-up `labels.get` per displayed label; both run
//  through GmailClient. State is partitioned by account id (issue #8) so the
//  sidebar can group every signed-in account's labels at once.
//

import Foundation
import Observation

@Observable
@MainActor
final class LabelStore {
    /// The mailboxes for each account, keyed by account id. Each list is flat with
    /// `parentID` wiring the hierarchy: system mailboxes first in a fixed order,
    /// then user labels sorted by full path so a parent precedes its children.
    private var mailboxesByAccount: [String: [Mailbox]] = [:]
    /// Accounts with a load in flight, so two accounts can load concurrently on
    /// launch without one's guard dropping the other.
    private var loadingAccountIDs: Set<String> = []
    private var errorsByAccount: [String: String] = [:]
    /// Per-account load generation, bumped by `purge`. A load captures it at start
    /// and writes its result only if it still matches, so a load suspended at an
    /// await when the account is removed cannot resurrect the deleted labels.
    private var loadGenerationByAccount: [String: Int] = [:]

    private let client = GmailClient()

    /// The mailboxes to show for one account (empty until its labels load).
    func mailboxes(for accountID: String) -> [Mailbox] {
        mailboxesByAccount[accountID] ?? []
    }

    /// Whether the given account's labels are currently loading.
    func isLoading(for accountID: String) -> Bool {
        loadingAccountIDs.contains(accountID)
    }

    /// The last load error for the given account, or nil.
    func error(for accountID: String) -> String? {
        errorsByAccount[accountID]
    }

    /// Drops an account's labels (used when the account is removed). Bumping the
    /// generation makes any in-flight load for this account no-op on completion.
    func purge(accountID: String) {
        mailboxesByAccount[accountID] = nil
        loadingAccountIDs.remove(accountID)
        errorsByAccount[accountID] = nil
        loadGenerationByAccount[accountID, default: 0] &+= 1
    }

    /// Loads one account's labels and their unread counts. `token` supplies a
    /// valid access token (it may refresh), so token failures surface here too.
    /// Guarded per account so a concurrent reload of the same account is a no-op
    /// while different accounts still load in parallel.
    func loadLabels(accountID: String, token: @escaping @Sendable () async throws -> String) async {
        guard !loadingAccountIDs.contains(accountID) else { return }
        loadingAccountIDs.insert(accountID)
        errorsByAccount[accountID] = nil
        let generation = loadGenerationByAccount[accountID] ?? 0
        defer { loadingAccountIDs.remove(accountID) }

        do {
            let accessToken = try await token()
            let all = try await client.labels(accessToken: accessToken)
            let displayed = Self.displayedLabels(from: all)
            // The list endpoint omits counts, so fetch them only for what we show.
            let detailed = try await client.labels(
                ids: displayed.map(\.id), concurrency: 5, accessToken: accessToken)
            // Use the thread (conversation) count so the badge matches Gmail's own
            // UI, which counts unread conversations rather than unread messages.
            let unreadByID = Dictionary(
                detailed.map { ($0.id, $0.threadsUnread ?? 0) },
                uniquingKeysWith: { first, _ in first })
            // The account may have been removed (and re-added) while we awaited;
            // only write back if this load hasn't been superseded.
            guard (loadGenerationByAccount[accountID] ?? 0) == generation else { return }
            mailboxesByAccount[accountID] = Self.mailboxes(
                from: displayed, unreadByID: unreadByID, accountID: accountID)
        } catch {
            guard (loadGenerationByAccount[accountID] ?? 0) == generation else { return }
            errorsByAccount[accountID] = String(describing: error)
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
    /// counts and wiring user-label parentage from the `/`-separated names. Every
    /// `Mailbox.id` (and `parentID`) is the composite `"\(accountID)|\(labelID)"`
    /// so the same Gmail label id across two accounts stays globally unique.
    private static func mailboxes(
        from labels: [GmailLabel], unreadByID: [String: Int], accountID: String
    ) -> [Mailbox] {
        func badge(_ id: String) -> Int? {
            let unread = unreadByID[id] ?? 0
            return unread == 0 ? nil : unread
        }
        func mailboxID(_ labelID: String) -> String { "\(accountID)|\(labelID)" }

        let userLabels = labels.filter { $0.type == "user" }
        // name -> composite mailbox id, so a child's parentID resolves within this
        // account's id space.
        let idByName = Dictionary(
            userLabels.map { ($0.name, mailboxID($0.id)) }, uniquingKeysWith: { first, _ in first })
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
                    id: mailboxID(label.id), accountID: accountID, title: system.0,
                    systemImage: system.1, gmailLabelID: label.id, isSystem: true,
                    parentID: nil, unreadCount: badge(label.id))
            }

            let comps = label.name.split(separator: "/").map(String.init)
            let parentPath = comps.dropLast().joined(separator: "/")
            let hasChildren = parentNames.contains(label.name)
            return Mailbox(
                id: mailboxID(label.id),
                accountID: accountID,
                title: comps.last ?? label.name,
                systemImage: hasChildren ? "folder.fill" : "tag.fill",
                gmailLabelID: label.id,
                isSystem: false,
                parentID: parentPath.isEmpty ? nil : idByName[parentPath],
                unreadCount: badge(label.id))
        }
    }
}
