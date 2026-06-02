//
//  SidebarModel.swift
//  VoqMail
//
//  View-independent sidebar state and resize policy.
//

import Observation
import SwiftUI

@Observable
final class SidebarModel {
    var isShown = true
    // Scene-local for now: resizing affects the current app run only. Persisting
    // this with AppStorage would be a product behavior change.
    var width = Metrics.sidebarWidth

    /// X position of the seam: the sidebar width when shown, 0 when hidden.
    var seamX: CGFloat {
        isShown ? width : 0
    }

    /// Leading padding for a detail-pane header's content (mailbox or settings):
    /// the normal inset while the sidebar is shown, and a wider one while it is
    /// collapsed so the icon/title slide clear of the traffic lights and the
    /// floating toggle button. Read inside `body` so it animates in the same
    /// observation transaction as `isShown`; never snapshot it.
    var collapsedClearingLeadingPadding: CGFloat {
        isShown
            ? Metrics.mailboxHeaderHorizontalPadding
            : Metrics.mailboxHeaderCollapsedLeadingPadding
    }

    func toggle() {
        isShown.toggle()
    }

    func toggleAnimated() {
        withAnimation(isShown ? Motion.sidebarCollapse : Motion.sidebarExpand) {
            toggle()
        }
    }

    func resize(toProposed proposedWidth: CGFloat) {
        // Once resize auto-collapses the sidebar, the same drag does not re-open it.
        // Re-expansion stays explicit through the toggle button or Cmd+B.
        guard isShown else { return }

        if proposedWidth < Metrics.sidebarAutoCollapseWidth {
            isShown = false
        } else {
            width = min(max(proposedWidth, Metrics.sidebarMinWidth), Metrics.sidebarMaxWidth)
        }
    }

    func resizeAnimated(toProposed proposedWidth: CGFloat) {
        if isShown && proposedWidth < Metrics.sidebarAutoCollapseWidth {
            withAnimation(Motion.sidebarCollapse) {
                resize(toProposed: proposedWidth)
            }
        } else {
            resize(toProposed: proposedWidth)
        }
    }
}
