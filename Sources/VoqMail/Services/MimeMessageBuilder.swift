//
//  MimeMessageBuilder.swift
//  VoqMail
//
//  Assembles an outgoing RFC 2822 / MIME message from a `MailDraft` and returns
//  the base64url string Gmail's `users.messages.send` expects in its `raw` field.
//  This is the write-side counterpart to `MimeParser` (which reads the inbound
//  tree); all the MIME-construction knowledge — CRLF line endings, encoded-word
//  headers, multipart boundaries, base64 line-wrapping — lives here so the rest
//  of the app never has to reason about wire formatting.
//
//  Layout produced:
//    - no attachments → multipart/alternative { text/plain, text/html }
//    - with attachments → multipart/mixed { the alternative block, file parts… }
//

import Foundation

struct MimeMessageBuilder {
    /// Builds the full message and returns it base64url-encoded for `raw`.
    func makeRawMessage(_ draft: MailDraft) -> String {
        let message = assemble(draft)
        return Data(message.utf8).base64URLEncodedString()
    }

    // MARK: - Assembly

    private static let crlf = "\r\n"

    private func assemble(_ draft: MailDraft) -> String {
        var headers = topLevelHeaders(draft)

        // The body section carries its own Content-Type/boundary headers; merge
        // them onto the message headers so there's a single header block.
        let alternative = alternativeBlock(draft)

        if draft.attachments.isEmpty {
            headers.append(contentsOf: alternative.headers)
            return join(headers: headers, body: alternative.body)
        }

        // Wrap the alternative block plus each file in a multipart/mixed.
        let boundary = "mixed_\(UUID().uuidString)"
        headers.append("MIME-Version: 1.0")
        headers.append("Content-Type: multipart/mixed; boundary=\"\(boundary)\"")

        var body = ""
        body += "--\(boundary)" + Self.crlf
        body += alternative.headers.joined(separator: Self.crlf) + Self.crlf + Self.crlf
        body += alternative.body + Self.crlf
        for attachment in draft.attachments {
            body += "--\(boundary)" + Self.crlf
            body += attachmentPart(attachment)
            body += Self.crlf
        }
        body += "--\(boundary)--"

        return join(headers: headers, body: body)
    }

    /// From/To/Cc/Bcc/Subject/Date and the reply-threading headers. Note these do
    /// NOT include MIME-Version / Content-Type — those belong to the body section
    /// and are appended by the caller so they end up adjacent to the boundary.
    private func topLevelHeaders(_ draft: MailDraft) -> [String] {
        var headers: [String] = []
        headers.append("From: \(draft.accountID)")
        headers.append("To: \(addressList(draft.to))")
        if !draft.cc.isEmpty {
            headers.append("Cc: \(addressList(draft.cc))")
        }
        if !draft.bcc.isEmpty {
            headers.append("Bcc: \(addressList(draft.bcc))")
        }
        headers.append("Subject: \(encodedHeaderValue(draft.subject))")
        headers.append("Date: \(rfc2822Date(Date()))")
        // Only a reply carries these — they thread it onto the original message.
        if let inReplyTo = draft.inReplyTo {
            headers.append("In-Reply-To: \(inReplyTo)")
        }
        if let references = draft.references {
            headers.append("References: \(references)")
        }
        return headers
    }

    // MARK: - Body parts

    /// The multipart/alternative block: a plain-text and an HTML rendering of the
    /// same body. Returns its own headers separately so it can be either the whole
    /// message body or one part of a multipart/mixed.
    private func alternativeBlock(_ draft: MailDraft) -> (headers: [String], body: String) {
        let boundary = "alt_\(UUID().uuidString)"
        let headers = [
            "MIME-Version: 1.0",
            "Content-Type: multipart/alternative; boundary=\"\(boundary)\"",
        ]

        var body = ""
        body += "--\(boundary)" + Self.crlf
        body += textPart(mimeType: "text/plain", content: draft.body)
        body += Self.crlf
        body += "--\(boundary)" + Self.crlf
        body += textPart(mimeType: "text/html", content: htmlBody(from: draft.body))
        body += Self.crlf
        body += "--\(boundary)--"
        return (headers, body)
    }

