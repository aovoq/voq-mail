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

    var body: some View {
        Button(action: action) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 24)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.black.opacity(Palette.toggleHoverOpacity) : Color.clear)
                }
        }
        .buttonStyle(.plain)
        .help(isExpanded ? "Hide Sidebar" : "Show Sidebar")
        .onHover { isHovered = $0 }
    }
}
