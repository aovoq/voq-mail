//
//  SettingsSection.swift
//  VoqMail
//
//  A titled section in the settings content column: a heading with an optional
//  caption, then the section's controls. Shared by every settings tab so the
//  title/caption typography and spacing stay in one place. It renders only the
//  inner section — each tab keeps its own outer stack spacing sections apart.
//

import SwiftUI

struct SettingsSection<Content: View>: View {
    let title: String
    var caption: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
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
            content
        }
    }
}
