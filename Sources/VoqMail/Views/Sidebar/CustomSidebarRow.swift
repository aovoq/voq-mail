//
//  CustomSidebarRow.swift
//  VoqMail
//
//  A single mailbox row: an optional disclosure chevron, icon, title, and an
//  optional unread count. Highlights its background when selected and dims the
//  icon when not. Nested rows indent by `depth`; rows with children show a
//  chevron whose tap toggles expansion independently of selecting the row.
//

import SwiftUI

/// Whether a row shows a disclosure chevron, and its state when it does.
enum SidebarDisclosure {
    case none
    case collapsed
    case expanded
}

/// The leading disclosure glyph used by sidebar rows and account headers: a
/// chevron that rotates to point down when expanded. Just the glyph — callers
/// own any fixed width, hit target, or tap gesture around it.
struct DisclosureChevron: View {
    let isExpanded: Bool

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
    }
}

struct CustomSidebarRow: View {
    let mailbox: Mailbox
    let isSelected: Bool
    var depth: Int = 0
    var disclosure: SidebarDisclosure = .none
    var onToggle: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Metrics.sidebarRowContentSpacing) {
            disclosureControl

            Image(systemName: mailbox.systemImage)
                .frame(width: Metrics.sidebarRowIconWidth)
                .foregroundStyle(isSelected ? .primary : .secondary)

            Text(mailbox.title)
                .font(.body)
                .lineLimit(1)

            Spacer()

            if let count = mailbox.unreadCount {
                Text(count, format: .number)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
        .padding(.leading, CGFloat(depth) * Metrics.sidebarIndentWidth)
        .padding(.horizontal, Metrics.sidebarRowContentSpacing)
        .frame(maxWidth: .infinity, minHeight: Metrics.sidebarRowHeight, maxHeight: Metrics.sidebarRowHeight, alignment: .leading)
        .sidebarRowSelection(isSelected: isSelected)
    }

    /// The leading chevron for rows with children, or an equal-width spacer so all
    /// rows' icons line up. Its tap is handled separately from selecting the row.
    @ViewBuilder
    private var disclosureControl: some View {
        switch disclosure {
        case .none:
            Color.clear.frame(width: Metrics.sidebarDisclosureWidth)
        case .collapsed, .expanded:
            DisclosureChevron(isExpanded: disclosure == .expanded)
                .frame(width: Metrics.sidebarDisclosureWidth)
                .contentShape(Rectangle())
                .onTapGesture { onToggle?() }
        }
    }
}
