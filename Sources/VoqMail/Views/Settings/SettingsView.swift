//
//  SettingsView.swift
//  VoqMail
//
//  The in-window settings panel. It takes over the detail pane (the sidebar stays
//  put), so it wears the same top bar as the mailbox header — same height, same
//  bottom hairline, same traffic-light clearance when the sidebar is collapsed —
//  and a left tab rail styled like the sidebar's rows, so the panel reads as part
//  of the app rather than a bolted-on preferences window.
//

import SwiftUI

/// A section of the settings panel.
enum SettingsTab: String, CaseIterable, Identifiable {
    case accounts
    case appearance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accounts: return "Accounts"
        case .appearance: return "Appearance"
        }
    }

    var systemImage: String {
        switch self {
        case .accounts: return "person.crop.circle"
        case .appearance: return "paintbrush"
        }
    }
}

struct SettingsView: View {
    @Environment(AppNavigation.self) private var navigation
    @Environment(SidebarModel.self) private var sidebarModel

    var body: some View {
        VStack(spacing: 0) {
            header

            HStack(spacing: 0) {
                tabRail
                    .frame(width: SettingsMetrics.tabRailWidth)

                Divider()

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    /// The panel's top bar — same metrics as `MailboxHeaderView` so toggling
    /// between mail and settings doesn't shift the layout under the seam.
    private var header: some View {
        DetailPaneHeader(
            systemImage: "gearshape",
            title: "Settings",
            leadingPadding: sidebarModel.collapsedClearingLeadingPadding
        ) {
            Button("Done") { navigation.showMailbox() }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
        }
    }

    // MARK: - Tab rail

    private var tabRail: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsTab.allCases) { tab in
                tabRow(tab)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func tabRow(_ tab: SettingsTab) -> some View {
        let isSelected = navigation.settingsTab == tab
        return Button {
            navigation.settingsTab = tab
        } label: {
            HStack(spacing: Metrics.sidebarRowContentSpacing) {
                Image(systemName: tab.systemImage)
                    .frame(width: Metrics.sidebarRowIconWidth)
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Text(tab.title)
                    .font(.body)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.sidebarRowContentSpacing)
            .frame(maxWidth: .infinity, minHeight: SettingsMetrics.tabRowHeight, alignment: .leading)
            .sidebarRowSelection(isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            Group {
                switch navigation.settingsTab {
                case .accounts:
                    AccountsSettingsView()
                case .appearance:
                    AppearanceSettingsView()
                }
            }
            .frame(maxWidth: SettingsMetrics.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SettingsMetrics.contentPadding)
        }
    }
}
