//
//  Composer presented as a sheet from the message detail pane — used both to
//  reply (threading fields carried on the draft) and to start a new message.
//
//  ComposerView.swift
//  VoqMail
//

import SwiftUI
import UniformTypeIdentifiers

struct ComposerView: View {
    @Binding var draft: MailDraft
    /// Accounts the user can send from. A new message can pick among them; a reply
    /// is pinned to the account that received the original, so the picker collapses
    /// to a static address there.
    var accounts: [Account] = []
    let onCancel: () -> Void
    let onSend: () -> Void
    /// Set while a send is in flight: disables the form and shows progress. Held by
    /// the parent so the sheet stays open (showing `errorMessage`) on failure.
    var isSending: Bool = false
    var errorMessage: String? = nil

    @State private var isImportingAttachments = false
    /// Cc/Bcc start hidden to keep the common case uncluttered; revealed on demand
    /// (or immediately when a draft already carries either, e.g. an edited reply).
    @State private var showsCcBcc = false
    @FocusState private var focus: Field?

    private enum Field { case to, subject, body }

    /// A reply pre-fills threading fields; a fresh compose does not.
    private var isReply: Bool { draft.replyingToMessageID != nil }

    private static let labelColumnWidth: CGFloat = 60

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            recipientFields
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .disabled(isSending)
            Divider()
            bodyEditor
                .disabled(isSending)
            if !draft.attachments.isEmpty {
                Divider()
                attachmentStrip
                    .disabled(isSending)
            }
            Divider()
            footer
        }
        .frame(minWidth: 600, idealWidth: 660, minHeight: 480, idealHeight: 560)
        // Note: only the editable areas are disabled while sending — Cancel stays
        // live so a slow send can always be dismissed (its result is then dropped
        // by the store's generation guard).
        .onAppear {
            focus = draft.to.isEmpty ? .to : .body
            showsCcBcc = !draft.cc.isEmpty || !draft.bcc.isEmpty
        }
        .fileImporter(
            isPresented: $isImportingAttachments,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                attach(urls)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Text(isReply ? "Reply" : "New Message")
                .font(.title2.weight(.semibold))
            Spacer()
            if isSending {
                ProgressView()
                    .controlSize(.small)
            }
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
            Button("Send", action: onSend)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSend || isSending)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Recipient / subject fields

    private var recipientFields: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                fieldLabel("From")
                fromControl
            }
            GridRow {
                fieldLabel("To")
                HStack(spacing: 8) {
                    TextField("recipient@example.com", text: addressBinding(\.to))
                        .textFieldStyle(.roundedBorder)
                        .focused($focus, equals: .to)
                    if !showsCcBcc {
                        Button("Cc/Bcc") { withAnimation(.easeInOut(duration: 0.15)) { showsCcBcc = true } }
                            .buttonStyle(.link)
                            .font(.callout)
                    }
                }
            }
            if showsCcBcc {
                GridRow {
                    fieldLabel("Cc")
                    TextField("cc@example.com", text: addressBinding(\.cc))
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    fieldLabel("Bcc")
                    TextField("bcc@example.com", text: addressBinding(\.bcc))
                        .textFieldStyle(.roundedBorder)
                }
            }
            GridRow {
                fieldLabel("Subject")
                TextField("Subject", text: $draft.subject)
                    .textFieldStyle(.roundedBorder)
                    .focused($focus, equals: .subject)
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .gridColumnAlignment(.trailing)
            .frame(width: Self.labelColumnWidth, alignment: .trailing)
    }

    /// A reply is sent from the account that received it (fixed); a new message can
    /// pick among the signed-in accounts, defaulting to the active mailbox's one.
    @ViewBuilder private var fromControl: some View {
        if !isReply, accounts.count > 1 {
            Picker("", selection: $draft.accountID) {
                ForEach(accounts) { account in
                    Text(account.email).tag(account.email)
                }
            }
            .labelsHidden()
            .fixedSize()
        } else {
            Text(draft.accountID)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Body

    private var bodyEditor: some View {
        TextEditor(text: $draft.body)
            .font(.body)
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(12)
            .focused($focus, equals: .body)
            .overlay(alignment: .topLeading) {
                // TextEditor has no native placeholder; show one for an empty body
                // and let taps fall through to the editor beneath.
                if draft.body.isEmpty {
                    Text("Write your message…")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 17)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
    }

    // MARK: - Attachments

    /// A horizontally scrolling row of attachment chips, shown only when the draft
    /// carries files (the "Attach" affordance lives in the footer toolbar).
    private var attachmentStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(draft.attachments) { attachment in
                    attachmentChip(attachment)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    private func attachmentChip(_ attachment: DraftAttachment) -> some View {
        HStack(spacing: 6) {
            Image(systemName: iconName(for: attachment))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(attachment.filename)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(byteCountLabel(attachment.data.count))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Button {
                draft.attachments.removeAll { $0.id == attachment.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: 240)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                isImportingAttachments = true
            } label: {
                Label("Attach", systemImage: "paperclip")
            }
            .disabled(isSending)
            if let count = attachmentSummary {
                Text(count)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Attachment helpers

    /// Reads each picked file's bytes into the draft. Each URL is a security-scoped
    /// resource handed over by the importer, so access is bracketed start/stop.
    private func attach(_ urls: [URL]) {
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { continue }
            let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
                ?? "application/octet-stream"
            draft.attachments.append(DraftAttachment(
                id: UUID().uuidString,
                filename: url.lastPathComponent,
                mimeType: mimeType,
                data: data))
        }
    }

    private func iconName(for attachment: DraftAttachment) -> String {
        let type = UTType(mimeType: attachment.mimeType)
        if type?.conforms(to: .image) == true { return "photo" }
        if type?.conforms(to: .movie) == true { return "film" }
        if type?.conforms(to: .pdf) == true { return "doc.richtext" }
        if type?.conforms(to: .archive) == true { return "doc.zipper" }
        return "doc"
    }

    private var attachmentSummary: String? {
        guard !draft.attachments.isEmpty else { return nil }
        let total = draft.attachments.reduce(0) { $0 + $1.data.count }
        let count = draft.attachments.count
        return "\(count) file\(count == 1 ? "" : "s") · \(byteCountLabel(total))"
    }

    private func byteCountLabel(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }

    // MARK: - Bindings

    /// A comma-split text binding over one of the address arrays (to/cc/bcc).
    private func addressBinding(_ keyPath: WritableKeyPath<MailDraft, [String]>) -> Binding<String> {
        Binding {
            draft[keyPath: keyPath].joined(separator: ", ")
        } set: { value in
            draft[keyPath: keyPath] = value
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }

    /// Send is allowed once there is at least one recipient and every recipient in
    /// To/Cc/Bcc looks like an address (carries an `@`), so an obvious typo is
    /// caught before the round-trip rather than as a server-side bounce.
    private var canSend: Bool {
        guard !draft.to.isEmpty else { return false }
        return (draft.to + draft.cc + draft.bcc).allSatisfy { $0.contains("@") }
    }
}
