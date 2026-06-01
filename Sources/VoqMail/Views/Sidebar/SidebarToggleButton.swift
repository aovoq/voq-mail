//
//  SidebarToggleButton.swift
//  VoqMail
//
//  The small button that shows or hides the sidebar. It lives at the top-left of
//  the window, positioned just right of the traffic-light buttons (see
//  `Metrics.toggleButtonLeadingPadding`). It highlights faintly on hover.
//

import SwiftUI

struct SidebarToggleButton: View {
    let isExpanded: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var label: String { isExpanded ? "Hide Sidebar" : "Show Sidebar" }
    private var helpText: String { "\(label) (⌘B)" }

    var body: some View {
        Image(systemName: "sidebar.left")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 24, height: 22)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.black.opacity(Palette.toggleHoverOpacity) : Color.clear)
            }
            // Make the whole 28x24 frame clickable, including the transparent parts.
            .contentShape(Rectangle())
            // Respond to EVERY click, including rapid ones. The button sits in the
            // transparent title-bar band over a window with
            // `isMovableByWindowBackground = true`, so on a fast click sequence macOS
            // tags the 2nd/3rd click as a title-bar double-click (or drifts it into a
            // window drag) and steals the mouse-up — a plain `Button` then latches in
            // its pressed state and "stops responding" until you pause. A zero-distance
            // drag gesture instead claims the press and fires on every mouse-up
            // regardless of click count, so each click toggles. Accessibility traits
            // below restore what a plain Image would otherwise lack.
            .gesture(
                DragGesture(minimumDistance: 0).onEnded { _ in action() }
            )
            .onHover { isHovered = $0 }
            .help(helpText)
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(label)
    }
}
