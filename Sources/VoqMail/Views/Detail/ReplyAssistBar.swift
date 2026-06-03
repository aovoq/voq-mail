//
//  ReplyAssistBar.swift
//  VoqMail
//
//  The AI reply-drafting affordance shown inside the composer. The user types a
//  natural-language instruction ("polite and concise", "agree, and mention I'll
//  be 5 minutes late") and codex rewrites/writes the reply body, streaming in.
//
//  Design intent: an *inline command line for your voice*, not a chat panel.
//  Native-mac and restrained — a single instruction field, hairline-framed
//  preview, SF type, and the system accent used only to signal liveness (a
//  faint pulsing ring while a draft streams, a blinking caret on the text). It
//  reads as a built-in composer control, not a bolted-on "AI box".
//

import SwiftUI

struct ReplyAssistBar: View {
    let assist: ReplyAssistStore
    /// The live draft, used as grounding context for the prompt.
    let draft: MailDraft
    /// Disabled along with the rest of the form while a send is in flight.
    var isSending: Bool = false
    /// Replace the composer body with the accepted draft text.
    let onInsert: (String) -> Void

    @State private var instruction = ""
    @State private var showsLog = false
    @FocusState private var instructionFocused: Bool

    /// Layout tokens local to this control (kept named, per the design-system
    /// convention, rather than scattered as literals).
    private enum Layout {
        static let horizontalPadding: CGFloat = 20
        static let verticalPadding: CGFloat = 12
        static let rowSpacing: CGFloat = 10
        static let previewCornerRadius: CGFloat = 8
        static let previewMaxHeight: CGFloat = 168
        static let iconColumnWidth: CGFloat = 20
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.rowSpacing) {
            content
            debugSection
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.22))
        .disabled(isSending)
        .task { await assist.checkAvailability() }
    }

    // MARK: - State routing

    @ViewBuilder
    private var content: some View {
        switch assist.availability {
        case .unknown, .checking:
            checkingRow
        case .unavailable(let reason):
            unavailableRow(reason)
        case .needsLogin:
            signInRow
        case .signingIn:
            signingInRow
        case .ready:
            readyContent
        }
    }

    private var checkingRow: some View {
        HStack(spacing: Layout.rowSpacing) {
            ProgressView().controlSize(.small)
            Text("Checking codex…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func unavailableRow(_ reason: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Layout.rowSpacing) {
            Image(systemName: "sparkles.slash")
                .foregroundStyle(.secondary)
                .frame(width: Layout.iconColumnWidth)
            Text(reason)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var signInRow: some View {
        HStack(spacing: Layout.rowSpacing) {
            Image(systemName: "sparkles")
                .foregroundStyle(.secondary)
                .frame(width: Layout.iconColumnWidth)
            VStack(alignment: .leading, spacing: 1) {
                Text("Sign in to codex to draft with AI")
                    .font(.callout)
                Text("Opens ChatGPT sign-in in your browser.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Sign In", action: assist.signIn)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }

    private var signingInRow: some View {
        HStack(spacing: Layout.rowSpacing) {
            ProgressView().controlSize(.small)
            Text("Complete sign-in in your browser…")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel", action: assist.cancelSignIn)
                .buttonStyle(.link)
                .controlSize(.small)
        }
    }

    @ViewBuilder
    private var readyContent: some View {
        instructionRow
        modelEffortRow
        if assist.hasResult || assist.isGenerating {
            previewCard
            actionRow
        }
        if let error = assist.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Compact model + reasoning-effort pickers, shown once the model list loads.
    @ViewBuilder
    private var modelEffortRow: some View {
        if !assist.models.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .foregroundStyle(.tertiary)
                    .frame(width: Layout.iconColumnWidth)

                Picker("Model", selection: modelSelection) {
                    ForEach(assist.models) { model in
                        Text(model.displayName).tag(Optional(model.id))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()

                if !assist.effortOptions.isEmpty {
                    Picker("Effort", selection: effortSelection) {
                        Text("Effort: Auto").tag(String?.none)
                        ForEach(assist.effortOptions, id: \.self) { effort in
                            Text("Effort: \(effort.capitalized)").tag(Optional(effort))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }

                Spacer()
            }
            .font(.caption)
            .controlSize(.small)
            .disabled(assist.isGenerating)
        }
    }

    private var modelSelection: Binding<String?> {
        Binding(get: { assist.selectedModelID }, set: { assist.selectModel($0) })
    }

    private var effortSelection: Binding<String?> {
        Binding(get: { assist.selectedEffort }, set: { assist.selectEffort($0) })
    }

    // MARK: - Instruction row

    private var instructionRow: some View {
        HStack(spacing: Layout.rowSpacing) {
            Image(systemName: "sparkles")
                .foregroundStyle(assist.isGenerating ? Color.accentColor : .secondary)
                .symbolEffect(.variableColor.iterative, isActive: assist.isGenerating)
                .frame(width: Layout.iconColumnWidth)

            TextField("Describe the reply — tone, intent, what to say…", text: $instruction)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($instructionFocused)
                .onSubmit(generate)
                .disabled(assist.isGenerating)

            trailingControl
        }
    }

    @ViewBuilder
    private var trailingControl: some View {
        if assist.isGenerating {
            Button(action: assist.cancelGeneration) {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Stop generating")
        } else {
            Button(action: generate) {
                Text(assist.hasResult ? "Regenerate" : "Generate")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(instruction.trimmingCharacters(in: .whitespaces).isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
    }

    // MARK: - Streaming preview

    private var previewCard: some View {
        ScrollView {
            Text(assist.draftText.isEmpty ? " " : assist.draftText)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
        .frame(maxHeight: Layout.previewMaxHeight)
        .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: Layout.previewCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Layout.previewCornerRadius)
                .strokeBorder(
                    assist.isGenerating ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.08),
                    lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.25), value: assist.isGenerating)
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: Layout.rowSpacing) {
            Button("Insert", action: insert)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(assist.draftText.isEmpty || assist.isGenerating)

            if assist.isGenerating {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Writing…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Discard", action: assist.reset)
                .buttonStyle(.link)
                .controlSize(.small)
                .disabled(assist.draftText.isEmpty && !assist.isGenerating)
        }
    }

    private func generate() {
        let trimmed = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        instructionFocused = false
        assist.generate(instruction: trimmed, draft: draft)
    }

    private func insert() {
        onInsert(assist.draftText)
        assist.reset()
    }

    // MARK: - Debug log

    /// Shown once codex is located (we have a connection that can produce
    /// traffic). A collapsed toggle keeps it out of the way for normal use.
    @ViewBuilder
    private var debugSection: some View {
        if showsDebugAffordance {
            Divider()
            HStack(spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { showsLog.toggle() }
                } label: {
                    Label("Debug log", systemImage: showsLog ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Text("\(assist.log.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)

                Spacer()

                if showsLog {
                    Button("Copy") { copyLog() }
                        .buttonStyle(.link)
                        .controlSize(.small)
                        .disabled(assist.log.isEmpty)
                    Button("Clear", action: assist.clearLog)
                        .buttonStyle(.link)
                        .controlSize(.small)
                        .disabled(assist.log.isEmpty)
                }
            }
            if showsLog {
                CodexLogView(entries: assist.log)
                    .transition(.opacity)
            }
        }
    }

    /// Copies the whole log as plain text to the clipboard.
    private func copyLog() {
        let text = CodexLogView.plainText(assist.log)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private var showsDebugAffordance: Bool {
        switch assist.availability {
        case .ready, .needsLogin, .signingIn: return true
        case .unknown, .checking, .unavailable: return !assist.log.isEmpty
        }
    }
}

/// A live, auto-scrolling view of the codex JSON-RPC traffic, for debugging.
///
/// The whole log is rendered as a single selectable `Text` built from one
/// `AttributedString` (per-line color preserved). That makes ⌘A select-all and
/// drag-select-across-lines work and copy as clean plain text — which per-row
/// `Text`s could not do — while staying monospaced and readable. A "Copy" button
/// (in the parent) is the one-click path.
private struct CodexLogView: View {
    let entries: [CodexLogEntry]

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView([.vertical]) {
                Text(attributedLog)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .id(Self.bottomAnchor)
            }
            .onChange(of: entries.count) {
                withAnimation { proxy.scrollTo(Self.bottomAnchor, anchor: .bottom) }
            }
        }
        .frame(height: 190)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.6),
                    in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .overlay {
            if entries.isEmpty {
                Text("No traffic yet.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private static let bottomAnchor = "codex-log-bottom"

    /// One attributed block: each line is `HH:mm:ss.SSS  →  text`, the gutter
    /// dimmed, the arrow colored by direction, errors in red.
    private var attributedLog: AttributedString {
        var result = AttributedString()
        for (index, entry) in entries.enumerated() {
            var stamp = AttributedString("\(Self.timeFormatter.string(from: entry.timestamp))  ")
            stamp.foregroundColor = .secondary
            var marker = AttributedString("\(entry.kind.symbol)  ")
            marker.foregroundColor = Self.color(for: entry.kind)
            var body = AttributedString(entry.text)
            body.foregroundColor = entry.kind == .error ? .red : .primary
            result += stamp
            result += marker
            result += body
            if index != entries.count - 1 { result += AttributedString("\n") }
        }
        return result
    }

    /// Plain-text rendering for the clipboard.
    static func plainText(_ entries: [CodexLogEntry]) -> String {
        entries.map { entry in
            "\(timeFormatter.string(from: entry.timestamp))  \(entry.kind.symbol)  \(entry.text)"
        }
        .joined(separator: "\n")
    }

    private static func color(for kind: CodexLogEntry.Kind) -> Color {
        switch kind {
        case .sent: return .blue
        case .received: return .green
        case .info: return .secondary
        case .error: return .red
        }
    }
}
