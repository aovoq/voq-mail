//
//  MailSplitView.swift
//  VoqMail
//
//  The app's main layout: a sidebar that slides in and out beside a detail pane,
//  joined by a curved seam. It is built as a ZStack of six layers so the seam
//  stays crisp while the sidebar animates. Each layer's role is documented on
//  `body` below.
//

import SwiftUI

struct MainMailSplitView: View {
    // MARK: - State

    @Environment(SidebarModel.self) private var sidebarModel

    /// Which mailbox is selected in the sidebar.
    @State private var selection: Mailbox.ID? = Mailbox.samples.first?.id

    // MARK: - Body

    // The layout is a ZStack of six layers, painted bottom to top. The explicit
    // zIndex values keep the paint order stable while the sidebar animates:
    //
    //   zIndex 0  sidebarLayer   – blurred sidebar material + the mailbox list
    //   zIndex 1  detail fill    – opaque rounded shape that "carves" the seam
    //   zIndex 2  detailLayer    – the detail content, clipped to the same seam
    //   zIndex 3  sidebarBorder  – hairline stroke tracing the seam
    //   zIndex 4  resize handle  – invisible hit area centered on the seam
    //   zIndex 5  toggle button  – always on top so it stays clickable
    var body: some View {
        ZStack(alignment: .topLeading) {
            sidebarLayer

            DetailPaneSurface(sidebarWidth: sidebarModel.seamX, radius: currentCornerRadius)
                .fill(Color(nsColor: .windowBackgroundColor))
                .allowsHitTesting(false)
                .zIndex(1)

            detailLayer
                .clipShape(DetailPaneSurface(sidebarWidth: sidebarModel.seamX, radius: currentCornerRadius))
                .zIndex(2)

            sidebarBorder
                .zIndex(3)

            sidebarResizeHandle
                .zIndex(4)

            SidebarToggleButton(isExpanded: sidebarModel.isShown, action: sidebarModel.toggleAnimated)
                .padding(.top, Metrics.toggleButtonTopPadding)
                .padding(.leading, Metrics.toggleButtonLeadingPadding)
                .zIndex(5)
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    // MARK: - Selection

    private var selectedMailbox: Mailbox? {
        Mailbox.sample(for: selection)
    }

    // MARK: - Animated geometry

    // The model owns the seam's X position. This derived radius shrinks with it
    // so the detail pane can collapse cleanly to the window edge.

    /// Corner radius of the seam, never larger than the space available for it.
    private var currentCornerRadius: CGFloat {
        min(Metrics.cornerRadius, sidebarModel.seamX)
    }

    // MARK: - Layers

    /// zIndex 0 — the blurred sidebar material with the mailbox list on top.
    /// Only receives clicks while the sidebar is shown.
    private var sidebarLayer: some View {
        ZStack(alignment: .topLeading) {
            CalibratedSidebarBackground(sidebarWidth: sidebarModel.width, cornerRadius: Metrics.cornerRadius)
                .allowsHitTesting(false)

            CustomSidebarList(selection: $selection)
                .frame(width: sidebarModel.width)
                .clipped()
        }
        .allowsHitTesting(sidebarModel.isShown)
        .zIndex(0)
    }

    /// zIndex 2 — the detail content, pushed right by an invisible spacer so it
    /// sits beside the sidebar rather than under it.
    private var detailLayer: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: sidebarModel.seamX)
                .allowsHitTesting(false)

            MailboxDetail(mailbox: selectedMailbox)
                .frame(minWidth: Metrics.detailMinWidth, maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// zIndex 3 — the hairline stroke along the seam; fades out with the sidebar.
    private var sidebarBorder: some View {
        SidebarRightBorder(sidebarWidth: sidebarModel.seamX, radius: currentCornerRadius)
            .stroke(
                Palette.sidebarDivider,
                style: StrokeStyle(lineWidth: 1, lineCap: .butt, lineJoin: .round)
            )
            .opacity(sidebarModel.isShown ? 1 : 0)
            .allowsHitTesting(false)
    }

    /// zIndex 4 — invisible drag target centered on the seam.
    private var sidebarResizeHandle: some View {
        SidebarResizeHandle(
            seamX: sidebarModel.seamX,
            hitWidth: Metrics.sidebarResizeHitWidth,
            isEnabled: sidebarModel.isShown,
            onResize: sidebarModel.resizeAnimated
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
