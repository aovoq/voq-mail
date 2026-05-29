import AppKit
import SwiftUI

struct ContentView: View {
    var body: some View {
        CustomSplitDemo()
        .background(WindowChromeConfigurator())
        .ignoresSafeArea(.container, edges: .top)
    }
}

#Preview {
    ContentView()
}

struct WindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: view.window)
        }
    }

    private func configure(window: NSWindow?) {
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

        positionTrafficLights(in: window)
        DispatchQueue.main.async {
            positionTrafficLights(in: window)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            positionTrafficLights(in: window)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            positionTrafficLights(in: window)
        }
    }

    private func positionTrafficLights(in window: NSWindow) {
        let topInset: CGFloat = 16
        let buttons: [(NSWindow.ButtonType, CGFloat)] = [
            (.closeButton, 15),
            (.miniaturizeButton, 35),
            (.zoomButton, 55)
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
