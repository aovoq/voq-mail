import SwiftUI

struct NativeTwoColumnDemo: View {
    @State private var selection: Mailbox.ID? = Mailbox.samples.first?.id

    var body: some View {
        HStack(spacing: 0) {
            CustomSidebarList(selection: $selection)
                .frame(width: 180)

            MailboxDetail(mailbox: selectedMailbox)
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var selectedMailbox: Mailbox? {
        Mailbox.samples.first { $0.id == selection }
    }
}

struct ThreeColumnDemo: View {
    @State private var mailboxSelection: Mailbox.ID? = Mailbox.samples.first?.id
    @State private var messageSelection: MailMessage.ID? = MailMessage.samples.first?.id

    var body: some View {
        HStack(spacing: 0) {
            CustomSidebarList(selection: $mailboxSelection)
                .frame(width: 180)

            MessageList(messages: messages, selection: $messageSelection)
                .frame(width: 280)

            MessageDetail(message: selectedMessage)
                .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: mailboxSelection) { _, _ in
            messageSelection = messages.first?.id
        }
    }

    private var messages: [MailMessage] {
        MailMessage.samples.filter { $0.mailboxID == mailboxSelection }
    }

    private var selectedMessage: MailMessage? {
        messages.first { $0.id == messageSelection }
    }
}
