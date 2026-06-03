//
//  AccountsSettingsView.swift
//  VoqMail
//
//  The Accounts tab: the signed-in Gmail accounts, each with a status badge and a
//  Remove action, plus Add Account. This is now the single place accounts are
//  managed (the sidebar footer just opens settings). Removing an account deletes
//  its Keychain token and purges its slice from every per-account store (issue #8),
//  matching what the old sidebar footer did.
//

import SwiftUI

struct AccountsSettingsView: View {
    @Environment(AccountStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsMetrics.sectionSpacing) {
            SettingsSection(
                title: "Accounts",
                caption: "Gmail accounts signed in to voq-mail."
            ) {
                if store.accounts.isEmpty {
                    emptyState
                } else {
                    accountsCard
                }

                addAccountButton

                if let error = store.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Accounts list

    private var accountsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(store.accounts.enumerated()), id: \.element.id) { index, account in
                if index > 0 {
                    Divider().padding(.leading, 52)
                }
                accountRow(account)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: SettingsMetrics.cardCornerRadius)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: SettingsMetrics.cardCornerRadius)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }

    private func accountRow(_ account: Account) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.email)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                statusBadge(for: account)
            }

            Spacer(minLength: 12)

            // A lapsed account gets a re-login action right beside its badge so the
            // fix is one click from where the problem is shown (issue #11).
            if store.needsReauthentication(account.id) {
                Button("Re-authenticate") { reauthenticate(account) }
                    .buttonStyle(.borderless)
                    .disabled(store.isAuthenticating)
            }

            Button("Remove", role: .destructive) { remove(account) }
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    /// Connection state: amber "needs re-authentication" once a token refresh has
    /// been rejected (issue #11), green "connected" otherwise.
    @ViewBuilder
    private func statusBadge(for account: Account) -> some View {
        if store.needsReauthentication(account.id) {
            badge(color: .orange, text: "Needs re-authentication")
        } else {
            badge(color: .green, text: "Connected")
        }
    }

    private func badge(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        Text("No accounts yet.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }

    private var addAccountButton: some View {
        Button {
            Task { await store.addAccount() }
        } label: {
            Label(
                store.isAuthenticating ? "Signing in…" : "Add Account",
                systemImage: "plus")
        }
        .disabled(store.isAuthenticating)
    }

    // MARK: - Actions

    /// Removes the account. The per-account store slices are purged by
    /// `AccountStore`'s `onAccountRemoved` hook (wired in ContentView), so this
    /// view no longer reaches into the other stores itself.
    private func remove(_ account: Account) {
        Task { await store.removeAccount(account.id) }
    }

    /// Re-runs the consent flow for a lapsed account, pinned to its address.
    private func reauthenticate(_ account: Account) {
        Task { await store.reauthenticate(account.id) }
    }
}
