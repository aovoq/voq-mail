//
//  CustomSidebarRow.swift
//  VoqMail
//
//  A single mailbox row: icon, title, and an optional unread count. Highlights its
//  background when selected and dims the icon when not.
//

import SwiftUI

struct CustomSidebarRow: View {
    let mailbox: Mailbox
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: mailbox.systemImage)
                .frame(width: Metrics.sidebarRowIconWidth)
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
}
