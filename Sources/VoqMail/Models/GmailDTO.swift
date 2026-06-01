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

/// `users.messages.get` response (format=metadata).
struct GmailMessage: Decodable {
    let id: String
    let threadId: String
    let labelIds: [String]?
    let snippet: String?
    /// Milliseconds since the epoch, as a string (Gmail's internal receipt time).
    let internalDate: String?
    let payload: Payload?

    struct Payload: Decodable {
        let headers: [Header]?
    }

    struct Header: Decodable {
        let name: String
        let value: String
    }
}

/// `users.labels.list` response.
struct GmailLabelList: Decodable {
    let labels: [GmailLabel]?
}

struct GmailLabel: Decodable {
    let id: String
    let name: String
    let type: String?
}

extension MailMessage {
    /// Maps a fetched Gmail message into a list-row `MailMessage`. Body and
    /// attachments are not fetched in this slice (issue #5); the preview uses the
    /// API snippet and the HTML body defaults to a plain-text rendering of it.
    init(gmail: GmailMessage, mailboxID: String) {
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
            isRead: !(gmail.labelIds?.contains("UNREAD") ?? false),
            attachments: [],
            mailboxID: mailboxID
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
