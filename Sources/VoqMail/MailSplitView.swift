import SwiftUI

struct MainMailSplitView: View {
    @State private var selection: Mailbox.ID? = Mailbox.samples.first?.id
    @State private var showsSidebar = true

    private let sidebarWidth = 220.0
    private let cornerRadius = 24.0
    private let expandAnimation = Animation.timingCurve(0.16, 1.0, 0.30, 1.0, duration: 0.44)
    private let collapseAnimation = Animation.timingCurve(0.55, 0.0, 0.20, 1.0, duration: 0.34)

    var body: some View {
        ZStack(alignment: .topLeading) {
            sidebarLayer

            DetailPaneSurface(sidebarWidth: currentDetailLeadingEdge, radius: currentCornerRadius)
                .fill(Color(nsColor: .windowBackgroundColor))
                .allowsHitTesting(false)
                .zIndex(1)

            detailLayer
                .zIndex(2)

            sidebarBorder
                .zIndex(3)

            SidebarToggleButton(isExpanded: showsSidebar, action: toggleSidebar)
                .padding(.top, 11)
                .padding(.leading, 78)
                .zIndex(4)
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    private var selectedMailbox: Mailbox? {
        Mailbox.samples.first { $0.id == selection }
    }

    private var currentDetailLeadingEdge: CGFloat {
        showsSidebar ? sidebarWidth : 0
    }

    private var currentCornerRadius: CGFloat {
        min(cornerRadius, currentDetailLeadingEdge)
    }

    private var sidebarLayer: some View {
        ZStack(alignment: .topLeading) {
            CalibratedSidebarBackground(sidebarWidth: sidebarWidth, cornerRadius: cornerRadius)
                .allowsHitTesting(false)

            CustomSidebarList(selection: $selection)
                .frame(width: sidebarWidth)
                .clipped()
        }
        .allowsHitTesting(showsSidebar)
        .zIndex(0)
    }

    private var detailLayer: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: currentDetailLeadingEdge)
                .allowsHitTesting(false)

            MailboxDetail(mailbox: selectedMailbox)
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var sidebarBorder: some View {
        SidebarRightBorder(sidebarWidth: currentDetailLeadingEdge, radius: currentCornerRadius)
            .stroke(
                Color(red: 0.902, green: 0.902, blue: 0.902),
                style: StrokeStyle(lineWidth: 1, lineCap: .butt, lineJoin: .round)
            )
            .opacity(showsSidebar ? 1 : 0)
            .allowsHitTesting(false)
    }

    private func toggleSidebar() {
        let isExpanding = !showsSidebar
        withAnimation(isExpanding ? expandAnimation : collapseAnimation) {
            showsSidebar = isExpanding
        }
    }
}

private struct CalibratedSidebarBackground: View {
    let sidebarWidth: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        VisualEffectBackground(style: .calibratedSidebar)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .mask(
                SidebarPaneSurface(sidebarWidth: sidebarWidth, radius: cornerRadius)
                    .fill(Color.black)
            )
    }
}
