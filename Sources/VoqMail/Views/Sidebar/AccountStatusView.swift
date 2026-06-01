//
//  AccountStatusView.swift
//  VoqMail
//
//  Sidebar footer: lists the signed-in accounts (each removable via a context
//  menu) and an "Add Account" button that launches the OAuth flow. Removing an
//  account deletes its Keychain token and purges its per-account store state
//  (issue #8).
//

import SwiftUI

struct AccountStatusView: View {
    @Environment(AccountStore.self) private var store
    @Environment(MailStore.self) private var mailStore
    @Environment(LabelStore.self) private var labelStore
    @Environment(MessageContentStore.self) private var contentStore

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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("Remove Account", role: .destructive) {
                                remove(account)
                            }
                        }
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

    /// Removes the account (Keychain token + cached access token + signed-in list)
    /// and purges its slice from every per-account store. The store lives at app
    /// level so its content can be purged here. Selection self-heals via
    /// MailSplitView's `onChange(of: allMailboxes)`.
    private func remove(_ account: Account) {
        Task {
            await store.removeAccount(account.id)
            labelStore.purge(accountID: account.id)
            mailStore.purge(accountID: account.id)
            contentStore.purge(accountID: account.id)
        }
    }
}
