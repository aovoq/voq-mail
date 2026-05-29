import SwiftUI

struct MailboxDetail: View {
    let mailbox: Mailbox?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: mailbox?.systemImage ?? "tray")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.tint)

            Text(mailbox?.title ?? "Select a mailbox")
                .font(.largeTitle.weight(.semibold))

            Text("This detail pane changes with the sidebar selection.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

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
