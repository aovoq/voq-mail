//
//  MessageDetail.swift
//  VoqMail
//
//  The right-hand detail pane for the selected message: a fixed header on top,
//  the HTML body filling the remaining space (the web view scrolls its own
//  content), and — only when present — an attachments footer. Body and
//  attachment bytes are loaded by the caller; this view reflects what it is given
//  and shows a spinner while the body is still loading.
//

import SwiftUI

struct MessageDetail: View {
    let message: MailMessage?
    var isLoadingContent: Bool = false
    var downloadingAttachmentIDs: Set<String> = []
    var onReply: (MailMessage) -> Void = { _ in }
    var onToggleRead: (MailMessage) -> Void = { _ in }
    var onPreviewAttachment: (MailAttachment) -> Void = { _ in }

    var body: some View {
        Group {
            if let message {
                VStack(spacing: 0) {
                    MessageHeaderView(message: message, onReply: onReply, onToggleRead: onToggleRead)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 14)

                    Divider()

                    // Fills the remaining height; the web view scrolls internally.
                    HTMLMailView(html: message.htmlBody)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay {
                            if isLoadingContent {
                                ProgressView()
                            }
                        }

                    if !message.attachments.isEmpty {
                        Divider()
                        ScrollView {
                            MessageAttachmentsView(
                                attachments: message.attachments,
                                downloadingIDs: downloadingAttachmentIDs,
                                onPreview: onPreviewAttachment)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                        }
                        .frame(maxHeight: 260)
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Message",
                    systemImage: "envelope",
                    description: Text("Choose a message from the list.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
