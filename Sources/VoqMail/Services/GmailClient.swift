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

    /// All labels for the account (used by the labels sidebar in issue #6).
    func labels(accessToken: String) async throws -> [GmailLabel] {
        let data = try await get(URL(string: "\(Self.usersBase)/labels")!, accessToken: accessToken)
        return try JSONDecoder().decode(GmailLabelList.self, from: data).labels ?? []
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

    /// Bounded-concurrency fan-out: keep at most `concurrency` gets in flight,
    /// starting a new one each time one finishes (a sliding window).
    private func metadata(
        for ids: [String], concurrency: Int, accessToken: String
    ) async throws -> [GmailMessage] {
        guard !ids.isEmpty else { return [] }
        return try await withThrowingTaskGroup(of: (Int, GmailMessage).self) { group in
            var results = [GmailMessage?](repeating: nil, count: ids.count)
            var next = 0
            let window = max(1, min(concurrency, ids.count))

            for _ in 0..<window {
                let index = next
                next += 1
                group.addTask { [self] in
                    (index, try await messageMetadata(id: ids[index], accessToken: accessToken))
                }
            }

            while let (index, message) = try await group.next() {
                results[index] = message
                if next < ids.count {
                    let index = next
                    next += 1
                    group.addTask { [self] in
                        (index, try await messageMetadata(id: ids[index], accessToken: accessToken))
                    }
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
