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
