//
//  GmailProfileService.swift
//  VoqMail
//
//  Reads the signed-in user's Gmail profile. For now only the email address is
//  needed (to label the account and key its Keychain item).
//

import Foundation

struct GmailProfileService {
    private static let profileEndpoint =
        URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/profile")!

    var session: URLSession = .shared

    /// The account's email address, via `users.getProfile`. Normalized
    /// (trimmed + lowercased) so it is identical every time it is fetched: the
    /// address is both the account id and its Keychain key, so a stable value is
    /// what lets account removal delete by id and hit the right Keychain item.
    func emailAddress(accessToken: String) async throws -> String {
        var request = URLRequest(url: Self.profileEndpoint)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw OAuthError.profileFetchFailed(
                status: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let address = try JSONDecoder().decode(Profile.self, from: data).emailAddress
        return address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private struct Profile: Decodable {
        let emailAddress: String
    }
}
