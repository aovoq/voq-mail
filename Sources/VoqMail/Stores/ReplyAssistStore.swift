//
//  ReplyAssistStore.swift
//  VoqMail
//
//  Observable UI state for AI reply drafting. Bridges the composer to the
//  `CodexAppServer` actor: checks whether codex is installed/signed-in, builds
//  the drafting prompt from the open draft + the user's natural-language
//  instruction, and streams the generated body in for live preview.
//
//  One instance is constructed in `VoqMailApp` and injected via `.environment`.
//  Only one composer is open at a time (a sheet), so a single drafting slice is
//  enough — no per-account partitioning like the mail stores need (issue #8).
//  `reset()` clears the slice each time a composer opens so a prior draft's text
//  never lingers.
//

import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class ReplyAssistStore {
    /// Whether codex can be used, resolved once (lazily) and cached. The
    /// `unavailable` reason is a ready-to-show, human-facing hint.
    enum Availability: Equatable {
        case unknown
        case checking
        case ready(account: String?)
        case needsLogin          // installed, but no stored codex auth
        case signingIn           // browser OAuth in progress
        case unavailable(String) // not installed / too old / errored
    }

    private(set) var availability: Availability = .unknown
    private(set) var isGenerating = false
    /// The streamed reply body, appended delta-by-delta for live preview.
    private(set) var draftText = ""
    private(set) var errorMessage: String?

    /// Live codex JSON-RPC traffic + lifecycle, for the in-composer debug panel.
    private(set) var log: [CodexLogEntry] = []
    private static let logCapacity = 400
    private var activeLoginID: String?

    /// Models offered by codex (`model/list`) and the user's persisted picks.
    /// `selectedModelID`/`selectedEffort` nil means "codex default".
    private(set) var models: [CodexModel] = []
    private(set) var selectedModelID: String?
    private(set) var selectedEffort: String?

    private enum DefaultsKey {
        static let model = "codex.reply.model"
        static let effort = "codex.reply.effort"
    }

    init() {
        selectedModelID = UserDefaults.standard.string(forKey: DefaultsKey.model)
        selectedEffort = UserDefaults.standard.string(forKey: DefaultsKey.effort)
    }

    /// The currently-selected model record, if it's in the fetched list.
    var selectedModel: CodexModel? {
        models.first { $0.id == selectedModelID }
    }

    /// Reasoning efforts valid for the selected model (empty until models load).
    var effortOptions: [String] {
        selectedModel?.supportedEfforts ?? []
    }

    func selectModel(_ id: String?) {
        selectedModelID = id
        UserDefaults.standard.set(id, forKey: DefaultsKey.model)
        // Drop an effort the newly-picked model doesn't support.
        if let effort = selectedEffort, let model = models.first(where: { $0.id == id }),
           !model.supportedEfforts.contains(effort) {
            selectEffort(nil)
        }
    }

    func selectEffort(_ effort: String?) {
        selectedEffort = effort
        UserDefaults.standard.set(effort, forKey: DefaultsKey.effort)
    }

    /// Built after the binary is located; nil until then (and when codex is
    /// missing). Holds the long-lived child-process connection.
    private var server: CodexAppServer?
    private var generationTask: Task<Void, Never>?
    /// Bumped on each generate/cancel/reset. A generation task captures its value
    /// and checks it before every state write, so a superseded run's late delta
    /// or trailing `isGenerating = false` can't clobber a newer run (the same
    /// load-generation guard the mail stores use, per CLAUDE.md).
    private var generation = 0

    var isReady: Bool {
        if case .ready = availability { return true }
        return false
    }

    var hasResult: Bool { !draftText.isEmpty }

    // MARK: - Availability

    /// Locates codex (off the main actor — `Process` work blocks) and checks its
    /// sign-in state. Cached: a prior `ready`/`unavailable` verdict is reused so
    /// reopening the composer doesn't re-probe. Call before showing the assist UI.
    func checkAvailability() async {
        switch availability {
        case .ready, .unavailable, .checking, .signingIn:
            return
        case .needsLogin, .unknown:
            break
        }
        availability = .checking

        // Build the connection (locating the binary blocks, so do it off-actor)
        // only once; reuse it on a re-check after sign-in.
        if server == nil {
            let located: Result<CodexInstall, Error> = await Task.detached(priority: .userInitiated) {
                do { return .success(try CodexLocator.locate()) }
                catch { return .failure(error) }
            }.value
            switch located {
            case .failure(let error):
                availability = .unavailable(Self.locateHint(for: error))
                return
            case .success(let install):
                server = makeServer(binary: install.url)
            }
        }

        guard let server else { availability = .unavailable("codex unavailable."); return }
        do {
            if let account = try await server.authenticatedAccount() {
                availability = .ready(account: account.email)
                await loadModels()
            } else {
                availability = .needsLogin
            }
        } catch {
            availability = .unavailable(Self.message(for: error))
        }
    }

    /// Fetches the model list once and defaults the selection to codex's default
    /// model when the user has no (still-valid) saved pick. Non-fatal on failure
    /// — the picker just stays empty and codex's default model is used.
    private func loadModels() async {
        guard let server, models.isEmpty else { return }
        do {
            let fetched = try await server.listModels()
            models = fetched
            if selectedModelID == nil || !fetched.contains(where: { $0.id == selectedModelID }) {
                selectModel(fetched.first(where: \.isDefault)?.id ?? fetched.first?.id)
            }
        } catch {
            // Leave models empty; generation falls back to codex defaults.
        }
    }

    /// Builds the server with a log sink that mirrors codex traffic into `log`
    /// on the main actor for the debug panel. Weak self avoids a retain cycle
    /// (store → server → sink → store).
    private func makeServer(binary: URL) -> CodexAppServer {
        CodexAppServer(binary: binary) { [weak self] entry in
            Task { @MainActor in self?.appendLog(entry) }
        }
    }

    func appendLog(_ entry: CodexLogEntry) {
        log.append(entry)
        if log.count > Self.logCapacity {
            log.removeFirst(log.count - Self.logCapacity)
        }
    }

    func clearLog() { log.removeAll() }

    // MARK: - Sign in

    /// Runs codex's ChatGPT OAuth: opens the browser to the auth URL and waits
    /// for codex's completion notification, then re-checks availability.
    func signIn() {
        guard let server else { return }
        Task {
            availability = .signingIn
            do {
                let handle = try await server.beginChatGPTLogin()
                activeLoginID = handle.loginId
                NSWorkspace.shared.open(handle.url)
                try await server.awaitLogin(loginId: handle.loginId)
                activeLoginID = nil
                availability = .unknown
                await checkAvailability()
            } catch {
                activeLoginID = nil
                availability = .needsLogin
                errorMessage = Self.message(for: error)
            }
        }
    }

    func cancelSignIn() {
        if let loginID = activeLoginID {
            let server = self.server
            Task { await server?.cancelLogin(loginId: loginID) }
        }
        activeLoginID = nil
        availability = .needsLogin
    }

    // MARK: - Generation

    /// Starts (or restarts) a generation from `instruction`, drawing context off
    /// `draft`. Cancels any in-flight generation first, so tapping Regenerate is
    /// safe. The result streams into `draftText`.
    func generate(instruction: String, draft: MailDraft) {
        guard let server else { return }
        let trimmed = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        generationTask?.cancel()
        generation += 1
        let token = generation
        isGenerating = true
        errorMessage = nil
        draftText = ""

        let prompt = ReplyPromptBuilder.buildPrompt(instruction: trimmed, draft: draft)
        let developerInstructions = ReplyPromptBuilder.developerInstructions
        let model = selectedModelID
        let effort = selectedEffort

        generationTask = Task { [weak self] in
            do {
                let stream = await server.generateReply(
                    developerInstructions: developerInstructions,
                    prompt: prompt,
                    model: model,
                    effort: effort)
                for try await delta in stream {
                    guard let self, self.generation == token else { return }
                    self.draftText.append(delta)
                }
            } catch is CancellationError {
                // User cancelled; keep whatever streamed in so far.
            } catch {
                guard let self, self.generation == token else { return }
                self.errorMessage = Self.message(for: error)
            }
            guard let self, self.generation == token else { return }
            self.isGenerating = false
        }
    }

    /// Cancels an in-flight generation. Cancelling the consuming task terminates
    /// the stream, which interrupts the codex turn (stops billing). Bumping the
    /// generation neutralizes the cancelled task's trailing state writes.
    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        generation += 1
        isGenerating = false
    }

    /// Clears the drafting slice (keeps the cached availability verdict). Called
    /// when a composer opens and when its assist panel is dismissed.
    func reset() {
        cancelGeneration()
        draftText = ""
        errorMessage = nil
    }

    // MARK: - Messages

    private static func locateHint(for error: Error) -> String {
        switch error {
        case CodexLocator.Failure.notFound:
            return "codex CLI not found. Install it with `brew install codex` (or from chatgpt.com/codex), then reopen the composer."
        case CodexLocator.Failure.versionUnreadable:
            return "Found codex but couldn't read its version. Update it and try again."
        case CodexLocator.Failure.tooOld(let found, let required):
            return "codex \(found) is too old (need \(required)+). Update with `brew upgrade codex`."
        default:
            return message(for: error)
        }
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
