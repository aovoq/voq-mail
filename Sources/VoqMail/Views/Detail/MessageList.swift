//
//  MessageList.swift
//  VoqMail
//
//  A list of message previews (sender, subject, snippet) with a bound selection.
//  Currently exercised only by the reference three-column demo
//  (see Reference/DemoViews.swift), not by the running app's main layout.
//

import SwiftUI

struct MessageList: View {
    let messages: [MailMessage]
    @Binding var selection: MailMessage.ID?

    var body: some View {
        List(selection: $selection) {
            ForEach(messages) { message in
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.sender)
                        .font(.headline)
                        .lineLimit(1)
                    Text(message.subject)
                        .lineLimit(1)
                    Text(message.preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
                .tag(message.id)
            }
        }
    }
}
