//
//  SplitSurfaceShapes.swift
//  VoqMail
//
//  The curved boundary — the "seam" — between the sidebar and the detail pane.
//  Three Shapes draw three views of the SAME seam:
//
//    • SidebarPaneSurface  – fills the sidebar region; used as a mask for the
//                            blurred sidebar material.
//    • DetailPaneSurface   – fills the detail region; its rounded left edge is
//                            what visually carves the sidebar's rounded corner.
//    • SidebarRightBorder  – the thin curved stroke drawn along the seam.
//
//  All three compute the same corner points, so that math lives once in
//  `SidebarSeam`. Each shape also repeats the same `animatableData` so the
//  sidebar width and corner radius animate smoothly as the sidebar collapses.
//

import SwiftUI

// MARK: - Shared geometry

/// The key points of the curved seam at `x = rect.minX + sidebarWidth`.
///
/// Computing them once here guarantees the three shapes trace the exact same
/// curve; each shape just connects these points in its own order.
private struct SidebarSeam {
    let outerTop: CGPoint      // (x + radius, minY)  – where the top curve meets the flat top edge
    let innerTop: CGPoint      // (x, minY + radius)  – where the top curve meets the vertical seam
    let topControl: CGPoint    // (x, minY)           – control point for the top curve
    let innerBottom: CGPoint   // (x, maxY - radius)  – where the vertical seam meets the bottom curve
    let outerBottom: CGPoint   // (x + radius, maxY)  – where the bottom curve meets the flat bottom edge
    let bottomControl: CGPoint // (x, maxY)           – control point for the bottom curve

    init(in rect: CGRect, sidebarWidth: CGFloat, radius: CGFloat) {
        let x = rect.minX + sidebarWidth
        let r = clampedRadius(radius, in: rect, boundaryX: x)
        outerTop = CGPoint(x: x + r, y: rect.minY)
        innerTop = CGPoint(x: x, y: rect.minY + r)
        topControl = CGPoint(x: x, y: rect.minY)
        innerBottom = CGPoint(x: x, y: rect.maxY - r)
        outerBottom = CGPoint(x: x + r, y: rect.maxY)
        bottomControl = CGPoint(x: x, y: rect.maxY)
    }
}

/// Keeps the corner radius within the space available, so the curve never
/// overshoots the pane or folds past the vertical midpoint.
private func clampedRadius(_ radius: CGFloat, in rect: CGRect, boundaryX x: CGFloat) -> CGFloat {
    max(0, min(radius, rect.maxX - x, rect.height / 2))
}

// MARK: - Sidebar pane surface

/// Fills the whole sidebar region, rounding the top-right and bottom-right
/// corners along the seam. Used as a mask for the blurred sidebar material.
struct SidebarPaneSurface: Shape {
    var sidebarWidth: CGFloat
    var radius: CGFloat

    /// Lets SwiftUI animate `sidebarWidth` and `radius` together as one pair.
    /// (The other two shapes repeat this same pattern.)
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(sidebarWidth, radius) }
        set {
            sidebarWidth = newValue.first
            radius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let seam = SidebarSeam(in: rect, sidebarWidth: sidebarWidth, radius: radius)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: seam.outerTop)
        path.addQuadCurve(to: seam.innerTop, control: seam.topControl)
        path.addLine(to: seam.innerBottom)
        path.addQuadCurve(to: seam.outerBottom, control: seam.bottomControl)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Detail pane surface

/// Fills the detail region to the right of the seam, rounding the top-left and
/// bottom-left corners. Painted opaque over the sidebar so its curved edge
/// "cuts" the sidebar's rounded corner.
struct DetailPaneSurface: Shape {
    var sidebarWidth: CGFloat
    var radius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(sidebarWidth, radius) }
        set {
            sidebarWidth = newValue.first
            radius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let seam = SidebarSeam(in: rect, sidebarWidth: sidebarWidth, radius: radius)

        var path = Path()
        path.move(to: seam.outerTop)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: seam.outerBottom)
        path.addQuadCurve(to: seam.innerBottom, control: seam.bottomControl)
        path.addLine(to: seam.innerTop)
        path.addQuadCurve(to: seam.outerTop, control: seam.topControl)
        path.closeSubpath()
        return path
    }
}

// MARK: - Sidebar right border

/// The thin curved stroke that traces the seam, drawn on top as a hairline.
struct SidebarRightBorder: Shape {
    var sidebarWidth: CGFloat
    var radius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(sidebarWidth, radius) }
        set {
            sidebarWidth = newValue.first
            radius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let seam = SidebarSeam(in: rect, sidebarWidth: sidebarWidth, radius: radius)

        var path = Path()
        path.move(to: seam.outerTop)
        path.addQuadCurve(to: seam.innerTop, control: seam.topControl)
        path.addLine(to: seam.innerBottom)
        path.addQuadCurve(to: seam.outerBottom, control: seam.bottomControl)
        return path
    }
}
