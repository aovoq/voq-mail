//
//  HTMLPlainTextExtractor.swift
//  VoqMail
//
//  A stateless HTML → plain-text transform. Stands alone (no mail/codex types)
//  so the reply-assist feature can layer its `MailMessage.plainTextBody`
//  convenience on top, and so the AppKit/WebKit dependency this needs stays out
//  of the Models layer.
//
//  Uses macOS's native HTML reader (`NSAttributedString`), which properly drops
//  `<style>`/`<script>` blocks, comments and markup, decodes entities, and
//  flattens structure — far better than a regex strip for real-world marketing
//  HTML. That reader builds on WebKit and **must run on the main thread**; off
//  the main thread (or on parse failure) it falls back to a regex strip.
//

import AppKit
import Foundation

enum HTMLPlainText {
    /// Cap on the extracted text so a long thread can't bloat a downstream prompt.
    static let cap = 6000

    /// Extracts plain text from `html`: the native reader on the main thread,
    /// the regex fallback otherwise (or on parse failure), then capped and
    /// trimmed. Returns an empty string when the body yields nothing — the caller
    /// decides on a fallback (e.g. a message preview).
    static func extract(fromHTML html: String) -> String {
        let extracted: String
        if Thread.isMainThread, let native = native(fromHTML: html) {
            extracted = native
        } else {
            extracted = regex(fromHTML: html)
        }
        let capped = String(extracted.prefix(cap))
        return capped.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// macOS-native HTML → text. Returns nil if the data can't be built or the
    /// reader fails, so the caller can fall back. Must be called on the main
    /// thread (the caller guards with `Thread.isMainThread`).
    private static func native(fromHTML html: String) -> String? {
        guard let data = html.data(using: .utf8) else { return nil }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]
        guard let attributed = try? NSAttributedString(
            data: data, options: options, documentAttributes: nil) else { return nil }
        return attributed.string
            // Drop the object-replacement char the reader leaves for <img>/attachments.
            .replacingOccurrences(of: "\u{FFFC}", with: "")
            // Collapse the runs of blank lines the HTML reader tends to leave.
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
    }

    /// Lightweight regex fallback for the off-main / parse-failure path.
    private static func regex(fromHTML html: String) -> String {
        var text = html
        for tag in ["<br>", "<br/>", "<br />", "</p>", "</div>", "</tr>", "</li>"] {
            text = text.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }
        // Drop style/script blocks (content and all) before stripping tags.
        text = text.replacingOccurrences(
            of: "<(style|script)[^>]*>[\\s\\S]*?</\\1>", with: "", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">",
                        "&quot;": "\"", "&#39;": "'", "&apos;": "'"]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        text = text.replacingOccurrences(of: "[ \\t]+\\n", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
