//
//  SidebarRowStyle.swift
//  VoqMail
//
//  The selection-highlight chrome shared by every selectable sidebar/tab row:
//  the rounded selection fill, the outer horizontal inset that frames it, and the
//  hit shape — in one place so the mailbox rows, the sidebar's Settings footer,
//  and the settings tab rows stay visually identical. Row height stays at each
//  call site, since they differ (sidebar rows vs. taller tab rows).
//

import SwiftUI

extension View {
    /// Selection-highlight background + outer inset + hit shape. Apply it
    /// immediately after the caller's own `.frame` so the view-tree order stays
    /// `frame → background → padding(.horizontal, inset) → contentShape`.
    func sidebarRowSelection(isSelected: Bool) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: Metrics.sidebarRowCornerRadius)
                    .fill(isSelected
                          ? Color(nsColor: .selectedContentBackgroundColor).opacity(Palette.sidebarRowSelectionOpacity)
                          : .clear)
            }
            .padding(.horizontal, Metrics.sidebarRowSelectionInset)
            .contentShape(Rectangle())
    }
}
