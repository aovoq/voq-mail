//
//  AccountStatusView.swift
//  VoqMail
//
//  Sidebar footer: shows the signed-in account address(es) and an "Add Account"
//  button that launches the OAuth flow. Minimal for issue #3 — issue #8 grows
//  this into per-account grouping.
//

import SwiftUI

struct AccountStatusView: View {
    @Environment(AccountStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .padding(.horizontal, 10)

            if store.accounts.isEmpty {
                Text("No account")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            } else {
                ForEach(store.accounts) { account in
                    Label(account.email, systemImage: "person.crop.circle")
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 12)
                }
            }

            Button {
                Task { await store.addAccount() }
            } label: {
                Label(
                    store.isAuthenticating ? "Signing in…" : "Add Account",
                    systemImage: "plus.circle")
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .disabled(store.isAuthenticating)
            .padding(.horizontal, 12)

            if let error = store.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
