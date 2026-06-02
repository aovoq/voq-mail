//
//  CustomSidebarList.swift
//  VoqMail
//
//  The scrollable list of mailboxes in the sidebar, grouped by account (issue #8):
//  one section per signed-in account, each headed by its address and listing that
//  account's Gmail labels (issue #6) — system mailboxes in a fixed order, then
//  user labels as a `/`-nested disclosure hierarchy. Selecting a label makes its
//  account active. Built from a ScrollView + plain buttons (rather than a native
//  List) so the rows and the custom split-view background can be styled freely.
//

import SwiftUI

struct CustomSidebarList: View {
    @Binding var selection: Mailbox.ID?
    @Environment(AccountStore.self) private var accountStore
    @Environment(LabelStore.self) private var labelStore
    /// Collapsed user-label ids. Absence means expanded, so labels start open.
    /// Shared across accounts; `Mailbox.id` is composite so ids never collide.
    @State private var collapsed: Set<Mailbox.ID> = []
    /// Collapsed account ids. Absence means expanded, so accounts start open.
    @State private var collapsedAccounts: Set<Account.ID> = []

    var body: some View {
        // Mailbox list scrolls; the account footer stays pinned to the bottom.
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    // Clears the window's traffic-light buttons above the first row.
                    Color.clear.frame(height: Metrics.sidebarHeaderTopPadding)

                    ForEach(accountStore.accounts) { account in
                        accountSection(account)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
            }
            .scrollContentBackground(.hidden)
            // Pinned band that occludes rows scrolling up under the window's
            // traffic-light buttons. Same material as the sidebar background so
            // the band is seamless; the matching `Color.clear` spacer atop the
            // list keeps the first row clear of it at rest. Non-hit-testing so
            // clicks still reach the traffic-light buttons.
            .overlay(alignment: .top) {
                VisualEffectBackground(style: .calibratedSidebar)
                    .frame(height: Metrics.sidebarHeaderTopPadding)
                    .allowsHitTesting(false)
            }

            AccountStatusView()
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    /// One account's group: an address header, its system mailboxes, then its
    /// user-label hierarchy. Reads the slice for this account so each group is
    /// independent.
    @ViewBuilder
    private func accountSection(_ account: Account) -> some View {
        let mailboxes = labelStore.mailboxes(for: account.id)
        let systemMailboxes = mailboxes.filter(\.isSystem)
        let rootUserMailboxes = mailboxes.filter { !$0.isSystem && $0.parentID == nil }
        let isExpanded = !collapsedAccounts.contains(account.id)

        accountHeader(account.email, isExpanded: isExpanded) {
            toggleAccount(account.id)
        }

        if isExpanded {
            ForEach(systemMailboxes) { mailbox in
                row(for: mailbox)
            }

            if !rootUserMailboxes.isEmpty {
                sectionHeader("Labels")
                    .padding(.top, 8)

                ForEach(rootUserMailboxes) { mailbox in
                    SidebarLabelNode(
                        mailbox: mailbox,
                        depth: 0,
                        selection: $selection,
                        collapsed: $collapsed,
                        children: { id in mailboxes.filter { $0.parentID == id } })
                }
            }

            if labelStore.isLoading(for: account.id) && mailboxes.isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
            }

            if let error = labelStore.error(for: account.id), mailboxes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(3)

                    Button("Retry") { retry(account) }
                        .font(.caption.weight(.medium))
                        .buttonStyle(.link)
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
            }
        }
    }

    private func toggleAccount(_ id: Account.ID) {
        let isCollapsing = !collapsedAccounts.contains(id)
        withAnimation(isCollapsing ? Motion.sidebarCollapse : Motion.sidebarExpand) {
            if isCollapsing {
                collapsedAccounts.insert(id)
            } else {
                collapsedAccounts.remove(id)
            }
        }
    }

    /// Reloads one account's labels after a failure. `load` clears the error and
    /// re-runs its own backoff, so this just kicks it off again.
    private func retry(_ account: Account) {
        let id = account.id
        labelStore.load(accountID: id) {
            try await accountStore.accessToken(for: id)
        }
    }

    /// The per-account group header showing the account's address. Tapping it
    /// collapses or expands that account's mailboxes; the chevron mirrors the state.
    private func accountHeader(_ email: String, isExpanded: Bool, onToggle: @escaping () -> Void) -> some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))

                Text(email)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
    }

    /// A flat (no-disclosure) row used for system mailboxes.
    private func row(for mailbox: Mailbox) -> some View {
        Button {
            selection = mailbox.id
        } label: {
            CustomSidebarRow(mailbox: mailbox, isSelected: selection == mailbox.id)
        }
        .buttonStyle(.plain)
    }
}

/// A user-label row plus, when expanded, its child rows. Recurses to render the
/// `/`-nested hierarchy; the chevron toggles `collapsed` without selecting.
private struct SidebarLabelNode: View {
    let mailbox: Mailbox
    let depth: Int
    @Binding var selection: Mailbox.ID?
    @Binding var collapsed: Set<Mailbox.ID>
    let children: (Mailbox.ID) -> [Mailbox]

    var body: some View {
        let kids = children(mailbox.id)
        let isExpanded = !collapsed.contains(mailbox.id)

        Button {
            selection = mailbox.id
        } label: {
            CustomSidebarRow(
                mailbox: mailbox,
                isSelected: selection == mailbox.id,
                depth: depth,
                disclosure: kids.isEmpty ? .none : (isExpanded ? .expanded : .collapsed),
                onToggle: kids.isEmpty ? nil : { toggle() })
        }
        .buttonStyle(.plain)

        if isExpanded {
            ForEach(kids) { child in
                SidebarLabelNode(
                    mailbox: child,
                    depth: depth + 1,
                    selection: $selection,
                    collapsed: $collapsed,
                    children: children)
            }
        }
    }

    private func toggle() {
        if collapsed.contains(mailbox.id) {
            collapsed.remove(mailbox.id)
        } else {
            collapsed.insert(mailbox.id)
        }
    }
}
