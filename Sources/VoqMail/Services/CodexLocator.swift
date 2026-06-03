//
//  CodexLocator.swift
//  VoqMail
//
//  Finds the user's installed `codex` CLI so VoqMail can drive its
//  `codex app-server` subcommand for AI reply drafting. The binary is NOT
//  bundled (it is ~187MB and bundling would force inside-out signing +
//  notarization and bloat the .app ~90x); VoqMail detects the system install
//  instead, matching the BYO approach documented in the codex integration plan.
//
//  The crux: a GUI .app launched from Finder does NOT inherit the user's shell
//  PATH, so a bare `which codex` is useless from inside the running app. So we
//  probe the known absolute install locations first, then fall back to a login
//  shell (`/bin/zsh -lc 'command -v codex'`) which DOES source the profile.
//

import Foundation

/// A located `codex` binary plus its parsed version.
struct CodexInstall: Equatable {
    let url: URL
    let version: SemanticVersion
}

/// The minimal three-part version we compare against the app-server floor.
struct SemanticVersion: Comparable, CustomStringConvertible, Equatable {
    let major: Int
    let minor: Int
    let patch: Int

    var description: String { "\(major).\(minor).\(patch)" }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    /// Parses the trailing `x.y.z` out of strings like `codex-cli 0.136.0` or
    /// `0.136.0 (…)`. Returns nil if no three-part version is present.
    init?(parsing raw: String) {
        // Grab the first run of digits-dots-digits and split it.
        let scalars = raw.unicodeScalars
        var current = ""
        var candidate: String?
        for scalar in scalars {
            if CharacterSet(charactersIn: "0123456789.").contains(scalar) {
                current.unicodeScalars.append(scalar)
            } else {
                if current.contains(".") { candidate = current; break }
                current = ""
            }
        }
        if candidate == nil, current.contains(".") { candidate = current }
        guard let token = candidate else { return nil }
        let parts = token.split(separator: ".").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        major = parts[0]
        minor = parts[1]
        patch = parts.count > 2 ? parts[2] : 0
    }

    init(_ major: Int, _ minor: Int, _ patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
}

enum CodexLocator {
    /// The app-server protocol floor. Below this the v2 thread/turn methods this
    /// client speaks aren't guaranteed present, so we refuse rather than fail
    /// opaquely mid-stream.
    static let minimumVersion = SemanticVersion(0, 125, 0)

    /// Why a locate attempt failed, phrased for a human-facing hint.
    enum Failure: Error, Equatable {
        case notFound
        case versionUnreadable(URL)
        case tooOld(found: SemanticVersion, required: SemanticVersion)
    }

    /// Absolute paths checked before falling back to a login shell. Order:
    /// official install.sh default, Homebrew (Apple silicon), Homebrew/manual
    /// (Intel / `/usr/local`).
    private static var candidatePaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/.local/bin/codex",       // official install.sh default
            "/opt/homebrew/bin/codex",        // Homebrew (Apple silicon)
            "/usr/local/bin/codex",           // Homebrew / manual (Intel)
            "\(home)/.cargo/bin/codex",       // cargo install
            "\(home)/bin/codex",              // common personal bin
        ]
    }

    /// Locates codex and verifies it meets the version floor. Runs blocking
    /// `Process` work, so call it off the main actor (the store hops to a
    /// background task).
    static func locate() throws -> CodexInstall {
        guard let url = resolveBinary() else { throw Failure.notFound }
        guard let raw = try? versionOutput(of: url),
              let version = SemanticVersion(parsing: raw) else {
            throw Failure.versionUnreadable(url)
        }
        guard version >= minimumVersion else {
            throw Failure.tooOld(found: version, required: minimumVersion)
        }
        return CodexInstall(url: url, version: version)
    }

    /// First existing absolute candidate, else whatever a login shell resolves.
    static func resolveBinary() -> URL? {
        let fileManager = FileManager.default
        for path in candidatePaths where fileManager.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return loginShellLookup()
    }

    /// `$SHELL -lc 'command -v codex'` — a login shell sources the user's
    /// profile, recovering a PATH the Finder-launched app never inherited. Honors
    /// the user's actual login shell (`$SHELL`), falling back to zsh (the macOS
    /// default) when it isn't set or isn't executable.
    private static func loginShellLookup() -> URL? {
        let shellPath = ProcessInfo.processInfo.environment["SHELL"]
        let shell = (shellPath.map { FileManager.default.isExecutableFile(atPath: $0) } == true)
            ? shellPath!
            : "/bin/zsh"
        guard let output = try? runCapturing(
            URL(fileURLWithPath: shell),
            arguments: ["-lc", "command -v codex"]
        ) else { return nil }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, FileManager.default.isExecutableFile(atPath: trimmed) else {
            return nil
        }
        return URL(fileURLWithPath: trimmed)
    }

    private static func versionOutput(of url: URL) throws -> String {
        try runCapturing(url, arguments: ["--version"])
    }

    /// Runs a process to completion and returns its stdout. A small helper kept
    /// here (not shared) since detection is the only blocking-process caller.
    private static func runCapturing(_ url: URL, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = url
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        // Discard stderr to a sink that can't fill (an unread Pipe could stall
        // the child if it wrote enough to stderr).
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
