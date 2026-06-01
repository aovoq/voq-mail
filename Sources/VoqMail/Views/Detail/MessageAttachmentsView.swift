//
//  MessageAttachmentsView.swift
//  VoqMail
//
//  Attachment rows and their optional Quick Look preview state.
//

import SwiftUI

struct MessageAttachmentsView: View {
    let attachments: [MailAttachment]
    var downloadingIDs: Set<String> = []
    var onPreview: (MailAttachment) -> Void = { _ in }
    @State private var selectedAttachmentID: MailAttachment.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Attachments")
                .font(.headline)

            ForEach(attachments) { attachment in
                VStack(alignment: .leading, spacing: 8) {
                    MessageAttachmentRow(
                        attachment: attachment,
                        isSelected: selectedAttachmentID == attachment.id
                    ) {
                        toggleSelection(for: attachment)
                    }

                    if selectedAttachmentID == attachment.id {
                        AttachmentPreviewSlot(
                            attachment: attachment,
                            isDownloading: downloadingIDs.contains(attachment.id))
                    }
                }
            }
        }
    }

    private func toggleSelection(for attachment: MailAttachment) {
        if selectedAttachmentID == attachment.id {
            selectedAttachmentID = nil
        } else {
            selectedAttachmentID = attachment.id
            // Fetch the bytes the first time the row is opened.
            if attachment.localFileURL == nil {
                onPreview(attachment)
            }
        }
    }
}

private struct MessageAttachmentRow: View {
    let attachment: MailAttachment
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "paperclip")
                    .frame(width: 16)

                Text(attachment.filename)
                    .lineLimit(1)

                Spacer()

                Text(byteCount)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(8)
        .background(.quaternary.opacity(backgroundOpacity), in: RoundedRectangle(cornerRadius: 6))
    }

    private var byteCount: String {
        ByteCountFormatter.string(fromByteCount: Int64(attachment.byteCount), countStyle: .file)
    }

    private var backgroundOpacity: Double {
        isSelected ? 0.65 : 0.35
    }
}

private struct AttachmentPreviewSlot: View {
    let attachment: MailAttachment
    var isDownloading: Bool = false

    var body: some View {
        if let _ = attachment.localFileURL {
            AttachmentPreviewView(attachment: attachment)
                .frame(height: 180)
        } else if isDownloading {
            HStack(spacing: 8) {
                ProgressView()
                Text("Downloading…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("Preview will appear here once the attachment is downloaded.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
