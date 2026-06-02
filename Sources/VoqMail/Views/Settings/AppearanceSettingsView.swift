//
//  AppearanceSettingsView.swift
//  VoqMail
//
//  The Appearance tab. For now it exposes the one appearance value the app already
//  holds — the sidebar width — bound live to `SidebarModel`, so the control does
//  something real rather than standing in for unbuilt settings. Persisting these
//  choices (AppStorage) and adding more (material, accent) is a later slice; until
//  then `SidebarModel.width` stays scene-local, so a change here lasts the run.
//

import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(SidebarModel.self) private var sidebarModel

    var body: some View {
        @Bindable var sidebar = sidebarModel

        VStack(alignment: .leading, spacing: SettingsMetrics.sectionSpacing) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sidebar")
                        .font(.title3.weight(.semibold))
                    Text("Width of the mailbox sidebar. Resets when the app relaunches.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Slider(
                        value: $sidebar.width,
                        in: Metrics.sidebarMinWidth...Metrics.sidebarMaxWidth)

                    Text("\(Int(sidebar.width)) pt")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .trailing)
                }
            }
        }
    }
}
