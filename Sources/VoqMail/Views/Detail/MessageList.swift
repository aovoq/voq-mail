//
//  MessageList.swift
//  VoqMail
//
//  A list of message previews (sender, subject, snippet) with a bound selection.
//  Used by both the running three-pane mail layout and the reference demo views.
//

import SwiftUI

struct MessageList: View {
    let messages: [MailMessage]
    @Binding var selection: MailMessage.ID?

    var body: some View {
        Group {
            if messages.isEmpty {
                ContentUnavailableView("No Messages", systemImage: "tray")
            } else {
                List(selection: $selection) {
                    ForEach(messages) { message in
                        MessageRow(message: message)
                            .tag(message.id)
                    }
                }
            }
        }
    }
}

private struct MessageRow: View {
    let message: MailMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(message.sender)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(message.receivedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(message.subject)
                .fontWeight(message.isRead ? .regular : .semibold)
                .lineLimit(1)

            Text(message.preview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}
