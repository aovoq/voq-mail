//
//  AppNavigation.swift
//  VoqMail
//
//  What the detail pane is currently showing: the selected mailbox's mail, or the
//  in-window settings panel. Settings replaces the detail pane (the sidebar stays
//  visible) rather than opening a separate window, so it lives as a route here
//  instead of as its own SwiftUI `Settings` scene — that keeps the app's custom
//  chrome (hidden titlebar, curved seam, translucent sidebar) unbroken.
//

import Observation
import SwiftUI

@Observable
@MainActor
final class AppNavigation {
    /// What the detail pane renders.
    enum DetailRoute: Equatable {
        case mailbox
        case settings
    }

    private(set) var detailRoute: DetailRoute = .mailbox
    /// The settings section shown when `detailRoute == .settings`. Kept across
    /// closes so reopening settings returns to the last-viewed tab.
    var settingsTab: SettingsTab = .accounts

    var isShowingSettings: Bool { detailRoute == .settings }

    /// Opens settings, optionally jumping straight to a tab.
    func showSettings(_ tab: SettingsTab? = nil) {
        if let tab { settingsTab = tab }
        detailRoute = .settings
    }

    /// Returns to the mailbox view. Called both by the panel's Done control and by
    /// an explicit mailbox click in the sidebar.
    func showMailbox() {
        detailRoute = .mailbox
    }

    /// Flips between mail and settings — wired to the ⌘, menu command.
    func toggleSettings() {
        detailRoute = isShowingSettings ? .mailbox : .settings
    }
}
