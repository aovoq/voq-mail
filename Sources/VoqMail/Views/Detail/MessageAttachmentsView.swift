//
//  MessageAttachmentsView.swift
//  VoqMail
//
//  Attachment rows and their optional Quick Look preview state.
//

import SwiftUI

struct MessageAttachmentsView: View {
    let attachments: [MailAttachment]
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
                        AttachmentPreviewSlot(attachment: attachment)
                    }
                }
            }
        }
    }

    private func toggleSelection(for attachment: MailAttachment) {
        selectedAttachmentID = selectedAttachmentID == attachment.id ? nil : attachment.id
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

    var body: some View {
        if attachment.localFileURL == nil {
            Text("Preview will appear here once the attachment is downloaded.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            AttachmentPreviewView(attachment: attachment)
                .frame(height: 180)
        }
    }
}
