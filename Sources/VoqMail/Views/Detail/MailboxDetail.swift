//
//  MailboxDetail.swift
//  VoqMail
//
//  The detail pane shown beside the original custom sidebar. It owns the message
//  selection and reply draft for the selected mailbox without changing sidebar
//  chrome or layout behavior.
//

import SwiftUI

struct MailboxDetail: View {
    let mailbox: Mailbox?
    @Environment(SidebarModel.self) private var sidebarModel
    @State private var selectedMessageID: MailMessage.ID?
    @State private var activeDraft: MailDraft?

    /// Slides the header content right of the traffic lights / toggle button when
    /// the sidebar is collapsed; tracks the toggle animation since it reads
    /// `isShown` inside the same transaction.
    private var headerLeadingPadding: CGFloat {
        sidebarModel.isShown
            ? Metrics.mailboxHeaderHorizontalPadding
            : Metrics.mailboxHeaderCollapsedLeadingPadding
    }

    private var messages: [MailMessage] {
        MailMessage.samples(in: mailbox?.id)
            .sorted { $0.receivedAt > $1.receivedAt }
    }

    private var selectedMessage: MailMessage? {
        messages.first { $0.id == selectedMessageID } ?? messages.first
    }

    var body: some View {
        Group {
            if mailbox == nil {
                ContentUnavailableView(
                    "Select a mailbox",
                    systemImage: "tray",
                    description: Text("Choose a mailbox from the sidebar.")
                )
            } else if let mailbox {
                VStack(spacing: 0) {
                    MailboxHeaderView(
                        mailbox: mailbox,
                        messageCount: messages.count,
                        leadingPadding: headerLeadingPadding
                    )

                    HStack(spacing: 0) {
                        MessageList(messages: messages, selection: $selectedMessageID)
                            .frame(width: 330)

                        Divider()

                        MessageDetail(message: selectedMessage) { message in
                            reply(to: message)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            selectedMessageID = selectedMessageID ?? messages.first?.id
        }
        .onChange(of: mailbox?.id) { _, _ in
            selectedMessageID = messages.first?.id
        }
        .sheet(item: $activeDraft) { draft in
            ComposerView(
                draft: draftBinding(for: draft.id),
                onCancel: { activeDraft = nil },
                onSend: { activeDraft = nil }
            )
        }
    }

    private func reply(to message: MailMessage) {
        activeDraft = MailDraft.reply(to: message)
    }

    private func draftBinding(for id: MailDraft.ID) -> Binding<MailDraft> {
        Binding {
            activeDraft ?? MailDraft(id: id, to: [], subject: "", body: "", replyingToMessageID: nil)
        } set: { draft in
            activeDraft = draft
        }
    }
}
