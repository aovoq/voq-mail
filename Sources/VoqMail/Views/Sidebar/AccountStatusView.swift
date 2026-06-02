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
                HStack(spacing: 10) {
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
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: Metrics.sidebarRowHeight, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: Metrics.sidebarRowCornerRadius)
                        .fill(navigation.isShowingSettings
                              ? Color(nsColor: .selectedContentBackgroundColor).opacity(Palette.sidebarRowSelectionOpacity)
                              : .clear)
                }
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)
        }
    }
}
