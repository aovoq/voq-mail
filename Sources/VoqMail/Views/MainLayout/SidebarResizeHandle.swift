//
//  SidebarResizeHandle.swift
//  VoqMail
//
//  AppKit-backed resize target for the custom curved sidebar seam. The seam
//  stroke stays visual-only; this view owns the reliable hit area, drag events,
//  and native cursor rect.
//

import AppKit
import SwiftUI

struct SidebarResizeHandle: NSViewRepresentable {
    let seamX: CGFloat
    let hitWidth: CGFloat
    let isEnabled: Bool
    let onResize: (CGFloat) -> Void

    func makeNSView(context: Context) -> ResizeHandleView {
        ResizeHandleView()
    }

    func updateNSView(_ view: ResizeHandleView, context: Context) {
        let didChangeEnabled = view.isEnabled != isEnabled

        view.seamX = seamX
        view.hitWidth = hitWidth
        view.isEnabled = isEnabled
        view.onResize = onResize

        if didChangeEnabled {
            view.invalidateResizeCursorRects()
        }
    }
}

final class ResizeHandleView: NSView {
    var seamX: CGFloat = 0
    var hitWidth: CGFloat = 0
    var isEnabled = false
    var onResize: (CGFloat) -> Void = { _ in }

    private var dragStartX: CGFloat?
    private var dragStartWidth: CGFloat = 0

    override var mouseDownCanMoveWindow: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        invalidateResizeCursorRects()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        invalidateResizeCursorRects()
    }

    override func resetCursorRects() {
        super.resetCursorRects()

        guard isEnabled else { return }
        addCursorRect(handleRect, cursor: .resizeLeftRight)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isEnabled, handleRect.contains(point) else { return nil }
        return self
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        dragStartX = event.locationInWindow.x
        dragStartWidth = seamX
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStartX else { return }
        onResize(dragStartWidth + event.locationInWindow.x - dragStartX)
    }

    override func mouseUp(with event: NSEvent) {
        dragStartX = nil
    }

    private var handleRect: CGRect {
        CGRect(
            x: seamX - hitWidth / 2,
            y: bounds.minY,
            width: hitWidth,
            height: bounds.height
        )
    }

    func invalidateResizeCursorRects() {
        window?.invalidateCursorRects(for: self)
    }
}
