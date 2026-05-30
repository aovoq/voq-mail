import AppKit
import SwiftUI

struct WindowChromeConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

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

    final class Coordinator {
        private weak var configuredWindow: NSWindow?
        private var trafficLightConstraints: [NSLayoutConstraint] = []

        deinit {
            resetTrafficLightConstraints()
        }

        func configure(window: NSWindow?) {
            guard let window else { return }

            window.titleVisibility = .hidden
            window.title = ""
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
            window.contentView?.superview?.wantsLayer = true
            window.contentView?.superview?.layer?.backgroundColor = NSColor.clear.cgColor
            window.toolbar = nil

            window.standardWindowButton(.closeButton)?.isHidden = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window.standardWindowButton(.zoomButton)?.isHidden = false

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

        private func pinTrafficLights(in window: NSWindow) {
            guard trafficLightConstraints.isEmpty else { return }

            let buttons = TrafficLightLayout.buttons.compactMap { type, leading in
                window.standardWindowButton(type).flatMap { button -> (NSButton, CGFloat, NSView)? in
                    guard let superview = button.superview else { return nil }
                    return (button, leading, superview)
                }
            }

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

private enum TrafficLightLayout {
    static let topInset: CGFloat = 16
    static let buttons: [(NSWindow.ButtonType, CGFloat)] = [
        (.closeButton, 16),
        (.miniaturizeButton, 38),
        (.zoomButton, 60),
    ]
}
