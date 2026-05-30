//
//  MailSplitView.swift
//  VoqMail
//
//  The app's main layout: a sidebar that slides in and out beside a detail pane,
//  joined by a curved seam. It is built as a ZStack of five layers so the seam
//  stays crisp while the sidebar animates. Each layer's role is documented on
//  `body` below.
//

import SwiftUI

struct MainMailSplitView: View {
    // MARK: - State

    /// Which mailbox is selected in the sidebar.
    @State private var selection: Mailbox.ID? = Mailbox.samples.first?.id
    /// Whether the sidebar is currently shown. Animates between shown and hidden.
    @State private var showsSidebar = true

    // MARK: - Body

    // The layout is a ZStack of five layers, painted bottom to top. The explicit
    // zIndex values keep the paint order stable while the sidebar animates:
    //
    //   zIndex 0  sidebarLayer   – blurred sidebar material + the mailbox list
    //   zIndex 1  detail fill    – opaque rounded shape that "carves" the seam
    //   zIndex 2  detailLayer    – the detail pane content, offset by the sidebar
    //   zIndex 3  sidebarBorder  – hairline stroke tracing the seam
    //   zIndex 4  toggle button  – always on top so it stays clickable
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
                .padding(.top, Metrics.toggleButtonTopPadding)
                .padding(.leading, Metrics.toggleButtonLeadingPadding)
                .zIndex(4)
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    // MARK: - Selection

    private var selectedMailbox: Mailbox? {
        Mailbox.sample(for: selection)
    }

    // MARK: - Animated geometry

    // These two values track the sidebar as it animates: the detail pane's leading
    // edge slides between 0 and the sidebar width, and the seam's corner radius
    // shrinks along with it.

    /// X position of the seam: the sidebar width when shown, 0 when hidden.
    private var currentDetailLeadingEdge: CGFloat {
        showsSidebar ? Metrics.sidebarWidth : 0
    }

    /// Corner radius of the seam, never larger than the space available for it.
    private var currentCornerRadius: CGFloat {
        min(Metrics.cornerRadius, currentDetailLeadingEdge)
    }

    // MARK: - Layers

    /// zIndex 0 — the blurred sidebar material with the mailbox list on top.
    /// Only receives clicks while the sidebar is shown.
    private var sidebarLayer: some View {
        ZStack(alignment: .topLeading) {
            CalibratedSidebarBackground(sidebarWidth: Metrics.sidebarWidth, cornerRadius: Metrics.cornerRadius)
                .allowsHitTesting(false)

            CustomSidebarList(selection: $selection)
                .frame(width: Metrics.sidebarWidth)
                .clipped()
        }
        .allowsHitTesting(showsSidebar)
        .zIndex(0)
    }

    /// zIndex 2 — the detail content, pushed right by an invisible spacer so it
    /// sits beside the sidebar rather than under it.
    private var detailLayer: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: currentDetailLeadingEdge)
                .allowsHitTesting(false)

            MailboxDetail(mailbox: selectedMailbox)
                .frame(minWidth: Metrics.detailMinWidth, maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// zIndex 3 — the hairline stroke along the seam; fades out with the sidebar.
    private var sidebarBorder: some View {
        SidebarRightBorder(sidebarWidth: currentDetailLeadingEdge, radius: currentCornerRadius)
            .stroke(
                Palette.sidebarDivider,
                style: StrokeStyle(lineWidth: 1, lineCap: .butt, lineJoin: .round)
            )
            .opacity(showsSidebar ? 1 : 0)
            .allowsHitTesting(false)
    }

    // MARK: - Actions

    /// Toggles the sidebar, revealing a little slower than it hides.
    private func toggleSidebar() {
        let isExpanding = !showsSidebar
        withAnimation(isExpanding ? Motion.sidebarExpand : Motion.sidebarCollapse) {
            showsSidebar = isExpanding
        }
    }
}

// MARK: - Sidebar background

/// The blurred sidebar material, masked to the sidebar's rounded-corner shape so
/// its right edge lines up exactly with the seam.
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
