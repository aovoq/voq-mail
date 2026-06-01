//
//  GmailClient.swift
//  VoqMail
//
//  Thin Gmail REST client over URLSession (no Google SDK). Stateless: every call
//  takes a bearer access token. `messages.list` returns only ids, so list rows
//  need a per-message `messages.get`; that N+1 is run through a bounded-
//  concurrency window (not the batch endpoint) to stay within per-user limits.
//

import Foundation

struct GmailClient {
    var session: URLSession = .shared

    private static let usersBase = "https://gmail.googleapis.com/gmail/v1/users/me"

    /// Ids of the newest messages carrying the given label.
    func listMessageIDs(
        labelID: String, maxResults: Int, accessToken: String
    ) async throws -> [String] {
        var components = URLComponents(string: "\(Self.usersBase)/messages")!
        components.queryItems = [
            .init(name: "labelIds", value: labelID),
            .init(name: "maxResults", value: String(maxResults)),
        ]
        let data = try await get(components.url!, accessToken: accessToken)
        return try JSONDecoder().decode(GmailMessageList.self, from: data).messages?
            .map(\.id) ?? []
    }

    /// Metadata for one message (From/To/Subject/Date headers + snippet + labels).
    func messageMetadata(id: String, accessToken: String) async throws -> GmailMessage {
        var components = URLComponents(string: "\(Self.usersBase)/messages/\(id)")!
        components.queryItems = [
            .init(name: "format", value: "metadata"),
            .init(name: "metadataHeaders", value: "From"),
            .init(name: "metadataHeaders", value: "To"),
            .init(name: "metadataHeaders", value: "Subject"),
            .init(name: "metadataHeaders", value: "Date"),
        ]
        let data = try await get(components.url!, accessToken: accessToken)
        return try JSONDecoder().decode(GmailMessage.self, from: data)
    }

    /// The full message (MIME tree with bodies) for rendering body + attachments.
    func fullMessage(id: String, accessToken: String) async throws -> GmailMessage {
        var components = URLComponents(string: "\(Self.usersBase)/messages/\(id)")!
        components.queryItems = [.init(name: "format", value: "full")]
        let data = try await get(components.url!, accessToken: accessToken)
        return try JSONDecoder().decode(GmailMessage.self, from: data)
    }

    /// Raw bytes of one attachment, base64url-decoded.
    func attachmentData(
        messageID: String, attachmentId: String, accessToken: String
    ) async throws -> Data {
        let url = URL(string: "\(Self.usersBase)/messages/\(messageID)/attachments/\(attachmentId)")!
        let data = try await get(url, accessToken: accessToken)
        let body = try JSONDecoder().decode(AttachmentBody.self, from: data)
        guard let decoded = Data(base64URLEncoded: body.data) else {
            throw GmailError.requestFailed(status: -1, body: "attachment decode failed")
        }
        return decoded
    }

    /// All labels for the account, ids/names only (the list endpoint omits counts).
    func labels(accessToken: String) async throws -> [GmailLabel] {
        let data = try await get(URL(string: "\(Self.usersBase)/labels")!, accessToken: accessToken)
        return try JSONDecoder().decode(GmailLabelList.self, from: data).labels ?? []
    }

    /// One label with its unread/total counts populated (the list endpoint leaves
    /// them empty, so the sidebar badges need this per-label get).
    func label(id: String, accessToken: String) async throws -> GmailLabel {
        let data = try await get(URL(string: "\(Self.usersBase)/labels/\(id)")!, accessToken: accessToken)
        return try JSONDecoder().decode(GmailLabel.self, from: data)
    }

    /// Fetches each label's counts, capped at `concurrency` in-flight gets. Results
    /// preserve the input order.
    func labels(
        ids: [String], concurrency: Int, accessToken: String
    ) async throws -> [GmailLabel] {
        try await concurrentMap(ids, concurrency: concurrency) { id in
            try await label(id: id, accessToken: accessToken)
        }
    }

    private struct AttachmentBody: Decodable {
        let data: String
        let size: Int?
    }

    /// Lists a label's newest messages and fetches each one's metadata, capped at
    /// `concurrency` in-flight requests. Results preserve the list order.
    func messages(
        labelID: String, maxResults: Int, concurrency: Int, accessToken: String
    ) async throws -> [GmailMessage] {
        let ids = try await listMessageIDs(
            labelID: labelID, maxResults: maxResults, accessToken: accessToken)
        return try await metadata(for: ids, concurrency: concurrency, accessToken: accessToken)
    }

    private func metadata(
        for ids: [String], concurrency: Int, accessToken: String
    ) async throws -> [GmailMessage] {
        try await concurrentMap(ids, concurrency: concurrency) { id in
            try await messageMetadata(id: id, accessToken: accessToken)
        }
    }

    /// Bounded-concurrency fan-out: maps `inputs` through `transform` keeping at
    /// most `concurrency` calls in flight, starting a new one each time one
    /// finishes (a sliding window). Results preserve the input order.
    private func concurrentMap<Input: Sendable, Output: Sendable>(
        _ inputs: [Input], concurrency: Int,
        _ transform: @escaping @Sendable (Input) async throws -> Output
    ) async throws -> [Output] {
        guard !inputs.isEmpty else { return [] }
        return try await withThrowingTaskGroup(of: (Int, Output).self) { group in
            var results = [Output?](repeating: nil, count: inputs.count)
            var next = 0
            let window = max(1, min(concurrency, inputs.count))

            for _ in 0..<window {
                let index = next
                next += 1
                group.addTask { (index, try await transform(inputs[index])) }
            }

            while let (index, value) = try await group.next() {
                results[index] = value
                if next < inputs.count {
                    let index = next
                    next += 1
                    group.addTask { (index, try await transform(inputs[index])) }
                }
            }
            return results.compactMap { $0 }
        }
    }

    private func get(_ url: URL, accessToken: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw GmailError.requestFailed(
                status: (response as? HTTPURLResponse)?.statusCode ?? -1,
                body: String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }
}

enum GmailError: Error {
    case requestFailed(status: Int, body: String)
}
