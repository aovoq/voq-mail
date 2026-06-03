//
//  CodexLogEntry.swift
//  VoqMail
//
//  One line in the live codex debug log. `CodexAppServer` (an actor, off the
//  main thread) emits these for every message it sends and receives plus
//  lifecycle events; the store collects them on the main actor and a debug panel
//  in the composer renders them in real time. `Sendable` so it can cross the
//  actor boundary.
//

import Foundation

struct CodexLogEntry: Identifiable, Sendable {
    enum Kind: Sendable {
        case sent          // a request/response we wrote to codex
        case received      // a raw line codex sent us
        case info          // lifecycle (started, disconnected, …)
        case error         // a failure

        /// The arrow/marker shown in the log gutter.
        var symbol: String {
            switch self {
            case .sent: return "→"
            case .received: return "←"
            case .info: return "•"
            case .error: return "⨯"
            }
        }
    }

    let id = UUID()
    let timestamp: Date
    let kind: Kind
    let text: String

    init(kind: Kind, text: String, timestamp: Date = Date()) {
        self.kind = kind
        self.text = text
        self.timestamp = timestamp
    }
}
