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
    @Environment(MailStore.self) private var mailStore
    @Environment(LabelStore.self) private var labelStore
    @Environment(MessageContentStore.self) private var contentStore

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsMetrics.sectionSpacing) {
            section(
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

                statusBadge
            }

            Spacer(minLength: 12)

            Button("Remove", role: .destructive) { remove(account) }
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    /// Connection state. For now every signed-in account reads as connected;
    /// surfacing "needs re-authentication" on a failed token refresh is a later
    /// slice that adds the detection in AccountStore.
    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(.green)
                .frame(width: 7, height: 7)
            Text("Connected")
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

    // MARK: - Section scaffold

    /// A titled section: a header, an optional caption, then its rows.
    private func section<Content: View>(
        title: String,
        caption: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.weight(.semibold))
                if let caption {
                    Text(caption)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
    }

    // MARK: - Actions

    /// Removes the account (Keychain token + cached access token + signed-in list)
    /// and purges its slice from every per-account store. Mirrors the old sidebar
    /// footer's removal so behavior is unchanged by the move into settings.
    private func remove(_ account: Account) {
        Task {
            await store.removeAccount(account.id)
            labelStore.purge(accountID: account.id)
            mailStore.purge(accountID: account.id)
            contentStore.purge(accountID: account.id)
        }
    }
}
