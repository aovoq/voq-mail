//
//  MimeParser.swift
//  VoqMail
//
//  Walks a Gmail message's payload tree (format=full) and pulls out what the
//  detail pane needs: the HTML body (or plain text to fall back on) and the
//  attachment parts, tagging inline (cid) parts so they can be embedded in the
//  body rather than listed. All MIME knowledge lives here.
//

import Foundation

struct MimeParser {
    struct Parsed {
        var html: String?
        var plainText: String?
        var attachments: [ParsedAttachment] = []
    }

    /// One attachment-like part. `inlineData` is set when the bytes arrived
    /// directly in `body.data`; otherwise `attachmentId` must be fetched.
    struct ParsedAttachment {
        let partId: String?
        let attachmentId: String?
        let filename: String
        let mimeType: String
        let size: Int
        let isInline: Bool
        let contentId: String?
        let inlineData: Data?
    }

    func parse(_ message: GmailMessage) -> Parsed {
        var parsed = Parsed()
        if let payload = message.payload {
            walk(payload, into: &parsed)
        }
        return parsed
    }

    private func walk(_ part: GmailMessage.Payload, into parsed: inout Parsed) {
        // Recurse into container parts first (multipart/*).
        if let parts = part.parts, !parts.isEmpty {
            for child in parts { walk(child, into: &parsed) }
        }

        let mime = part.mimeType?.lowercased() ?? ""
        let headers = Dictionary(
            (part.headers ?? []).map { ($0.name.lowercased(), $0.value) },
            uniquingKeysWith: { first, _ in first })
        let disposition = headers["content-disposition"]?.lowercased() ?? ""
        let contentId = headers["content-id"]
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "<> ")) }
        let filename = part.filename ?? ""
        let isAttachmentLike = !filename.isEmpty || part.body?.attachmentId != nil

        if mime == "text/html", !isAttachmentLike {
            if parsed.html == nil, let data = decodedBody(part) {
                parsed.html = String(decoding: data, as: UTF8.self)
            }
        } else if mime == "text/plain", !isAttachmentLike {
            if parsed.plainText == nil, let data = decodedBody(part) {
                parsed.plainText = String(decoding: data, as: UTF8.self)
            }
        } else if isAttachmentLike {
            let isInline = disposition.contains("inline")
                || (contentId != nil && mime.hasPrefix("image/"))
            parsed.attachments.append(ParsedAttachment(
                partId: part.partId,
                attachmentId: part.body?.attachmentId,
                filename: filename.isEmpty ? (contentId ?? "attachment") : filename,
                mimeType: part.mimeType ?? "application/octet-stream",
                size: part.body?.size ?? 0,
                isInline: isInline,
                contentId: contentId,
                // Keep bytes only for inline parts that carry them directly.
                inlineData: (isInline ? decodedBody(part) : nil)))
        }
    }

    private func decodedBody(_ part: GmailMessage.Payload) -> Data? {
        guard let data = part.body?.data else { return nil }
        return Data(base64URLEncoded: data)
    }
}

extension MailAttachment {
    /// Builds a list-facing attachment from a parsed MIME part.
    init(parsed: MimeParser.ParsedAttachment) {
        self.init(
            id: parsed.attachmentId ?? parsed.partId ?? parsed.filename,
            filename: parsed.filename,
            byteCount: parsed.size,
            contentType: parsed.mimeType,
            localFileURL: nil,
            partId: parsed.partId,
            attachmentId: parsed.attachmentId,
            isInline: parsed.isInline)
    }
}
