//
//  Constants.swift
//  VoqMail
//
//  The app's design tokens in one place: layout sizes, motion curves, colors,
//  and window sizing. Each value has a descriptive name so it can be found and
//  tuned without hunting through view code, and so related values (e.g. the
//  sidebar width used in two places) stay in sync.
//
//  Every number here is identical to the inline literal it replaced — naming a
//  value never changes it.
//

import SwiftUI

// MARK: - Metrics

/// Sizes and spacing for the main split layout and the sidebar.
enum Metrics {
    /// Width of the sidebar pane. The sidebar's background mask and its list frame
    /// must use the SAME width, so they both read this single value.
    static let sidebarWidth: CGFloat = 220

    /// Corner radius of the curved seam between the sidebar and the detail pane.
    static let cornerRadius: CGFloat = 24

    /// Smallest width the detail pane is allowed to shrink to.
    static let detailMinWidth: CGFloat = 420

    /// Padding that positions the floating sidebar toggle button. The leading
    /// value is chosen to clear the window's traffic-light buttons
    /// (see `TrafficLightLayout` in WindowChromeConfigurator.swift).
    static let toggleButtonTopPadding: CGFloat = 11
    static let toggleButtonLeadingPadding: CGFloat = 78

    // Sidebar list internals
    static let sidebarRowHeight: CGFloat = 28
    static let sidebarRowCornerRadius: CGFloat = 6
    static let sidebarRowIconWidth: CGFloat = 18
    static let sidebarHeaderTopPadding: CGFloat = 44
}

// MARK: - Motion

/// Animations for showing and hiding the sidebar. Expand is a touch slower than
/// collapse so the reveal settles gently.
///
/// Named `Motion` rather than `Animation` on purpose: an enum called `Animation`
/// would shadow SwiftUI's own `Animation` type and cause confusing errors.
enum Motion {
    /// Ease-out curve; the sidebar reveals slightly slower (0.44s) for a gentle settle.
    static let sidebarExpand = Animation.timingCurve(0.16, 1.0, 0.30, 1.0, duration: 0.44)

    /// Ease-in-out curve; the sidebar collapses a little faster (0.34s).
    static let sidebarCollapse = Animation.timingCurve(0.55, 0.0, 0.20, 1.0, duration: 0.34)
}

// MARK: - Palette

/// Named colors used by the custom chrome.
enum Palette {
    /// Hairline divider tracing the curved seam (a light ~230/255 grey).
    static let sidebarDivider = Color(red: 0.902, green: 0.902, blue: 0.902)

    /// Opacity applied to the system selection color behind a selected sidebar row.
    static let sidebarRowSelectionOpacity: Double = 0.18

    /// Opacity of the toggle button's hover highlight.
    static let toggleHoverOpacity: Double = 0.08
}

// MARK: - Window

/// Window sizing for the app's main scene. (Named `WindowMetrics`, not
/// `WindowChrome`, to avoid confusion with the `WindowChromeConfigurator` bridge.)
enum WindowMetrics {
    /// Size the window opens at.
    static let defaultSize = CGSize(width: 980, height: 620)
    /// Smallest the window can be resized to.
    static let minSize = CGSize(width: 760, height: 460)
}
