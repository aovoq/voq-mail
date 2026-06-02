//
//  MessageContentStore.swift
//  VoqMail
//
//  Loads the full content of the currently open message: HTML body (with inline
//  cid images embedded) and the list of downloadable attachments. Only one
//  message is open at a time, so this holds a single result keyed by message id.
//
//  Selection can change faster than the network responds, so every step guards
//  on the requested (account, message) matching the latest one — a late A
//  response never overwrites B's content, including when the two accounts hold
//  messages that happen to share a Gmail message id (issue #8).
//

import Foundation
import Observation

/// The loaded body + attachments for one message.
struct MessageContent {
    let html: String
    let attachments: [MailAttachment]
}

@Observable
@MainActor
final class MessageContentStore {
    private(set) var content: MessageContent?
    /// The message id the current `content` (or in-flight load) belongs to.
    private(set) var loadedMessageID: String?
    /// The account id the current `content` belongs to. Gmail message ids are not
    /// unique across accounts, so the loaded key is the (account, message) pair.
    private(set) var loadedAccountID: String?
    private(set) var isLoading = false
    private(set) var downloadingAttachmentIDs: Set<String> = []
    var errorMessage: String?

    private let client = GmailClient()
    private let parser = MimeParser()

    /// Whether the given account's message is the one currently shown/loading.
    func isShowing(accountID: String, messageID: String) -> Bool {
        loadedAccountID == accountID && loadedMessageID == messageID
    }

    /// Clears the content if it belongs to the removed account (issue #8 delete).
    func purge(accountID: String) {
        guard loadedAccountID == accountID else { return }
        content = nil
        loadedMessageID = nil
        loadedAccountID = nil
        isLoading = false
        downloadingAttachmentIDs = []
        errorMessage = nil
    }

    /// Fetches and parses the full message. `message` provides the snippet body
    /// to fall back on while loading or if no text part is found.
    func load(
        message: MailMessage,
        accountID: String,
        token: @escaping @Sendable () async throws -> String
    ) async {
        guard !isShowing(accountID: accountID, messageID: message.id) || content == nil else { return }
        let requestedID = message.id
        let requestedAccountID = accountID
        loadedMessageID = requestedID
        loadedAccountID = requestedAccountID
        content = nil
        errorMessage = nil
        isLoading = true
        defer { if isCurrent(requestedAccountID, requestedID) { isLoading = false } }

        do {
            let accessToken = try await token()
            guard isCurrent(requestedAccountID, requestedID) else { return }

            let full = try await client.fullMessage(id: requestedID, accessToken: accessToken)
            guard isCurrent(requestedAccountID, requestedID) else { return }

            let parsed = parser.parse(full)
            var html = bodyHTML(from: parsed, fallback: message)
            html = try await resolveInlineImages(
                in: html, parsed: parsed, messageID: requestedID, accessToken: accessToken)
            guard isCurrent(requestedAccountID, requestedID) else { return }

            let attachments = parsed.attachments
                .filter { !$0.isInline }
                .map(MailAttachment.init(parsed:))
            content = MessageContent(html: html, attachments: attachments)
        } catch {
            if isCurrent(requestedAccountID, requestedID) { errorMessage = String(describing: error) }
        }
    }

    /// Downloads an attachment to a temp file and propagates `localFileURL` so the
    /// attachment view can show a Quick Look preview.
    func downloadAttachment(
        _ attachment: MailAttachment,
        accountID: String,
        token: @escaping @Sendable () async throws -> String
    ) async {
        guard attachment.localFileURL == nil,
              let attachmentId = attachment.attachmentId,
              let messageID = loadedMessageID,
              loadedAccountID == accountID,
              !downloadingAttachmentIDs.contains(attachment.id) else { return }

        downloadingAttachmentIDs.insert(attachment.id)
        defer { downloadingAttachmentIDs.remove(attachment.id) }

        do {
            let accessToken = try await token()
            let data = try await client.attachmentData(
                messageID: messageID, attachmentId: attachmentId, accessToken: accessToken)
            let url = try Self.writeTempFile(
                data: data, accountID: accountID, messageID: messageID, filename: attachment.filename)

            // Apply only if the same message in the same account is still open.
            guard loadedAccountID == accountID, loadedMessageID == messageID,
                  let current = content else { return }
            let updated = current.attachments.map {
                $0.id == attachment.id ? $0.withLocalFileURL(url) : $0
            }
            content = MessageContent(html: current.html, attachments: updated)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func isCurrent(_ accountID: String, _ messageID: String) -> Bool {
        !Task.isCancelled && loadedAccountID == accountID && loadedMessageID == messageID
    }

    private func bodyHTML(from parsed: MimeParser.Parsed, fallback: MailMessage) -> String {
        if let html = parsed.html, !html.isEmpty { return html }
        if let plain = parsed.plainText, !plain.isEmpty { return Self.wrapPlainText(plain) }
        return fallback.htmlBody
    }

    /// Embeds inline cid images as data URIs so the body renders them with the
    /// web view's JavaScript disabled and no base URL. Prefers bytes already in
    /// `body.data`, falling back to attachments.get for larger parts.
    private func resolveInlineImages(
        in html: String,
        parsed: MimeParser.Parsed,
        messageID: String,
        accessToken: String
    ) async throws -> String {
        guard html.contains("cid:") else { return html }
        var result = html
        for part in parsed.attachments where part.isInline {
            guard let contentId = part.contentId,
                  result.contains("cid:\(contentId)") else { continue }

            let data: Data
            if let inlineData = part.inlineData {
                data = inlineData
            } else if let attachmentId = part.attachmentId {
                data = try await client.attachmentData(
                    messageID: messageID, attachmentId: attachmentId, accessToken: accessToken)
            } else {
                continue
            }

            let dataURI = "data:\(part.mimeType);base64,\(data.base64EncodedString())"
            result = result.replacingOccurrences(of: "cid:\(contentId)", with: dataURI)
        }
        return result
    }

    private static func wrapPlainText(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br>")
        return """
        <html>
        <body style="font: -apple-system-body; color: #1f2328;">
        <p>\(escaped)</p>
        </body>
        </html>
        """
    }

    private static func writeTempFile(
        data: Data, accountID: String, messageID: String, filename: String
    ) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoqMailAttachments", isDirectory: true)
            .appendingPathComponent(accountID, isDirectory: true)
            .appendingPathComponent(messageID, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(filename.isEmpty ? "attachment" : filename)
        try data.write(to: url, options: .atomic)
        return url
    }
}
