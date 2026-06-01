//
//  GmailDTO.swift
//  VoqMail
//
//  Decodable mirrors of the Gmail REST JSON we consume, plus the mapping from a
//  fetched message to the app's `MailMessage`. Kept apart from the networking so
//  the wire shapes and the parsing rules live in one place.
//

import Foundation

/// `users.messages.list` response — only ids/threadIds, hence the follow-up get.
struct GmailMessageList: Decodable {
    let messages: [Ref]?
    let nextPageToken: String?

    struct Ref: Decodable {
        let id: String
        let threadId: String
    }
}

/// `users.messages.get` response. The payload is fully recursive so the same
/// type decodes both `format=metadata` (headers only) and `format=full` (the
/// MIME tree with bodies); every full-only field is optional for compatibility.
struct GmailMessage: Decodable {
    let id: String
    let threadId: String
    let labelIds: [String]?
    let snippet: String?
    /// Milliseconds since the epoch, as a string (Gmail's internal receipt time).
    let internalDate: String?
    let payload: Payload?

    struct Payload: Decodable {
        let partId: String?
        let mimeType: String?
        let filename: String?
        let headers: [Header]?
        let body: Body?
        let parts: [Payload]?
    }

    struct Body: Decodable {
        let attachmentId: String?
        let size: Int?
        /// base64url-encoded part bytes (present for inline/small parts).
        let data: String?
    }

    struct Header: Decodable {
        let name: String
        let value: String
    }
}

extension Data {
    /// Decodes base64url (RFC 4648 §5), tolerating missing padding. Gmail returns
    /// part and attachment bytes in this encoding.
    init?(base64URLEncoded string: String) {
        var s = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s.append("=") }
        self.init(base64Encoded: s, options: [.ignoreUnknownCharacters])
    }
}

/// `users.labels.list` response.
struct GmailLabelList: Decodable {
    let labels: [GmailLabel]?
}

/// A Gmail label. `users.labels.list` populates only id/name/type; the unread and
/// total counts are filled in only by `users.labels.get` (issue #6 fetches those
/// per displayed label), so the count fields are optional. Note Gmail counts both
/// messages and threads: its own UI badges show the *thread* (conversation) count.
struct GmailLabel: Decodable {
    let id: String
    let name: String
    let type: String?
    let messagesUnread: Int?
    let messagesTotal: Int?
    let threadsUnread: Int?
    let threadsTotal: Int?
}

extension MailMessage {
    /// Maps a fetched Gmail message into a list-row `MailMessage`. Body and
    /// attachments are not fetched in this slice (issue #5); the preview uses the
    /// API snippet and the HTML body defaults to a plain-text rendering of it.
    /// `accountID` tags the message with the account it was fetched from.
    init(gmail: GmailMessage, accountID: String, mailboxID: String) {
        let headers = Dictionary(
            (gmail.payload?.headers ?? []).map { ($0.name.lowercased(), $0.value) },
            uniquingKeysWith: { first, _ in first })

        let (name, address) = Self.parseAddress(headers["from"] ?? "")
        let recipients = (headers["to"] ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        self.init(
            id: gmail.id,
            sender: name,
            senderAddress: address,
            recipients: recipients,
            subject: headers["subject"] ?? "(no subject)",
            preview: gmail.snippet ?? "",
            htmlBody: nil,
            receivedAt: Self.date(fromInternalDate: gmail.internalDate),
            labelIds: gmail.labelIds ?? [],
            attachments: [],
            mailboxID: mailboxID,
            accountID: accountID
        )
    }

    /// Splits an address header value into a display name and bare address.
    /// Handles `Name <addr>`, a bare `addr`, and quoted display names.
    static func parseAddress(_ value: String) -> (name: String, address: String) {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if let open = trimmed.lastIndex(of: "<"),
           let close = trimmed.lastIndex(of: ">"),
           open < close {
            let address = trimmed[trimmed.index(after: open)..<close]
                .trimmingCharacters(in: .whitespaces)
            let name = trimmed[..<open]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            return (name.isEmpty ? address : name, address)
        }
        return (trimmed, trimmed)
    }

    /// Converts Gmail's millisecond `internalDate` string to a `Date`.
    static func date(fromInternalDate internalDate: String?) -> Date {
        guard let internalDate, let ms = Double(internalDate) else { return Date() }
        return Date(timeIntervalSince1970: ms / 1000)
    }
}
