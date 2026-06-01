//
//  MailAttachment.swift
//  VoqMail
//
//  Metadata for a message attachment. The app can render a Quick Look preview
//  when `localFileURL` points to a downloaded file. The Gmail-specific fields
//  (partId / attachmentId / isInline) identify the MIME part so the bytes can be
//  fetched on demand via users.messages.attachments.get.
//

import Foundation

struct MailAttachment: Codable, Identifiable, Hashable {
    let id: String
    let filename: String
    let byteCount: Int
    let contentType: String
    let localFileURL: URL?
    /// MIME part id within the message payload.
    let partId: String?
    /// Gmail attachment id used to fetch the body; nil for inline `body.data` parts.
    let attachmentId: String?
    /// True for parts referenced inline by the HTML body (cid images).
    let isInline: Bool

    init(
        id: String,
        filename: String,
        byteCount: Int,
        contentType: String,
        localFileURL: URL? = nil,
        partId: String? = nil,
        attachmentId: String? = nil,
        isInline: Bool = false
    ) {
        self.id = id
        self.filename = filename
        self.byteCount = byteCount
        self.contentType = contentType
        self.localFileURL = localFileURL
        self.partId = partId
        self.attachmentId = attachmentId
        self.isInline = isInline
    }

    /// A copy with the downloaded file location filled in (for Quick Look).
    func withLocalFileURL(_ url: URL) -> MailAttachment {
        MailAttachment(
            id: id,
            filename: filename,
            byteCount: byteCount,
            contentType: contentType,
            localFileURL: url,
            partId: partId,
            attachmentId: attachmentId,
            isInline: isInline)
    }
}
