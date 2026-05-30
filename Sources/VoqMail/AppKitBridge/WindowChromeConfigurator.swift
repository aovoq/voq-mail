//
//  WindowChromeConfigurator.swift
//  VoqMail
//
//  An AppKit bridge that customizes the host `NSWindow`: it hides the title bar,
//  makes the background transparent so the app's own chrome shows through, and
//  pins the traffic-light buttons (close / minimize / zoom) to fixed positions.
//
//  Used by ContentView as a transparent `.background`, purely for its side effect
//  of reaching the window. It draws nothing itself.
//

import AppKit
import SwiftUI

struct WindowChromeConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // The window isn't attached yet while `makeNSView` runs, so we hop to the next
    // main-loop tick (`DispatchQueue.main.async`) by which time `view.window` exists.
    // `configure` is idempotent, so re-running it on every SwiftUI update is safe.
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.configure(window: view.window)
        }
    }

    // MARK: - Coordinator

    /// Holds state that must survive across SwiftUI updates: which window we have
    /// already configured, and the traffic-light constraints we installed.
    final class Coordinator {
        private weak var configuredWindow: NSWindow?
        private var trafficLightConstraints: [NSLayoutConstraint] = []

        deinit {
            resetTrafficLightConstraints()
        }

        /// Applies the chrome. Safe to call repeatedly — the window properties are
        /// simply re-set, and the traffic lights are only re-pinned when needed.
        func configure(window: NSWindow?) {
            guard let window else { return }

            window.titleVisibility = .hidden
            window.title = ""
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.isOpaque = false
            window.backgroundColor = .clear
            // Both the content view and the theme frame above it need a transparent
            // layer; otherwise an opaque system background can show through.
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
            window.contentView?.superview?.wantsLayer = true
            window.contentView?.superview?.layer?.backgroundColor = NSColor.clear.cgColor
            window.toolbar = nil

            window.standardWindowButton(.closeButton)?.isHidden = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window.standardWindowButton(.zoomButton)?.isHidden = false

            // If the window changed (e.g. a new window), drop the old constraints so
            // they get re-created for the new one.
            if configuredWindow !== window {
                resetTrafficLightConstraints()
                configuredWindow = window
            }

            pinTrafficLights(in: window)
        }

        private func resetTrafficLightConstraints() {
            NSLayoutConstraint.deactivate(trafficLightConstraints)
            trafficLightConstraints = []
        }

        /// Pins the three traffic-light buttons to their custom positions.
        /// The `isEmpty` guard makes this run only once per window, so repeated
        /// updates don't stack duplicate constraints.
        private func pinTrafficLights(in window: NSWindow) {
            guard trafficLightConstraints.isEmpty else { return }

            let buttons = TrafficLightLayout.buttons.compactMap { type, leading in
                window.standardWindowButton(type).flatMap { button -> (NSButton, CGFloat, NSView)? in
                    guard let superview = button.superview else { return nil }
                    return (button, leading, superview)
                }
            }

            // Only proceed once every expected button is present.
            guard buttons.count == TrafficLightLayout.buttons.count else { return }

            for (button, leading, superview) in buttons {
                button.translatesAutoresizingMaskIntoConstraints = false
                trafficLightConstraints.append(contentsOf: [
                    button.leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: leading),
                    button.topAnchor.constraint(equalTo: superview.topAnchor, constant: TrafficLightLayout.topInset),
                ])
            }

            NSLayoutConstraint.activate(trafficLightConstraints)
            window.contentView?.superview?.layoutSubtreeIfNeeded()
        }
    }
}

// MARK: - Traffic-light layout

/// Where the standard window buttons sit, measured from the top-left of the
/// title-bar area. These are visually calibrated to the app's custom chrome; the
/// sidebar toggle button (`Metrics.toggleButtonLeadingPadding`) is positioned to
/// clear them.
private enum TrafficLightLayout {
    static let topInset: CGFloat = 16
    static let buttons: [(NSWindow.ButtonType, CGFloat)] = [
        (.closeButton, 16),
        (.miniaturizeButton, 38),
        (.zoomButton, 60),
    ]
}
