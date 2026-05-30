//
//  MessageDetail.swift
//  VoqMail
//
//  The full view of one message: subject, sender, and body — or a neutral
//  empty state when nothing is selected. Currently exercised only by the
//  reference three-column demo (see Reference/DemoViews.swift).
//

import SwiftUI

struct MessageDetail: View {
    let message: MailMessage?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let message {
                Text(message.subject)
                    .font(.largeTitle.weight(.semibold))
                Text("From \(message.sender)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Divider()
                Text(message.preview)
                    .font(.body)
                Spacer()
            } else {
                ContentUnavailableView(
                    "No Message",
                    systemImage: "envelope",
                    description: Text("Choose a message from the list.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(28)
    }
}
