import AppKit
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

struct CustomSplitDemo: View {
    @State private var selection: Mailbox.ID? = Mailbox.samples.first?.id
    @State private var showsSidebar = true
    private let sidebarWidth = 220.0
    private let cornerRadius = 24.0

    var body: some View {
        ZStack(alignment: .topLeading) {
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .mask(
                    SidebarPaneSurface(sidebarWidth: currentSidebarWidth, radius: currentCornerRadius)
                        .fill(Color.black)
                )
                .opacity(showsSidebar ? 1 : 0)
                .allowsHitTesting(false)

            DetailPaneSurface(sidebarWidth: currentSidebarWidth, radius: currentCornerRadius)
                .fill(Color(nsColor: .windowBackgroundColor))
                .allowsHitTesting(false)

            HStack(spacing: 0) {
                CustomSidebarList(selection: $selection)
                    .frame(width: currentSidebarWidth)
                    .opacity(showsSidebar ? 1 : 0)
                    .clipped()

                MailboxDetail(mailbox: selectedMailbox)
                    .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
            }

            SidebarRightBorder(sidebarWidth: currentSidebarWidth, radius: currentCornerRadius)
                .stroke(
                    Color(red: 0.902, green: 0.902, blue: 0.902),
                    style: StrokeStyle(lineWidth: 1, lineCap: .butt, lineJoin: .round)
                )
                .opacity(showsSidebar ? 1 : 0)
                .allowsHitTesting(false)

            SidebarToggleButton(isExpanded: showsSidebar) {
                withAnimation(.easeInOut(duration: 0.22)) {
                    showsSidebar.toggle()
                }
            }
            .padding(.top, 11)
            .padding(.leading, 78)
        }
        .animation(.easeInOut(duration: 0.22), value: currentSidebarWidth)
        .ignoresSafeArea(.container, edges: .top)
    }

    private var selectedMailbox: Mailbox? {
        Mailbox.samples.first { $0.id == selection }
    }

    private var currentSidebarWidth: CGFloat {
        showsSidebar ? sidebarWidth : 0
    }

    private var currentCornerRadius: CGFloat {
        min(cornerRadius, currentSidebarWidth)
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
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .followsWindowActiveState
    }
}

struct CustomSidebarList: View {
    // The currently selected mailbox id is owned by the parent view.
    // This sidebar only reads and updates that shared selection.
    @Binding var selection: Mailbox.ID?

    var body: some View {
        // The mailbox rows can scroll if the sidebar becomes shorter than the
        // content. Background is owned by CustomSplitDemo so it stays one
        // continuous material surface from the window top to bottom.
        ScrollView {
            // Vertical layout for the section title and mailbox buttons.
            VStack(alignment: .leading, spacing: 2) {
                // Small section label at the top of the sidebar.
                Text("Mailboxes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.top, 44)
                    .padding(.bottom, 6)

                // Render one selectable row for each sample mailbox.
                ForEach(Mailbox.samples) { mailbox in
                    // A plain button keeps the row clickable without adding
                    // the default rounded macOS button chrome.
                    Button {
                        // Update the parent-owned selection when clicked.
                        selection = mailbox.id
                    } label: {
                        // The row decides its own selected appearance.
                        CustomSidebarRow(mailbox: mailbox, isSelected: selection == mailbox.id)
                    }
                    .buttonStyle(.plain)
                }

                // Keeps extra empty space below the rows instead of forcing
                // the rows to stretch vertically.
                Spacer(minLength: 0)
            }
            // Let rows use the full sidebar width while keeping their
            // contents aligned to the left.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
        }
        // Prevent SwiftUI from applying a separate scroll background.
        .scrollContentBackground(.hidden)
        .ignoresSafeArea(.container, edges: .top)
    }
}

struct SidebarPaneSurface: Shape {
    let sidebarWidth: CGFloat
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let x = rect.minX + sidebarWidth
        let clampedRadius = min(radius, rect.maxX - x, rect.height / 2)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: x + clampedRadius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: x, y: rect.minY + clampedRadius),
            control: CGPoint(x: x, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: x, y: rect.maxY - clampedRadius))
        path.addQuadCurve(
            to: CGPoint(x: x + clampedRadius, y: rect.maxY),
            control: CGPoint(x: x, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct DetailPaneSurface: Shape {
    let sidebarWidth: CGFloat
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let x = rect.minX + sidebarWidth
        let clampedRadius = min(radius, rect.maxX - x, rect.height / 2)

        var path = Path()
        path.move(to: CGPoint(x: x + clampedRadius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: x + clampedRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: x, y: rect.maxY - clampedRadius),
            control: CGPoint(x: x, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: x, y: rect.minY + clampedRadius))
        path.addQuadCurve(
            to: CGPoint(x: x + clampedRadius, y: rect.minY),
            control: CGPoint(x: x, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

struct SidebarRightBorder: Shape {
    let sidebarWidth: CGFloat
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let x = rect.minX + sidebarWidth
        let clampedRadius = min(radius, rect.maxX - x, rect.height / 2)

        var path = Path()
        path.move(to: CGPoint(x: x + clampedRadius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: x, y: rect.minY + clampedRadius),
            control: CGPoint(x: x, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: x, y: rect.maxY - clampedRadius))
        path.addQuadCurve(
            to: CGPoint(x: x + clampedRadius, y: rect.maxY),
            control: CGPoint(x: x, y: rect.maxY)
        )
        return path
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

    private var selectedMailbox: Mailbox? {
        Mailbox.samples.first { $0.id == mailboxSelection }
    }

    private var messages: [MailMessage] {
        MailMessage.samples.filter { $0.mailboxID == mailboxSelection }
    }

    private var selectedMessage: MailMessage? {
        messages.first { $0.id == messageSelection }
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
        .frame(height: 28)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isSelected
                        ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.18)
                        : Color.clear)
        }
        .padding(.horizontal, 8)
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
                    "No Message", systemImage: "envelope",
                    description: Text("Choose a message from the list."))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(28)
    }
}