    /// One UTF-8 text part, base64-encoded and line-wrapped.
    private func textPart(mimeType: String, content: String) -> String {
        var part = ""
        part += "Content-Type: \(mimeType); charset=\"UTF-8\"" + Self.crlf
        part += "Content-Transfer-Encoding: base64" + Self.crlf
        part += Self.crlf
        part += wrap(Data(content.utf8).base64EncodedString())
        part += Self.crlf
        return part
    }

    /// One attachment part: typed, base64-encoded bytes with a download filename.
    private func attachmentPart(_ attachment: DraftAttachment) -> String {
        var part = ""
        part += "Content-Type: \(attachment.mimeType); name=\"\(attachment.filename)\"" + Self.crlf
        part += "Content-Transfer-Encoding: base64" + Self.crlf
        part += "Content-Disposition: attachment; \(dispositionFilename(attachment.filename))" + Self.crlf
        part += Self.crlf
        part += wrap(attachment.data.base64EncodedString())
        part += Self.crlf
        return part
    }

    // MARK: - Header / encoding helpers

    /// Joins the header block and body with the blank line between them.
    private func join(headers: [String], body: String) -> String {
        headers.joined(separator: Self.crlf) + Self.crlf + Self.crlf + body
    }

    /// Joins recipients into one address-list header value, RFC 2047-encoding any
    /// non-ASCII display name on each entry while leaving the addr-spec untouched.
    private func addressList(_ addresses: [String]) -> String {
        addresses.map(encodedAddress).joined(separator: ", ")
    }

    /// Encodes a single recipient. For a `Display Name <addr>` form, only the
    /// display-name phrase goes through RFC 2047 (the addr-spec must stay raw
    /// ASCII); a bare address is passed through unchanged.
    private func encodedAddress(_ address: String) -> String {
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        guard let open = trimmed.lastIndex(of: "<"),
              trimmed.hasSuffix(">") else {
            // Bare addr-spec (or unparseable) — only encode if it carries non-ASCII.
            return encodedHeaderValue(trimmed)
        }
        let phrase = trimmed[trimmed.startIndex..<open]
            .trimmingCharacters(in: .whitespaces)
        let addrSpec = trimmed[open...]  // includes the angle brackets
        guard !phrase.isEmpty else { return String(addrSpec) }
        // Strip surrounding quotes before encoding; the encoded-word is itself a
        // valid phrase, so re-quoting isn't needed.
        let unquoted = phrase.hasPrefix("\"") && phrase.hasSuffix("\"") && phrase.count >= 2
            ? String(phrase.dropFirst().dropLast())
            : phrase
        return "\(encodedHeaderValue(unquoted)) \(addrSpec)"
    }

    /// RFC 2047 encoded-word for a header value, but only when it contains
    /// non-ASCII (a plain ASCII subject is left readable on the wire).
    private func encodedHeaderValue(_ value: String) -> String {
        guard value.contains(where: { !$0.isASCII }) else { return value }
        return "=?UTF-8?B?\(Data(value.utf8).base64EncodedString())?="
    }

    /// `filename="…"` for ASCII names; RFC 2231 `filename*=UTF-8''…` (percent-
    /// encoded) when the name carries non-ASCII so it survives the header.
    private func dispositionFilename(_ filename: String) -> String {
        if filename.allSatisfy({ $0.isASCII }) {
            return "filename=\"\(filename)\""
        }
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~")
        let encoded = filename.addingPercentEncoding(withAllowedCharacters: allowed) ?? filename
        return "filename*=UTF-8''\(encoded)"
    }

    /// RFC 2822 Date header, fixed locale so weekday/month stay English.
    private func rfc2822Date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.string(from: date)
    }

    /// Renders the plain-text body as minimal HTML: escaped, newlines → <br>.
    private func htmlBody(from text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n", with: "<br>")
        return "<html><body>\(escaped)</body></html>"
    }

    /// Folds a base64 string to 76-char lines (RFC 2045) joined with CRLF.
    private func wrap(_ base64: String) -> String {
        let chars = Array(base64)
        guard chars.count > 76 else { return base64 }
        var lines: [String] = []
        var index = 0
        while index < chars.count {
            let end = min(index + 76, chars.count)
            lines.append(String(chars[index..<end]))
            index = end
        }
        return lines.joined(separator: Self.crlf)
    }
}
