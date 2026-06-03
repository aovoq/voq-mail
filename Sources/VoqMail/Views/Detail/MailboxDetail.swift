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
    @Environment(MessageContentStore.self) private var contentStore
    @Environment(SendStore.self) private var sendStore
    @Environment(ReplyAssistStore.self) private var assistStore  // reply-assist:
    @State private var selectedMessageID: MailMessage.ID?
    @State private var activeDraft: MailDraft?

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
        if contentStore.isShowing(accountID: base.accountID, messageID: base.id),
           let content = contentStore.content {
            return base.with(htmlBody: content.html, attachments: content.attachments)
        }
        return base
    }

    /// Re-fires the load when the selected mailbox changes. `Mailbox.id` is already
    /// composite (`accountID|labelID`), so it also changes when the account does.
    private var loadKey: Mailbox.ID? {
        mailbox?.id
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
                        leadingPadding: sidebarModel.collapsedClearingLeadingPadding,
                        onCompose: { compose(from: mailbox.accountID) }
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
            composerSheet(for: draft)
        }
    }

    /// The composer sheet for the active draft. Extracted from `body` to keep that
    /// expression light for the type-checker.
    @ViewBuilder
    private func composerSheet(for draft: MailDraft) -> some View {
        // Read the account off the live `activeDraft`, not the presentation-time
        // `draft` snapshot, so the From picker can re-key the send state.
        let accountID = activeDraft?.accountID ?? draft.accountID
        ComposerView(
            draft: draftBinding(for: draft.id),
            accounts: accountStore.accounts,
            assist: assistStore,  // reply-assist:
            onCancel: {
                sendStore.reset(accountID: accountID)
                activeDraft = nil
            },
            // Capture the draft as it stands when Send is tapped; the binding's
            // latest edits are already on `activeDraft`.
            onSend: { Task { await send(activeDraft ?? draft) } },
            // Send state is keyed by the draft's account in SendStore, so a late
            // completion after an account switch can't surface here (issue #8).
            isSending: sendStore.isSending(accountID: accountID),
            errorMessage: sendStore.errorMessage(accountID: accountID)
        )
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
        guard let mailbox else { return }
        let accountID = mailbox.accountID
        await mailStore.load(mailbox: mailbox) {
            try await accountStore.accessToken(for: accountID)
        }
    }

    private func loadMore() async {
        guard let mailbox else { return }
        let accountID = mailbox.accountID
        await mailStore.loadMore(accountID: accountID) {
            try await accountStore.accessToken(for: accountID)
        }
    }

    private func loadSelectedContent() async {
        guard let message = selectedMessage else { return }
        let accountID = message.accountID
        // Opening a message marks it read; the user can flip it back from the header.
        if !message.isRead {
            await mailStore.setRead(true, messageID: message.id, accountID: accountID) {
                try await accountStore.accessToken(for: accountID)
            }
        }
        await contentStore.load(message: message, accountID: accountID) {
            try await accountStore.accessToken(for: accountID)
        }
    }

    private func toggleRead(_ message: MailMessage) async {
        let accountID = message.accountID
        await mailStore.toggleRead(messageID: message.id, accountID: accountID) {
            try await accountStore.accessToken(for: accountID)
        }
    }

    private func downloadAttachment(_ attachment: MailAttachment) async {
        guard let accountID = selectedMessage?.accountID else { return }
        await contentStore.downloadAttachment(attachment, accountID: accountID) {
            try await accountStore.accessToken(for: accountID)
        }
    }

    private func reply(to message: MailMessage) {
        sendStore.reset(accountID: message.accountID)
        activeDraft = MailDraft.reply(to: message)
    }

    private func compose(from accountID: String) {
        sendStore.reset(accountID: accountID)
        activeDraft = MailDraft.compose(from: accountID)
    }

    /// Builds and sends the draft via the per-account SendStore, then closes the
    /// sheet on success. On failure the sheet stays open with the error shown so
    /// the user can fix and retry. The store drops a stale completion (issue #8),
    /// so closing the sheet is gated on success belonging to the live draft.
    private func send(_ draft: MailDraft) async {
        let accountID = draft.accountID
        let succeeded = await sendStore.send(draft) {
            try await accountStore.accessToken(for: accountID)
        }
        if succeeded, activeDraft?.id == draft.id {
            activeDraft = nil
        }
    }

    private func draftBinding(for id: MailDraft.ID) -> Binding<MailDraft> {
        Binding {
            activeDraft ?? MailDraft.compose(from: mailbox?.accountID ?? "")
        } set: { draft in
            activeDraft = draft
        }
    }
}
