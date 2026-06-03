//
//  ReplyPromptBuilder.swift
//  VoqMail
//
//  Assembles the exact text sent to codex for AI reply drafting: the static
//  developer instructions (the assistant's standing rules) and the per-turn
//  prompt built from the open draft + the user's natural-language instruction.
//
//  Pure, stateless string assembly — kept out of `ReplyAssistStore` (the
//  @MainActor UI-state layer) so "what we ask codex" lives in the Services layer
//  alongside the other codex pieces, and the store stays orchestration-only.
//

import Foundation

enum ReplyPromptBuilder {
    /// The assistant's standing rules, sent once as the thread's developer
    /// instructions. This text is product behavior — edit deliberately.
    static let developerInstructions = """
    You are VoqMail's reply-drafting assistant. You write the body of an email on the user's behalf.

    Rules:
    - Output ONLY the email body text. No subject line, no markdown, no code fences, no surrounding quotation marks, and no commentary or explanation before or after.
    - Do NOT echo back the quoted original message; the mail app threads replies via headers, so only the new body is needed.
    - Write in the same language as the conversation (often Japanese). Choose a natural register and honorifics for that language.
    - Follow the user's instruction precisely. Never invent facts, names, dates, numbers, or commitments that the context or instruction does not support.
    - Produce text that is ready to send as-is.
    """

    /// Assembles the turn prompt from the open draft and the user's instruction.
    /// The full original message (when replying) and anything the user has
    /// already drafted are handed over as read-only context so the model can
    /// ground its reply.
    static func buildPrompt(instruction: String, draft: MailDraft) -> String {
        let recipients = draft.to.joined(separator: ", ")
        let subject = draft.subject.isEmpty ? "(none)" : draft.subject
        let original = draft.originalText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalBlock = (original?.isEmpty == false) ? original! : "(none — this is a new message)"
        let drafted = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let draftedBlock = drafted.isEmpty ? "(empty)" : drafted

        return """
        To: \(recipients.isEmpty ? "(unspecified)" : recipients)
        Subject: \(subject)

        The message being replied to (context only — do not quote it back):
        \"\"\"
        \(originalBlock)
        \"\"\"

        Anything the user has already drafted (may include a quoted snippet; may be empty):
        \"\"\"
        \(draftedBlock)
        \"\"\"

        Instruction for how to write the reply:
        \(instruction)

        Write the final email body now.
        """
    }
}
