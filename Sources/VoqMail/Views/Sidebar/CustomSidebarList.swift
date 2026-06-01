//
//  CustomSidebarList.swift
//  VoqMail
//
//  The scrollable list of mailboxes in the sidebar, sourced from the account's
//  Gmail labels (issue #6). System mailboxes show in a fixed order; user labels
//  show as a `/`-nested disclosure hierarchy. Built from a ScrollView + plain
//  buttons (rather than a native List) so the rows and the custom split-view
//  background can be styled freely.
//

import SwiftUI

struct CustomSidebarList: View {
    @Binding var selection: Mailbox.ID?
    @Environment(LabelStore.self) private var labelStore
    /// Collapsed user-label ids. Absence means expanded, so labels start open.
    @State private var collapsed: Set<Mailbox.ID> = []

    private var systemMailboxes: [Mailbox] {
        labelStore.mailboxes.filter(\.isSystem)
    }

    private var rootUserMailboxes: [Mailbox] {
        labelStore.mailboxes.filter { !$0.isSystem && $0.parentID == nil }
    }

    private func children(of id: Mailbox.ID) -> [Mailbox] {
        labelStore.mailboxes.filter { $0.parentID == id }
    }

    var body: some View {
        // Mailbox list scrolls; the account footer stays pinned to the bottom.
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    sectionHeader("Mailboxes")
                        // Extra top padding clears the window's traffic-light buttons.
                        .padding(.top, Metrics.sidebarHeaderTopPadding)

                    ForEach(systemMailboxes) { mailbox in
                        row(for: mailbox)
                    }

                    if !rootUserMailboxes.isEmpty {
                        sectionHeader("Labels")
                            .padding(.top, 12)

                        ForEach(rootUserMailboxes) { mailbox in
                            SidebarLabelNode(
                                mailbox: mailbox,
                                depth: 0,
                                selection: $selection,
                                collapsed: $collapsed,
                                children: children)
                        }
                    }

                    if labelStore.isLoading && labelStore.mailboxes.isEmpty {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 18)
                            .padding(.top, 6)
                    }

                    if let error = labelStore.errorMessage, labelStore.mailboxes.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(3)
                            .padding(.horizontal, 18)
                            .padding(.top, 6)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
            }
            .scrollContentBackground(.hidden)

            AccountStatusView()
        }
        .ignoresSafeArea(.container, edges: .top)
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
