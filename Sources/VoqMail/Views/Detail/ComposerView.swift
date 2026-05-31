//
//  Reply composer presented as a sheet from the message detail pane.
//
//  ComposerView.swift
//  VoqMail
//

import SwiftUI

struct ComposerView: View {
    @Binding var draft: MailDraft
    let onCancel: () -> Void
    let onSend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reply")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Send", action: onSend)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSend)
            }

            LabeledContent("To") {
                TextField("recipient@example.com", text: recipientsBinding)
                    .textFieldStyle(.roundedBorder)
            }

            TextField("Subject", text: $draft.subject)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $draft.body)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 220)
                .padding(8)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.quaternary)
                }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 380)
    }

    private var recipientsBinding: Binding<String> {
        Binding {
            draft.to.joined(separator: ", ")
        } set: { value in
            draft.to = value
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }

    private var canSend: Bool {
        !draft.to.isEmpty
    }
}
