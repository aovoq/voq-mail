//
//  CodexProtocol.swift
//  VoqMail
//
//  The slice of codex's `app-server` JSON-RPC protocol VoqMail speaks. The full
//  protocol is large and **experimental** (it may shift between codex releases),
//  so rather than mirror every type we encode only the handful of request params
//  we send and decode only the leaf fields we read off responses/notifications.
//  Unknown incoming fields are ignored by `JSONDecoder`, which keeps this client
//  resilient to additive protocol changes.
//
//  Generated reference for the full protocol: `codex app-server generate-ts`.
//

import Foundation

// MARK: - Outgoing

/// A JSON-RPC 2.0 request envelope. `params` is generic so each call site passes
/// its own typed params struct.
struct CodexRequest<Params: Encodable>: Encodable {
    let jsonrpc = "2.0"
    let id: Int
    let method: String
    let params: Params
}

/// Encodes to `{}` — used for parameterless-but-object methods like `account/read`.
struct CodexEmptyParams: Encodable {}

struct CodexClientInfo: Encodable {
    let name: String
    let title: String?
    let version: String
}

struct CodexInitializeCapabilities: Encodable {
    /// Opt into the v2 `thread/*` + `turn/*` methods this client drives.
    let experimentalApi: Bool
    let requestAttestation: Bool
}

struct CodexInitializeParams: Encodable {
    let clientInfo: CodexClientInfo
    let capabilities: CodexInitializeCapabilities
}

/// Subset of `ThreadStartParams`. Drafting an email needs no filesystem or
/// command access, so the thread is locked to a read-only sandbox that never
/// asks for approval, and is ephemeral (not persisted to `~/.codex`). Nil fields
/// are omitted by `JSONEncoder`, falling back to codex defaults.
struct CodexThreadStartParams: Encodable {
    var sandbox: String? = "read-only"
    var approvalPolicy: String? = "never"
    var cwd: String?
    var ephemeral: Bool? = true
    var developerInstructions: String?
    /// nil → codex's default model.
    var model: String?
}

/// One `UserInput` of type `text`. `text_elements` is required by the protocol
/// (UI span metadata); we have none, so it is always empty.
struct CodexUserTextInput: Encodable {
    let type = "text"
    let text: String
    let text_elements: [String] = []
}

struct CodexTurnStartParams: Encodable {
    let threadId: String
    let input: [CodexUserTextInput]
    /// nil → inherit the thread's model. `effort` is a `ReasoningEffort`
    /// (`minimal`/`low`/`medium`/`high`/…); nil → the model's default.
    var model: String?
    var effort: String?
}

struct CodexTurnInterruptParams: Encodable {
    let threadId: String
    let turnId: String
}

/// `account/login/start` for a ChatGPT (OAuth) login. The response carries an
/// `authUrl` the client opens in a browser; an `account/login/completed`
/// notification (keyed by `loginId`) signals the end.
struct CodexLoginStartParams: Encodable {
    let type = "chatgpt"
}

struct CodexCancelLoginParams: Encodable {
    let loginId: String
}

// MARK: - Incoming

/// A JSON-RPC id, which the spec allows to be a number OR a string. This client
/// only ever sends integer ids (so responses correlate as ints), but a
/// server-initiated request can carry a string id — decoding it faithfully lets
/// us echo it back when rejecting, rather than silently dropping the request and
/// leaving the server blocked.
enum CodexID: Codable, Equatable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        }
    }
}

/// A decoded inbound line. One type covers responses (carry `id` + `result`/
/// `error`) and notifications (carry `method` + `params`); only the fields this
/// client actually reads are declared, everything else is dropped.
struct CodexIncoming: Decodable {
    let id: CodexID?
    let method: String?
    let result: ResultBody?
    let error: ErrorBody?
    let params: ParamsBody?

    struct ResultBody: Decodable {
        let thread: Ref?
        let turn: Ref?
        // account/read
        let account: AccountBody?
        let requiresOpenaiAuth: Bool?
        // account/login/start (chatgpt)
        let loginId: String?
        let authUrl: String?
        // model/list
        let data: [ModelBody]?
    }

    struct ModelBody: Decodable {
        let id: String
        let displayName: String?
        let defaultReasoningEffort: String?
        let supportedReasoningEfforts: [EffortOption]?
        let isDefault: Bool?
        let hidden: Bool?

        struct EffortOption: Decodable {
            let reasoningEffort: String
        }
    }

    struct Ref: Decodable { let id: String }

    struct AccountBody: Decodable {
        let type: String?
        let email: String?
        let planType: String?
    }

    struct ErrorBody: Decodable {
        let code: Int?
        let message: String?
    }

    /// Notification params. `error` is decoded leniently because its shape varies
    /// by notification: the turn `error` notification carries an object (with a
    /// `message`), while `account/login/completed` carries a bare string. Both
    /// collapse to `errorMessage` so neither shape breaks decoding the other.
    struct ParamsBody: Decodable {
        let threadId: String?
        let turnId: String?
        let delta: String?            // item/agentMessage/delta
        let loginId: String?          // account/login/completed
        let success: Bool?            // account/login/completed
        let errorMessage: String?

        enum CodingKeys: String, CodingKey {
            case threadId, turnId, delta, loginId, success, error
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            threadId = try? c.decodeIfPresent(String.self, forKey: .threadId)
            turnId = try? c.decodeIfPresent(String.self, forKey: .turnId)
            delta = try? c.decodeIfPresent(String.self, forKey: .delta)
            loginId = try? c.decodeIfPresent(String.self, forKey: .loginId)
            success = try? c.decodeIfPresent(Bool.self, forKey: .success)
            if let string = try? c.decode(String.self, forKey: .error) {
                errorMessage = string
            } else if let object = try? c.decode(TurnErrorBody.self, forKey: .error) {
                errorMessage = object.message
            } else {
                errorMessage = nil
            }
        }
    }

    struct TurnErrorBody: Decodable {
        let message: String?
    }
}

/// The authenticated codex account, surfaced to the UI for availability hints.
struct CodexAccount: Equatable {
    let type: String
    let email: String?
    let planType: String?
}

/// A model offered by `model/list`, surfaced to the model/effort picker.
/// `Sendable` so it can cross the actor boundary to the store.
struct CodexModel: Equatable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let supportedEfforts: [String]
    let defaultEffort: String
    let isDefault: Bool
}
