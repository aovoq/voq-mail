//
//  MessageHeaderView.swift
//  VoqMail
//
//  Subject, sender metadata, timestamp, and the primary message action.
//

import SwiftUI

struct MessageHeaderView: View {
    let message: MailMessage
    let onReply: (MailMessage) -> Void
    var onToggleRead: (MailMessage) -> Void = { _ in }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text(message.subject)
                    .font(.title.weight(.semibold))
                    .lineLimit(2)

                Text(senderLine)
                    .foregroundStyle(.secondary)

                Text(message.receivedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onToggleRead(message)
            } label: {
                Label(
                    message.isRead ? "Mark Unread" : "Mark Read",
                    systemImage: message.isRead ? "envelope.badge" : "envelope.open")
            }

            Button {
                onReply(message)
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left.fill")
            }
        }
    }

    private var senderLine: String {
        if message.senderAddress.isEmpty {
            return "From \(message.sender)"
        }

        return "From \(message.sender) <\(message.senderAddress)>"
    }
}
