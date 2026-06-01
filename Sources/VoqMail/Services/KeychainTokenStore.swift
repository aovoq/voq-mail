//
//  KeychainTokenStore.swift
//  VoqMail
//
//  Stores OAuth refresh tokens in the login Keychain — one generic-password
//  item per account (service = bundle id, account = email). Access tokens are
//  never stored here; they live only in memory (see TokenProvider).
//
//  The set of stored items is also the source of truth for which accounts to
//  restore on launch, so no separate account list is kept elsewhere.
//

import Foundation
import Security

struct KeychainTokenStore {
    /// Scopes our items within the Keychain.
    private let service = Bundle.main.bundleIdentifier ?? "work.aovoq.voqmail"

    /// Saves (or replaces) the refresh token for an account.
    func saveRefreshToken(_ token: String, for email: String) throws {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: email,
        ]
        // Delete-then-add so re-auth overwrites cleanly.
        SecItemDelete(base as CFDictionary)
        var attributes = base
        attributes[kSecValueData as String] = Data(token.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    /// The refresh token for an account, or nil if none is stored.
    func refreshToken(for email: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: email,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.unexpectedStatus(status)
        }
        return String(data: data, encoding: .utf8)
    }

    /// Emails of every account with a stored refresh token.
    func storedAccountEmails() throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            throw KeychainError.unexpectedStatus(status)
        }
        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }

    /// Removes an account's refresh token (used when signing out / re-auth fails).
    func deleteRefreshToken(for email: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: email,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

enum KeychainError: Error {
    case unexpectedStatus(OSStatus)
}
