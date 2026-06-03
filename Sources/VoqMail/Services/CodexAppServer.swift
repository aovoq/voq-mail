//
//  CodexAppServer.swift
//  VoqMail
//
//  Drives a `codex app-server` child process over newline-delimited JSON-RPC on
//  stdio, exposing the one capability VoqMail needs: turn a natural-language
//  instruction into an email reply body, streamed token-by-token.
//
//  Isolated as an `actor` (like `TokenProvider`) because it owns mutable,
//  shared, long-lived state — the child process, the stdin handle, the pending
//  request table, and the single in-flight drafting stream — that many callers
//  and a background reader task touch concurrently.
//
//  Protocol flow (verified against codex-cli 0.136.0):
//    initialize → account/read → thread/start (ephemeral, read-only sandbox)
//    → turn/start → stream `item/agentMessage/delta` until `turn/completed`.
//  See CodexProtocol.swift for the encoded/decoded subset and CodexLocator for
//  how the binary is found. The server is started lazily and kept alive across
//  generations; each generation runs on a fresh ephemeral thread so prior
//  drafts never bleed into the next.
//
//  Concurrency contract (the actor interleaves at every `await`, so a second
//  generation can run while a first is suspended mid-handshake):
//  - Every `generateReply` call gets a unique `streamID`. `latestStreamID` names
//    the most recently started generation; each post-`await` write in
//    `runGeneration` is gated on still being the latest, so a superseded run can
//    never overwrite the current run's state.
//  - The active slot (`activeThreadID`/`activeTurnID`/`activeContinuation`,
//    tagged with `activeStreamID`) is only installed once `thread/start`
//    returns, and only its owning stream clears it — identified by `streamID`,
//    since `AsyncThrowingStream.Continuation` is not itself comparable.
//

import Foundation
import os

