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
    @State private var contentStore = MessageContentStore()

    /// Slides the header content right of the traffic lights / toggle button when
    /// the sidebar is collapsed; tracks the toggle animation since it reads
    /// `isShown` inside the same transaction.
    private var headerLeadingPadding: CGFloat {
        sidebarModel.isShown
            ? Metrics.mailboxHeaderHorizontalPadding
            : Metrics.mailboxHeaderCollapsedLeadingPadding
    }

    private var messages: [MailMessage] {
        mailStore.messages
    }

    private var selectedMessage: MailMessage? {
        messages.first { $0.id == selectedMessageID } ?? messages.first
    }

    /// The selected message with fetched body/attachments merged in once loaded;
    /// until then the list metadata (snippet body) stands in.
    private var displayMessage: MailMessage? {
        guard let base = selectedMessage else { return nil }
        if contentStore.loadedMessageID == base.id, let content = contentStore.content {
            return base.with(htmlBody: content.html, attachments: content.attachments)
        }
        return base
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

                        MessageDetail(
                            message: displayMessage,
                            isLoadingContent: contentStore.isLoading,
                            downloadingAttachmentIDs: contentStore.downloadingAttachmentIDs,
                            onReply: { reply(to: $0) },
                            onToggleRead: { message in
                                Task { await toggleRead(message) }
                            },
                            onPreviewAttachment: { attachment in
                                Task { await downloadAttachment(attachment) }
                            })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: loadKey) { await loadMessagesIfNeeded() }
        // Cancellable per-selection: switching messages cancels the prior load so
        // a late response can't overwrite the newly selected message's content.
        .task(id: selectedMessage?.id) { await loadSelectedContent() }
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
        MessageList(
            messages: messages,
            selection: $selectedMessageID,
            canLoadMore: mailStore.canLoadMore,
            isLoadingMore: mailStore.isLoadingMore,
            onLoadMore: { Task { await loadMore() } })
            .overlay {
                if mailStore.isLoading && messages.isEmpty {
                    ProgressView()
                }
            }
            .overlay(alignment: .top) {
                if let error = mailStore.errorMessage, messages.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
    }

    private func loadMessagesIfNeeded() async {
        guard let mailbox, let account = accountStore.accounts.first else { return }
        await mailStore.load(mailbox: mailbox) {
            try await accountStore.accessToken(for: account.email)
        }
    }

    private func loadMore() async {
        guard let account = accountStore.accounts.first else { return }
        await mailStore.loadMore {
            try await accountStore.accessToken(for: account.email)
        }
    }

    private func loadSelectedContent() async {
        guard let message = selectedMessage,
              let account = accountStore.accounts.first else { return }
        // Opening a message marks it read; the user can flip it back from the header.
        if !message.isRead {
            await mailStore.setRead(true, messageID: message.id) {
                try await accountStore.accessToken(for: account.email)
            }
        }
        await contentStore.load(message: message) {
            try await accountStore.accessToken(for: account.email)
        }
    }

    private func toggleRead(_ message: MailMessage) async {
        guard let account = accountStore.accounts.first else { return }
        await mailStore.toggleRead(messageID: message.id) {
            try await accountStore.accessToken(for: account.email)
        }
    }

    private func downloadAttachment(_ attachment: MailAttachment) async {
        guard let account = accountStore.accounts.first else { return }
        await contentStore.downloadAttachment(attachment) {
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
