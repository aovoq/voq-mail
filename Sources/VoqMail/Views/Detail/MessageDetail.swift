//
//  MessageDetail.swift
//  VoqMail
//
//  The right-hand detail pane for the selected message. It composes the message
//  header, HTML body, and optional attachments without owning mailbox selection.
//

import SwiftUI

struct MessageDetail: View {
    let message: MailMessage?
    var onReply: (MailMessage) -> Void = { _ in }

    var body: some View {
        Group {
            if let message {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        MessageHeaderView(message: message, onReply: onReply)

                        Divider()

                        HTMLMailView(html: message.htmlBody)
                            .frame(minHeight: 260)

                        if !message.attachments.isEmpty {
                            Divider()
                            MessageAttachmentsView(attachments: message.attachments)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
