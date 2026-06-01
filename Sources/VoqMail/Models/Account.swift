//
//  Account.swift
//  VoqMail
//
//  A signed-in Gmail account. Deliberately minimal for the first auth slice
//  (issue #3); it grows as multi-account and per-label features land.
//

import Foundation

/// A signed-in Gmail account.
struct Account: Identifiable, Hashable {
    /// Stable identifier — the account's email address. Also the Keychain key
    /// under which the account's refresh token is stored.
    var id: String { email }
    /// The account's Gmail address, as returned by `users.getProfile`.
    let email: String
    /// Human-friendly name, if known. Unused for now; reserved for later slices.
    let displayName: String?
}
