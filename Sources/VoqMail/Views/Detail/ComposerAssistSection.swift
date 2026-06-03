//
//  ComposerAssistSection.swift
//  VoqMail
//
//  The reply-assist (codex) feature's footprint inside the composer, gathered
//  into one feature-owned file so the composer itself carries only thin, marked
//  hooks. Two pieces:
//
//  - `ComposerAssistSection` — the opt-in AI panel that slots into the composer
//    body above the footer. It owns the top-posting insert policy (place the
//    generated reply ABOVE existing content, never clobbering it) and resets the
//    shared store when the composer opens.
//  - `ComposerAssistToggle` — the "Write with AI" footer button that reveals the
//    panel. Renders nothing when the feature is unavailable.
//
//  Removing the feature: delete this file and the two `.composerAssist`/toggle
//  call sites in ComposerView (both tagged `// reply-assist:`).
//

import SwiftUI

/// The collapsible AI drafting panel, shown in the composer body when revealed.
/// Always present in the tree (rendering nothing when collapsed/unavailable) so
/// its `onAppear` can reliably reset the shared store as the composer opens.
struct ComposerAssistSection: View {
    let assist: ReplyAssistStore?
    /// The live draft, passed to the bar as grounding context for the prompt.
    let draft: MailDraft
    /// The composer body text, mutated in place by a top-posting insert.
    @Binding var bodyText: String
    var isSending: Bool
    @Binding var showsAssist: Bool

    var body: some View {
        // VStack(spacing: 0) matches the composer's own zero-spaced stack, so the
        // Divider + bar sit flush exactly as when they lived inline.
        VStack(spacing: 0) {
            if let assist, showsAssist {
                Divider()
                ReplyAssistBar(
                    assist: assist,
                    draft: draft,
                    isSending: isSending,
                    onInsert: { generated in
                        // Place the generated reply above any existing content
                        // (the quoted original and/or text the user already
                        // typed) rather than clobbering it — the email convention
                        // of top-posting, and non-destructive.
                        let existing = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
                        bodyText = existing.isEmpty ? generated : "\(generated)\n\n\(existing)"
                        withAnimation(.easeInOut(duration: 0.18)) { showsAssist = false }
                    })
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // Drop any generated text left over from a previously open composer.
        .onAppear { assist?.reset() }
    }
}

/// The footer affordance that reveals the assist panel. Opt-in so the common
/// type-it-yourself path stays uncluttered; absent entirely when the feature is
/// unavailable, so the footer is unchanged for callers without a store.
struct ComposerAssistToggle: View {
    @Binding var showsAssist: Bool
    var isSending: Bool
    var isAvailable: Bool

    var body: some View {
        if isAvailable {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { showsAssist.toggle() }
            } label: {
                Label("Write with AI", systemImage: "sparkles")
            }
            .disabled(isSending)
            .tint(showsAssist ? .accentColor : nil)
        }
    }
}
