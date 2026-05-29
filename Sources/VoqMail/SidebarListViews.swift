import SwiftUI

struct CustomSidebarList: View {
    @Binding var selection: Mailbox.ID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                Text("Mailboxes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.top, 44)
                    .padding(.bottom, 6)

                ForEach(Mailbox.samples) { mailbox in
                    Button {
                        selection = mailbox.id
                    } label: {
                        CustomSidebarRow(mailbox: mailbox, isSelected: selection == mailbox.id)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
        }
        .scrollContentBackground(.hidden)
        .ignoresSafeArea(.container, edges: .top)
    }
}

struct CustomSidebarRow: View {
    let mailbox: Mailbox
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: mailbox.systemImage)
                .frame(width: 18)
                .foregroundStyle(isSelected ? .primary : .secondary)

            Text(mailbox.title)
                .font(.body)
                .lineLimit(1)

            Spacer()

            if let count = mailbox.count {
                Text(count, format: .number)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.18) : .clear)
        }
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}

struct SidebarToggleButton: View {
    let isExpanded: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 24)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.black.opacity(0.08) : Color.clear)
                }
        }
        .buttonStyle(.plain)
        .help(isExpanded ? "Hide Sidebar" : "Show Sidebar")
        .onHover { isHovered = $0 }
    }
}

struct SidebarList: View {
    @Binding var selection: Mailbox.ID?

    var body: some View {
        List(selection: $selection) {
            Section("Mailboxes") {
                ForEach(Mailbox.samples) { mailbox in
                    Label {
                        HStack {
                            Text(mailbox.title)
                            Spacer()
                            if let count = mailbox.count {
                                Text(count, format: .number)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: mailbox.systemImage)
                    }
                    .tag(mailbox.id)
                }
            }
        }
        .listStyle(.sidebar)
    }
}
