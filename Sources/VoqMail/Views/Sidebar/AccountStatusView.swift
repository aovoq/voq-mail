//
//  AccountStatusView.swift
//  VoqMail
//
//  Sidebar footer: an entry into the settings panel, plus an at-a-glance count of
//  signed-in accounts. Adding, removing, and (later) re-authenticating accounts
//  now all live in Settings → Accounts; this footer only opens that panel, so the
//  sidebar stays focused on mailboxes.
//

import SwiftUI

struct AccountStatusView: View {
    @Environment(AccountStore.self) private var store
    @Environment(AppNavigation.self) private var navigation

    private var accountSummary: String {
        switch store.accounts.count {
        case 0: return "No accounts"
        case 1: return "1 account"
        case let n: return "\(n) accounts"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 10)

            Button {
                navigation.showSettings(.accounts)
            } label: {
                HStack(spacing: Metrics.sidebarRowContentSpacing) {
                    Image(systemName: "gearshape")
                        .frame(width: Metrics.sidebarRowIconWidth)
                        .foregroundStyle(navigation.isShowingSettings ? .primary : .secondary)

                    Text("Settings")
                        .font(.body)

                    Spacer(minLength: 6)

                    Text(accountSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, Metrics.sidebarRowContentSpacing)
                .frame(maxWidth: .infinity, minHeight: Metrics.sidebarRowHeight, alignment: .leading)
                .sidebarRowSelection(isSelected: navigation.isShowingSettings)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)
        }
    }
}
