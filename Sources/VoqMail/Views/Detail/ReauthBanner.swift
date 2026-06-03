//
//  ReauthBanner.swift
//  VoqMail
//
//  A strip above the detail pane warning that an account's session has expired and
//  offering a one-tap re-login. It is the always-visible half of issue #11's "no
//  silent failure" guarantee — Settings → Accounts carries the same prompt, but the
//  banner means the user sees it without going looking. One row per lapsed account,
//  so one account's expiry is called out without implying the others are broken.
//

import SwiftUI

struct ReauthBanner: View {
    @Environment(AccountStore.self) private var store

    var body: some View {
        // Renders nothing (zero height) when no account needs re-authentication.
        if !store.accountsNeedingReauth.isEmpty {
            VStack(spacing: 0) {
                ForEach(store.accountsNeedingReauth.sorted(), id: \.self) { email in
                    row(email)
                }
            }
            .background(.orange.opacity(0.12))
            .overlay(alignment: .bottom) { Divider() }
        }
    }

    private func row(_ email: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(email) needs to sign in again")
                    .font(.callout.weight(.medium))
                Text("Its session expired. Re-authenticate to keep sending and receiving mail.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button("Re-authenticate") {
                Task { await store.reauthenticate(email) }
            }
            .disabled(store.isAuthenticating)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}
