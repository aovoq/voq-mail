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

struct CustomSidebarRow: View {
    let mailbox: Mailbox
    let isSelected: Bool
    var depth: Int = 0
    var disclosure: SidebarDisclosure = .none
    var onToggle: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
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
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: Metrics.sidebarRowHeight, maxHeight: Metrics.sidebarRowHeight, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Metrics.sidebarRowCornerRadius)
                .fill(isSelected
                      ? Color(nsColor: .selectedContentBackgroundColor).opacity(Palette.sidebarRowSelectionOpacity)
                      : .clear)
        }
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }

    /// The leading chevron for rows with children, or an equal-width spacer so all
    /// rows' icons line up. Its tap is handled separately from selecting the row.
    @ViewBuilder
    private var disclosureControl: some View {
        switch disclosure {
        case .none:
            Color.clear.frame(width: Metrics.sidebarDisclosureWidth)
        case .collapsed, .expanded:
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(disclosure == .expanded ? 90 : 0))
                .frame(width: Metrics.sidebarDisclosureWidth)
                .contentShape(Rectangle())
                .onTapGesture { onToggle?() }
        }
    }
}
