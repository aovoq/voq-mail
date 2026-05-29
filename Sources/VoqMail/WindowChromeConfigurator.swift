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
        private var observers: [NSObjectProtocol] = []

        deinit {
            observers.forEach(NotificationCenter.default.removeObserver)
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
                observe(window: window)
                configuredWindow = window
            }

            positionTrafficLights(in: window)
            scheduleTrafficLightPositioning(in: window)
        }

        private func observe(window: NSWindow) {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = [
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didResizeNotification,
                    object: window,
                    queue: .main
                ) { [weak self, weak window] _ in
                    guard let window else { return }
                    self?.scheduleTrafficLightPositioning(in: window)
                },
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didEndLiveResizeNotification,
                    object: window,
                    queue: .main
                ) { [weak self, weak window] _ in
                    guard let window else { return }
                    self?.scheduleTrafficLightPositioning(in: window)
                },
            ]
        }

        private func scheduleTrafficLightPositioning(in window: NSWindow) {
            for delay in [0, 0.1, 0.35] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak window] in
                    guard let window else { return }
                    Self.positionTrafficLights(in: window)
                }
            }
        }

        private func positionTrafficLights(in window: NSWindow) {
            Self.positionTrafficLights(in: window)
        }

        private static func positionTrafficLights(in window: NSWindow) {
            let topInset: CGFloat = 16
            let buttons: [(NSWindow.ButtonType, CGFloat)] = [
                (.closeButton, 16),
                (.miniaturizeButton, 38),
                (.zoomButton, 60),
            ]

            for (type, x) in buttons {
                guard
                    let button = window.standardWindowButton(type),
                    let superview = button.superview
                else {
                    continue
                }

                var frame = button.frame
                frame.origin.x = x
                frame.origin.y = superview.bounds.height - topInset - frame.height
                button.frame = frame
            }
        }
    }
}
