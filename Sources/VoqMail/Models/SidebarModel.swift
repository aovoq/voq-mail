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
