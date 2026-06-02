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

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        configure(view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        configure(view, coordinator: context.coordinator)
    }

    private func configure(_ view: NSVisualEffectView, coordinator: Coordinator) {
        // Plain scalars are cheap and a no-op when unchanged, so just assign them.
        view.material = style.material
        view.blendingMode = style.blendingMode
        view.state = style.state
        view.isEmphasized = style.isEmphasized

        // `appearance` and `contentFilters` allocate fresh objects each call, and
        // the filter pipeline in particular is expensive (~8 CIFilters). Both are
        // stable for a given style, so apply them only when the style's identity
        // changes — not on every SwiftUI re-render (e.g. each frame of a sidebar
        // resize). A future dynamic style (dark mode, per-account theming) gets a
        // different token and is reapplied correctly.
        //
        // This is purely an efficiency measure. The window-activation transparency
        // flicker is handled elsewhere, by `CalibratedSidebarMaterial`'s opaque
        // fallback — not by skipping work here.
        if coordinator.appliedStyleToken != style.identityToken {
            view.appearance = style.appearanceName.flatMap(NSAppearance.init(named:))
            view.contentFilters = style.contentFilters()
            coordinator.appliedStyleToken = style.identityToken
        }
    }

    /// Survives across SwiftUI updates so the calibrated filter chain is rebuilt
    /// only when the style actually changes, not on every re-render. One coordinator
    /// is created per view, so every instance still receives the full pipeline.
    final class Coordinator {
        var appliedStyleToken: AnyHashable?
    }
}

// MARK: - Calibrated sidebar material

/// The calibrated sidebar material, backed by an opaque fallback color.
///
/// `.calibratedSidebar` uses `state: .followsWindowActiveState`, so AppKit
/// re-resolves the `.behindWindow` backdrop on every window inactive↔active
/// transition. For the one frame while that happens the material renders nothing,
/// and because the host window is non-opaque with a clear background (see
/// `WindowChromeConfigurator`) that gap would read as a *fully transparent* flash.
/// The opaque color underneath fills the gap, so the sidebar still dims with focus
/// but never flickers through to the desktop. Use this instead of
/// `VisualEffectBackground(style: .calibratedSidebar)` directly.
struct CalibratedSidebarMaterial: View {
    var body: some View {
        Palette.sidebarMaterialFallback
            .overlay(VisualEffectBackground(style: .calibratedSidebar))
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
    /// Cheap value-equatable identity for the (non-Equatable) filter pipeline.
    /// `VisualEffectBackground` rebuilds `contentFilters` only when this changes,
    /// so distinct presets get distinct tokens. Reusing the same preset across
    /// re-renders keeps the same token and therefore never rebuilds the chain.
    let identityToken: AnyHashable

    /// The calibrated sidebar material. Pinned to the `.aqua` (light) appearance
    /// on purpose — the color calibration was tuned for light mode only.
    ///
    /// `state` is `.followsWindowActiveState` so the material dims when the window
    /// loses focus, matching native sidebars. That transition re-resolves the
    /// `.behindWindow` backdrop and leaves a one-frame gap that, over this app's
    /// non-opaque window, would read as a transparent flash — so callers render
    /// this material via `CalibratedSidebarMaterial`, which backs it with an opaque
    /// fallback color that fills the gap.
    static let calibratedSidebar = VisualEffectStyle(
        material: .titlebar,
        blendingMode: .behindWindow,
        state: .followsWindowActiveState,
        appearanceName: .aqua,
        isEmphasized: false,
        contentFilters: SidebarMaterialCalibration.makeFilters,
        identityToken: "calibratedSidebar"
    )
}
