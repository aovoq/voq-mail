//
//  CustomSidebarList.swift
//  VoqMail
//
//  The scrollable list of mailboxes in the sidebar. Tapping a row updates the
//  bound selection. Built from a ScrollView + plain buttons (rather than a native
//  List) so the rows and the custom split-view background can be styled freely.
//

import SwiftUI

struct CustomSidebarList: View {
    @Binding var selection: Mailbox.ID?
    @Environment(MailStore.self) private var mailStore

    var body: some View {
        // Mailbox list scrolls; the account footer stays pinned to the bottom.
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mailboxes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        // Extra top padding clears the window's traffic-light buttons.
                        .padding(.top, Metrics.sidebarHeaderTopPadding)
                        .padding(.bottom, 6)

                    ForEach(Mailbox.samples) { mailbox in
                        Button {
                            selection = mailbox.id
                        } label: {
                            CustomSidebarRow(
                                mailbox: displayMailbox(mailbox),
                                isSelected: selection == mailbox.id)
                        }
                        .buttonStyle(.plain)
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

    /// Replaces the INBOX row's static sample badge with the live unread count.
    private func displayMailbox(_ mailbox: Mailbox) -> Mailbox {
        guard mailbox.id == "inbox" else { return mailbox }
        let unread = mailStore.inboxUnreadCount
        return Mailbox(
            id: mailbox.id,
            title: mailbox.title,
            systemImage: mailbox.systemImage,
            count: unread == 0 ? nil : unread)
    }
}
