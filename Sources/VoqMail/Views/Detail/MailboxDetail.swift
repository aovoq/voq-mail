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
    @Environment(MailStore.self) private var mailStore
    @Environment(AccountStore.self) private var accountStore
    @State private var selectedMessageID: MailMessage.ID?
    @State private var activeDraft: MailDraft?

    /// Only INBOX is backed by real data in this slice; other mailboxes get real
    /// messages once labels land (issue #6).
    private var isInbox: Bool { mailbox?.id == "inbox" }

    /// Slides the header content right of the traffic lights / toggle button when
    /// the sidebar is collapsed; tracks the toggle animation since it reads
    /// `isShown` inside the same transaction.
    private var headerLeadingPadding: CGFloat {
        sidebarModel.isShown
            ? Metrics.mailboxHeaderHorizontalPadding
            : Metrics.mailboxHeaderCollapsedLeadingPadding
    }

    private var messages: [MailMessage] {
        isInbox ? mailStore.messages : []
    }

    private var selectedMessage: MailMessage? {
        messages.first { $0.id == selectedMessageID } ?? messages.first
    }

    /// Re-fires the load when the selected mailbox or the signed-in account changes.
    private var loadKey: String {
        "\(mailbox?.id ?? "")|\(accountStore.accounts.first?.id ?? "")"
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
                        messageListColumn
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
        .task(id: loadKey) { await loadInboxIfNeeded() }
        .onChange(of: mailbox?.id) { _, _ in
            selectedMessageID = messages.first?.id
        }
        // Select the first message once an async load populates the list.
        .onChange(of: messages) { _, newMessages in
            if selectedMessageID == nil || !newMessages.contains(where: { $0.id == selectedMessageID }) {
                selectedMessageID = newMessages.first?.id
            }
        }
        .sheet(item: $activeDraft) { draft in
            ComposerView(
                draft: draftBinding(for: draft.id),
                onCancel: { activeDraft = nil },
                onSend: { activeDraft = nil }
            )
        }
    }

    /// The message list with INBOX loading/error feedback layered on top.
    private var messageListColumn: some View {
        MessageList(messages: messages, selection: $selectedMessageID)
            .overlay {
                if isInbox && mailStore.isLoading && messages.isEmpty {
                    ProgressView()
                }
            }
            .overlay(alignment: .top) {
                if isInbox, let error = mailStore.errorMessage, messages.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
    }

    private func loadInboxIfNeeded() async {
        guard isInbox, let account = accountStore.accounts.first else { return }
        await mailStore.loadInbox {
            try await accountStore.accessToken(for: account.email)
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