actor CodexAppServer {
    enum ServerError: LocalizedError {
        case launchFailed(String)
        case notAuthenticated
        case protocolError(String)
        case turnFailed(String)
        case timedOut
        case loginFailed(String)

        var errorDescription: String? {
            switch self {
            case .launchFailed(let detail):
                return "Couldn't start codex: \(detail)"
            case .notAuthenticated:
                return "codex isn't signed in."
            case .protocolError(let detail):
                return "codex protocol error: \(detail)"
            case .turnFailed(let detail):
                return detail
            case .timedOut:
                return "codex stopped responding. Please try again."
            case .loginFailed(let detail):
                return "Sign-in failed: \(detail)"
            }
        }
    }

    /// Wall-clock ceilings so a hung-but-alive child can never strand the UI in
    /// a "generating" state forever. The request ceiling covers the handshake
    /// round-trips; the turn ceiling covers the streaming phase.
    private static let requestTimeout: Duration = .seconds(30)
    private static let turnTimeout: Duration = .seconds(120)

    private let binary: URL
    private let log = Logger(subsystem: "work.aovoq.voqmail", category: "codex")
    /// Emits a line for every message sent/received plus lifecycle events, for
    /// the live debug panel. Crosses the actor boundary, hence `@Sendable`.
    private let logSink: @Sendable (CodexLogEntry) -> Void

    private var process: Process?
    private var stdin: FileHandle?
    private var readerTask: Task<Void, Never>?
    private var initialized = false

    private var nextID = 1
    private var pending: [Int: CheckedContinuation<CodexIncoming, Error>] = [:]

    /// Monotonic per-generation id, assigned when a stream is created. See the
    /// concurrency contract.
    private var streamSeq = 0
    /// The most recently started generation; gates `runGeneration`'s writes.
    private var latestStreamID = 0

    /// The single in-flight drafting turn. Deltas and the terminal
    /// `turn/completed`/`error` notification for this thread route to its
    /// continuation. `activeStreamID` tags which generation owns the slot.
    private var activeStreamID: Int?
    private var activeThreadID: String?
    private var activeTurnID: String?
    private var activeContinuation: AsyncThrowingStream<String, Error>.Continuation?

    /// Threads whose turn an interrupt was requested for *before* the turn id was
    /// known (cancelled/superseded mid `turn/start`). Once the id arrives, the
    /// owning run honors the pending interrupt so the turn stops billing.
    private var interruptPendingThreadIDs: Set<String> = []

    /// Waiters for `account/login/completed`, keyed by `loginId`.
    private var loginContinuations: [String: CheckedContinuation<Void, Error>] = [:]

    init(binary: URL, logSink: @escaping @Sendable (CodexLogEntry) -> Void = { _ in }) {
        self.binary = binary
        self.logSink = logSink
    }

    private func emit(_ kind: CodexLogEntry.Kind, _ text: String) {
        logSink(CodexLogEntry(kind: kind, text: text))
    }

    // MARK: - Public API

    /// Confirms the server starts and reports the signed-in account (nil when
    /// codex has no stored auth). Used by the store to gate the UI up front.
    func authenticatedAccount() async throws -> CodexAccount? {
        try await initializeIfNeeded()
        let message = try await request(method: "account/read", params: CodexEmptyParams())
        guard let account = message.result?.account, let type = account.type else { return nil }
        return CodexAccount(type: type, email: account.email, planType: account.planType)
    }

    /// The models codex offers for the signed-in account, for the picker.
    /// Hidden models are filtered out.
    func listModels() async throws -> [CodexModel] {
        try await initializeIfNeeded()
        let message = try await request(method: "model/list", params: CodexEmptyParams())
        let entries = message.result?.data ?? []
        return entries.compactMap { entry in
            guard entry.hidden != true else { return nil }
            return CodexModel(
                id: entry.id,
                displayName: entry.displayName ?? entry.id,
                supportedEfforts: entry.supportedReasoningEfforts?.map(\.reasoningEffort) ?? [],
                defaultEffort: entry.defaultReasoningEffort ?? "medium",
                isDefault: entry.isDefault ?? false)
        }
    }

    /// An in-progress ChatGPT login: the browser URL the user must open and the
    /// `loginId` that `awaitLogin`/`cancelLogin` reference.
    struct LoginHandle: Sendable {
        let loginId: String
        let url: URL
    }

    /// Begins a ChatGPT OAuth login and returns the URL to open in a browser.
    /// codex hosts the local callback; completion arrives as a notification —
    /// await it via `awaitLogin(loginId:)`.
    func beginChatGPTLogin() async throws -> LoginHandle {
        try await initializeIfNeeded()
        let message = try await request(method: "account/login/start", params: CodexLoginStartParams())
        guard let loginId = message.result?.loginId,
              let authUrl = message.result?.authUrl,
              let url = URL(string: authUrl) else {
            throw ServerError.loginFailed("codex did not return a sign-in URL.")
        }
        return LoginHandle(loginId: loginId, url: url)
    }

    /// Suspends until codex reports the login finished (or fails / times out).
    func awaitLogin(loginId: String, timeout: Duration = .seconds(300)) async throws {
        let timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            if Task.isCancelled { return }
            await self?.failLogin(loginId, reason: "Timed out waiting for sign-in.")
        }
        defer { timeoutTask.cancel() }
        try await withCheckedThrowingContinuation { continuation in
            loginContinuations[loginId] = continuation
        }
    }

    func cancelLogin(loginId: String) {
        let id = nextID
        nextID += 1
        try? writeMessage(CodexRequest(
            id: id, method: "account/login/cancel", params: CodexCancelLoginParams(loginId: loginId)))
        failLogin(loginId, reason: "Sign-in cancelled.")
    }

    private func failLogin(_ loginId: String, reason: String) {
        if let continuation = loginContinuations.removeValue(forKey: loginId) {
            continuation.resume(throwing: ServerError.loginFailed(reason))
        }
    }

    /// Streams an email reply body produced from `prompt`, constrained by
    /// `developerInstructions`. The stream yields text deltas in order and
    /// finishes on `turn/completed`, or throws on auth/protocol/turn failure.
    /// Terminating the stream (e.g. the caller cancels) interrupts the turn.
    func generateReply(
        developerInstructions: String,
        prompt: String,
        model: String? = nil,
        effort: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        streamSeq += 1
        let streamID = streamSeq
        return AsyncThrowingStream { continuation in
            let task = Task { await self.runGeneration(
                streamID: streamID,
                developerInstructions: developerInstructions,
                prompt: prompt,
                model: model,
                effort: effort,
                continuation: continuation) }
            continuation.onTermination = { _ in
                task.cancel()
                Task { await self.streamTerminated(streamID) }
            }
        }
    }

    // MARK: - Generation

    private func runGeneration(
        streamID: Int,
        developerInstructions: String,
        prompt: String,
        model: String?,
        effort: String?,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async {
        // Supersede any still-active generation rather than rejecting: a fast
        // Regenerate may arrive before the previous stream's cancellation has
        // interrupted its turn. Interrupt + drop the old one, then take over.
        if activeStreamID != nil {
            interruptActiveSlot()
        }
        latestStreamID = streamID

        do {
            try await initializeIfNeeded()
            guard latestStreamID == streamID else { continuation.finish(); return }

            let account = try await request(method: "account/read", params: CodexEmptyParams())
            guard latestStreamID == streamID else { continuation.finish(); return }
            guard account.result?.account != nil else {
                continuation.finish(throwing: ServerError.notAuthenticated)
                return
            }

            let params = CodexThreadStartParams(
                cwd: NSTemporaryDirectory(),
                developerInstructions: developerInstructions,
                model: model)
            let started = try await request(method: "thread/start", params: params)
            guard latestStreamID == streamID else { continuation.finish(); return }
            guard let threadID = started.result?.thread?.id else {
                continuation.finish(throwing: ServerError.protocolError("thread/start returned no thread id"))
                return
            }

            // Install the active slot before turn/start so a fast first delta
            // isn't dropped (the reader routes by thread id).
            activeStreamID = streamID
            activeThreadID = threadID
            activeContinuation = continuation

            let turn = try await request(
                method: "turn/start",
                params: CodexTurnStartParams(
                    threadId: threadID,
                    input: [CodexUserTextInput(text: prompt)],
                    model: model,
                    effort: effort))
            let turnID = turn.result?.turn?.id

            // We may have been superseded or cancelled while turn/start was in
            // flight. Honor the (now-actionable) interrupt and bow out without
            // disturbing whoever owns the slot now.
            let superseded = latestStreamID != streamID
            let cancelled = interruptPendingThreadIDs.remove(threadID) != nil
            if superseded || cancelled {
                if let turnID { sendInterrupt(threadID: threadID, turnID: turnID) }
                continuation.finish()
                if activeStreamID == streamID { clearActive() }
                return
            }

            activeTurnID = turnID
            armTurnTimeout(streamID: streamID)
            // Completion is delivered by the reader loop (turn/completed / error).
        } catch {
            // Only tear down the slot if this run still owns it; a superseded run
            // must not wipe the current one's live state.
            if activeStreamID == streamID {
                clearActive()
            }
            continuation.finish(throwing: error)
        }
    }

    /// The consuming side of `streamID`'s stream terminated (the caller cancelled
    /// or finished iterating). If that stream still owns the slot, interrupt its
    /// turn; a stale termination (already superseded) is ignored.
    private func streamTerminated(_ streamID: Int) {
        guard activeStreamID == streamID else { return }
        interruptActiveSlot()
    }

    /// Requests an interrupt for whatever turn currently owns the slot, finishes
    /// its continuation, and clears the slot. If the turn id isn't known yet
    /// (turn/start still in flight), the interrupt is deferred to the owning run
    /// via `interruptPendingThreadIDs`.
    private func interruptActiveSlot() {
        if let threadID = activeThreadID {
            if let turnID = activeTurnID {
                sendInterrupt(threadID: threadID, turnID: turnID)
            } else {
                interruptPendingThreadIDs.insert(threadID)
            }
        }
        activeContinuation?.finish()
        clearActive()
    }

    private func sendInterrupt(threadID: String, turnID: String) {
        let id = nextID
        nextID += 1
        try? writeMessage(CodexRequest(
            id: id,
            method: "turn/interrupt",
            params: CodexTurnInterruptParams(threadId: threadID, turnId: turnID)))
    }

    private func clearActive() {
        activeStreamID = nil
        activeThreadID = nil
        activeTurnID = nil
        activeContinuation = nil
    }

    /// Force-finishes the active turn if it hasn't completed within the ceiling,
    /// so a silently-stalled stream can't leave the UI generating forever.
    private func armTurnTimeout(streamID: Int) {
        Task { [weak self] in
            try? await Task.sleep(for: Self.turnTimeout)
            await self?.turnTimedOut(streamID: streamID)
        }
    }

    private func turnTimedOut(streamID: Int) {
        guard activeStreamID == streamID, let continuation = activeContinuation else { return }
        if let threadID = activeThreadID, let turnID = activeTurnID {
            sendInterrupt(threadID: threadID, turnID: turnID)
        }
        log.error("codex turn timed out")
        emit(.error, "turn timed out")
        continuation.finish(throwing: ServerError.timedOut)
        clearActive()
    }

    // MARK: - Lifecycle

    private func initializeIfNeeded() async throws {
        try ensureStarted()
        guard !initialized else { return }
        let params = CodexInitializeParams(
            clientInfo: CodexClientInfo(name: "voq-mail", title: "VoqMail", version: "0.1.0"),
            capabilities: CodexInitializeCapabilities(experimentalApi: true, requestAttestation: false))
        _ = try await request(method: "initialize", params: params)
        initialized = true
    }

    private func ensureStarted() throws {
        if let process, process.isRunning { return }

        let process = Process()
        process.executableURL = binary
        process.arguments = ["app-server"]
        let inPipe = Pipe()
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardInput = inPipe
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            throw ServerError.launchFailed(error.localizedDescription)
        }

        self.process = process
        self.stdin = inPipe.fileHandleForWriting
        self.initialized = false
        startReader(outPipe.fileHandleForReading)
        // Drain stderr to the log so handshake/launch failures are diagnosable.
        // Draining (rather than nullDevice) also avoids a full-pipe stall.
        startStderrDrain(errPipe.fileHandleForReading)
        log.info("codex app-server started (pid \(process.processIdentifier))")
        emit(.info, "codex app-server started (pid \(process.processIdentifier))")
    }

    /// Reads stdout and dispatches each newline-framed JSON message into the
    /// actor, in order.
    ///
    /// The blocking reads run on a dedicated GCD queue — NOT the actor and NOT
    /// the Swift cooperative pool. `FileHandle.bytes.lines` proved unreliable
    /// here (it stalled after the first line, and an actor-isolated reader can
    /// occupy the actor's executor on a blocking read, deadlocking a
    /// `runGeneration` that needs the actor to send its next request). Lines flow
    /// through an `AsyncStream` (which preserves yield order) to a lightweight
    /// actor-side consumer that only awaits + hands off — never blocking the
    /// actor. On EOF every waiter is failed so callers don't hang.
    private func startReader(_ handle: FileHandle) {
        let (lines, continuation) = AsyncStream<String>.makeStream()
        DispatchQueue(label: "work.aovoq.voqmail.codex.reader").async {
            Self.pumpLines(from: handle) { continuation.yield($0) }
            continuation.finish()
        }
        readerTask = Task { [weak self] in
            for await line in lines {
                await self?.handleLine(line)
            }
            await self?.handleDisconnect()
        }
    }

    /// Drains stderr to the log (same off-actor blocking-read rationale).
    private func startStderrDrain(_ handle: FileHandle) {
        let log = self.log
        DispatchQueue(label: "work.aovoq.voqmail.codex.stderr").async {
            Self.pumpLines(from: handle) { line in
                guard !line.isEmpty else { return }
                log.debug("codex stderr: \(line, privacy: .public)")
            }
        }
    }

    /// Blocking read loop: accumulates bytes and emits complete `\n`-terminated
    /// lines until the handle reaches EOF (its writer — the child — closed).
    private static func pumpLines(from handle: FileHandle, _ emit: (String) -> Void) {
        var buffer = Data()
        while case let chunk = handle.availableData, !chunk.isEmpty {
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer.subdata(in: buffer.startIndex..<newline)
                buffer = buffer.subdata(in: buffer.index(after: newline)..<buffer.endIndex)
                if let line = String(data: lineData, encoding: .utf8) {
                    emit(line)
                }
            }
        }
    }

    private func handleDisconnect() {
        log.info("codex app-server disconnected")
        emit(.info, "codex app-server disconnected")
        initialized = false
        process = nil
        stdin = nil
        readerTask = nil
        let error = ServerError.launchFailed("codex app-server exited")
        for (_, continuation) in pending {
            continuation.resume(throwing: error)
        }
        pending.removeAll()
        for (_, continuation) in loginContinuations {
            continuation.resume(throwing: error)
        }
        loginContinuations.removeAll()
        activeContinuation?.finish(throwing: error)
        clearActive()
    }

    // MARK: - Message dispatch

    private func handleLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }
        emit(.received, Self.summarize(trimmed))
        guard let message = try? JSONDecoder().decode(CodexIncoming.self, from: data) else {
            log.debug("codex: undecodable line dropped")
            return
        }

        if let id = message.id {
            // A message carrying both id and method is a server-initiated request
            // (e.g. an approval). Drafting turns run read-only with approvals off,
            // so none are expected; reject defensively so the server never blocks.
            if message.method != nil {
                rejectServerRequest(id: id)
            } else if case .int(let intID) = id, let continuation = pending.removeValue(forKey: intID) {
                continuation.resume(returning: message)
            }
            return
        }

        guard let method = message.method else { return }
        switch method {
        case "item/agentMessage/delta":
            if isActive(message), let delta = message.params?.delta {
                activeContinuation?.yield(delta)
            }
        case "turn/completed":
            if isActive(message) {
                activeContinuation?.finish()
                clearActive()
            }
        case "error":
            if isActive(message) {
                let detail = message.params?.errorMessage ?? "Generation failed."
                activeContinuation?.finish(throwing: ServerError.turnFailed(detail))
                clearActive()
            }
        case "account/login/completed":
            handleLoginCompleted(message)
        default:
            break
        }
    }

    private func handleLoginCompleted(_ message: CodexIncoming) {
        let success = message.params?.success ?? false
        let reason = message.params?.errorMessage ?? "Sign-in failed."
        // The notification's loginId may be null; in that case complete whatever
        // login is outstanding (only one runs at a time).
        let ids = message.params?.loginId.map { [$0] } ?? Array(loginContinuations.keys)
        for id in ids {
            guard let continuation = loginContinuations.removeValue(forKey: id) else { continue }
            if success {
                continuation.resume()
            } else {
                continuation.resume(throwing: ServerError.loginFailed(reason))
            }
        }
    }

    /// A rendering of a JSON-RPC message for the debug panel. Capped generously
    /// so full requests/responses stay copyable (only very large streamed blobs
    /// are clipped).
    private static func summarize(_ line: String) -> String {
        line.count > 2000 ? String(line.prefix(2000)) + "…(truncated)" : line
    }

    /// True when a notification belongs to the in-flight drafting turn's thread.
    private func isActive(_ message: CodexIncoming) -> Bool {
        guard let threadID = activeThreadID else { return false }
        return message.params?.threadId == threadID
    }

    private func rejectServerRequest(id: CodexID) {
        struct RPCError: Encodable { let code: Int; let message: String }
        struct ErrorResponse: Encodable {
            let jsonrpc = "2.0"
            let id: CodexID
            let error: RPCError
        }
        try? writeMessage(ErrorResponse(
            id: id,
            error: RPCError(code: -32601, message: "VoqMail grants no approvals")))
    }

    // MARK: - Transport

    @discardableResult
    private func request<Params: Encodable>(
        method: String,
        params: Params,
        timeout: Duration = CodexAppServer.requestTimeout
    ) async throws -> CodexIncoming {
        let id = nextID
        nextID += 1
        try writeMessage(CodexRequest(id: id, method: method, params: params))

        // Time-bound the wait: if the response never arrives, fail this waiter
        // (and drop it from `pending`) instead of suspending forever.
        let timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            if Task.isCancelled { return }
            await self?.timeoutPending(id)
        }
        defer { timeoutTask.cancel() }

        let message: CodexIncoming = try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
        }
        if let error = message.error {
            throw ServerError.protocolError(error.message ?? "RPC error \(error.code ?? 0)")
        }
        return message
    }

    private func timeoutPending(_ id: Int) {
        if let continuation = pending.removeValue(forKey: id) {
            continuation.resume(throwing: ServerError.timedOut)
        }
    }

    private func writeMessage<T: Encodable>(_ value: T) throws {
        guard let stdin else { throw ServerError.launchFailed("codex app-server is not running") }
        var data = try JSONEncoder().encode(value)
        emit(.sent, Self.summarize(String(decoding: data, as: UTF8.self)))
        data.append(0x0A) // newline frames one JSON-RPC message
        try stdin.write(contentsOf: data)
    }
}
