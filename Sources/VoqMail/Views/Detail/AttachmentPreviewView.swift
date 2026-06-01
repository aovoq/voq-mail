//
//  Quick Look bridge for downloaded attachment files.
//
//  AttachmentPreviewView.swift
//  VoqMail
//

import QuickLookUI
import SwiftUI

struct AttachmentPreviewView: NSViewRepresentable {
    let attachment: MailAttachment

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
        view.autostarts = true
        return view
    }

    func updateNSView(_ view: QLPreviewView, context: Context) {
        guard let localFileURL = attachment.localFileURL else {
            view.previewItem = nil
            return
        }
        view.previewItem = PreviewItem(url: localFileURL, title: attachment.filename)
    }
}

private final class PreviewItem: NSObject, QLPreviewItem {
    let previewItemURL: URL?
    let previewItemTitle: String?

    init(url: URL, title: String) {
        previewItemURL = url
        previewItemTitle = title
    }
}
