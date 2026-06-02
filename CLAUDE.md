# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`voq-mail` is a native macOS (14+) multi-account Gmail client written in SwiftUI
+ AppKit, built as a single SwiftPM executable target (`VoqMail`). No Google SDK,
no third-party dependencies — Gmail is reached via raw REST over `URLSession`,
and OAuth runs a hand-rolled PKCE flow.

## Build & run

```sh
./script/build_and_run.sh            # build → assemble .app → sign → launch
./script/build_and_run.sh logs       # launch + stream os_log (process predicate)
./script/build_and_run.sh telemetry  # launch + stream os_log (subsystem = bundle id)
./script/build_and_run.sh debug      # run under lldb
./script/build_and_run.sh verify     # launch and assert the process is alive
./script/build_and_run.sh sign-info  # print signing authority + designated requirement
```

`swift build` alone compiles, but the app **must** run from the assembled,
code-signed `.app` bundle the script produces (under `dist/`) — a bare SwiftPM
binary has no `Info.plist`, so it lacks the activation policy, the OAuth
redirect URL scheme, and a stable Keychain ACL.

There is **no test target** — `swift test` does nothing. Verify changes by
running the app (`build_and_run.sh verify` / `logs`).

## Code signing matters here (don't change the identity)

The app stores OAuth **refresh tokens** in the login Keychain. A Keychain item's
ACL binds to the signing app's *designated requirement*, which includes the Team
ID. Ad-hoc signing changes the code hash every build and orphans saved tokens
(forcing a weekly-or-worse re-login). So the script signs with a **stable
identity** (`Developer ID Application: ao hirata (XDZ7L87T5C)`, a personal-team
cert). Switching identity changes the Team ID and orphans every existing
Keychain item. Override only via `CODE_SIGN_IDENTITY=…` and only deliberately.

`OAUTH_REDIRECT_SCHEME` in the script (the reversed client ID, written into
`Info.plist`'s `CFBundleURLTypes`) must stay in sync with
`OAuthConfiguration.redirectScheme`.

## Architecture

The app is a one-window split layout (sidebar + detail) driven by a small set of
`@Observable @MainActor` stores, fed by stateless service structs that talk to
Google. Data flows: **Services** (network/keychain) → **Stores** (observable UI
state) → **Views**.

### Stores — `Sources/VoqMail/Stores/`, injected via `.environment(...)`

All five are constructed once in `VoqMailApp` and passed down through
`ContentView`. The central design constraint is **everything is partitioned by
account id** (issue #8): each store keeps per-account dictionaries so switching
accounts never lets one account's late network response surface on — or stomp —
another's state.

- `AccountStore` — the signed-in accounts the UI observes; owns add/restore.
- `LabelStore` — Gmail labels → sidebar `Mailbox` rows, per account. Owns its
  load `Task`s itself (not a view's `.task`) so a re-render can't cancel a load
  and leave an account stuck empty.
- `MailStore` — per-account message-list state (messages, paging cursor, load
  generation). Computed `messages`/`isLoading`/… reflect the *active* account.
- `MessageContentStore` — the one open message's HTML body + attachments.
- `SidebarModel` — sidebar collapse/expand + width (pure UI, no network).

Two recurring concurrency patterns to preserve when editing stores:
- **Load generation counters** — bumped on each load/purge; a suspended `await`
  checks its captured generation before writing, so stale results are dropped.
- **Whole-value writes** — per-account state is held as one struct written back
  as `statesByAccount[id] = s`; `@Observable` won't fire on a mutation two levels
  deep, so never mutate a nested field in place.

### Services — `Sources/VoqMail/Services/`, stateless structs (+ one actor)

- OAuth/PKCE: `PKCE` → `GoogleOAuthClient` (builds auth URL, exchanges/refreshes
  codes) + `WebAuthenticationSession` (ASWebAuthenticationSession consent sheet).
  `AccountAuthenticator` sequences the whole add-account flow:
  PKCE → consent → code exchange → profile fetch → Keychain save.
- `TokenProvider` is an **actor** (the one stateful service): the shared source
  of valid access tokens. Access tokens live only in memory, keyed by email;
  refresh tokens are read from `KeychainTokenStore` on demand. Every Gmail call
  gets its token here.
- `GmailClient` — thin Gmail REST client; stateless, every call takes a bearer
  token. `messages.list` returns ids only, so list rows fan out a per-message
  `messages.get` through a **bounded-concurrency window** (not the batch
  endpoint) to respect per-user rate limits.
- `KeychainTokenStore` — one generic-password item per account (service = bundle
  id, account = email). The set of stored items **is** the account list restored
  on launch; no separate persisted account list exists.
- `MimeParser` — assembles the HTML body and inline `cid:` images from a Gmail
  message payload.

### Views & design system

- `Views/MainLayout/MailSplitView.swift` is the heart of the layout: a 5-layer
  ZStack (sidebar, seam fill, detail, border, toggle) documented in its `body`.
- `DesignSystem/Constants.swift` holds every tunable number as a named token —
  edit the token, not the call sites.
- `DesignSystem/SidebarColorCalibration.swift` is an empirically calibrated Core
  Image filter chain. Its float constants are exact on purpose — **treat it as
  read-only** unless re-deriving the look.
- `Sources/VoqMail/Reference/` is example code the running app does **not** use.
  Don't wire it up; it's there to learn from.

## OAuth / Gmail config

`Services/OAuthConfiguration.swift` holds the `clientID`, `redirectScheme`,
`redirectURI`, and `scopes` (`gmail.modify`, `gmail.send`, `openid`/`email`/
`profile`). The client is an **iOS** (public) type with no secret, so the
`clientID` is non-sensitive and committed. The project runs in OAuth **Testing**
mode: only registered test-user accounts can sign in, the consent screen shows an
"unverified app" warning, and **refresh tokens expire after 7 days** (weekly
re-auth until moved to Production).

## Workflow conventions

Development is issue-driven: work lands as small, single-purpose branches
(`feat/…`, `fix/…`) merged via PR, each commit referencing a GitHub issue (e.g.
"issue #8"). Issue numbers appear throughout the code comments as rationale
anchors — when touching per-account partitioning, the curved seam, or token
storage, the relevant issue explains *why* the code is shaped that way.
