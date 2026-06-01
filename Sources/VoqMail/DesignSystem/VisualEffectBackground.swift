//
//  VisualEffectBackground.swift
//  VoqMail
//
//  A small AppKit bridge that lets SwiftUI use AppKit's `NSVisualEffectView`
//  (the system blur/material used behind sidebars). A `VisualEffectStyle` bundles
//  all the knobs; the calibrated sidebar look is defined in
//  SidebarColorCalibration.swift.
//

import AppKit
import CoreImage
import SwiftUI

// MARK: - Bridge

/// Wraps `NSVisualEffectView` so it can be used as a SwiftUI `View`.
///
/// `makeNSView` builds the view once; `updateNSView` re-applies the style whenever
/// SwiftUI re-renders. Both funnel through `configure` so there is a single place
/// that maps the style onto the AppKit view.
struct VisualEffectBackground: NSViewRepresentable {
    let style: VisualEffectStyle

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        configure(view)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        configure(view)
    }

    private func configure(_ view: NSVisualEffectView) {
        view.material = style.material
        view.blendingMode = style.blendingMode
        view.state = style.state
        view.appearance = style.appearanceName.flatMap(NSAppearance.init(named:))
        view.isEmphasized = style.isEmphasized
        view.contentFilters = style.contentFilters()
    }
}

// MARK: - Style

/// Every setting needed to configure an `NSVisualEffectView`, grouped so call
/// sites can pick a named preset instead of setting six properties by hand.
struct VisualEffectStyle {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let state: NSVisualEffectView.State
    let appearanceName: NSAppearance.Name?
    let isEmphasized: Bool
    /// Built lazily each time so fresh `CIFilter` instances are handed to the view.
    let contentFilters: () -> [CIFilter]

    /// The calibrated sidebar material. Pinned to the `.aqua` (light) appearance
    /// on purpose — the color calibration was tuned for light mode only.
    static let calibratedSidebar = VisualEffectStyle(
        material: .titlebar,
        blendingMode: .behindWindow,
        state: .followsWindowActiveState,
        appearanceName: .aqua,
        isEmphasized: false,
        contentFilters: SidebarMaterialCalibration.makeFilters
    )
}
