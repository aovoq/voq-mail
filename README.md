# voq-mail

A lightweight SwiftUI macOS app scaffold: a single-window mail UI with a
collapsible sidebar, a custom translucent sidebar material, and a curved seam
between the sidebar and the detail pane.

## Run it

```sh
./script/build_and_run.sh
```

The script builds with SwiftPM, assembles a `.app` bundle under `dist/`, writes
an `Info.plist`, code-signs the bundle, and launches the app. Other modes:
`debug`, `logs`, `telemetry`, `verify`, `sign-info` (see the script).

## Code signing

The app stores OAuth refresh tokens in the Keychain. A Keychain item's ACL is
bound to the signing app's *designated requirement*, which includes the Team ID.
Ad-hoc signing changes the code hash on every build, orphaning saved tokens and
forcing a re-login each rebuild. So `build_and_run.sh` signs with a **stable
identity** instead.

- **Default identity:** `Developer ID Application: ao hirata (XDZ7L87T5C)` — a
  *personal*-team certificate, chosen so it can't be revoked by an employer and
  so it stays usable if we later notarize for distribution.
- **Prerequisite:** that signing certificate must exist in your login Keychain.
  Check with `security find-identity -v -p codesigning`. If you need one, create
  it via Xcode (Settings → Accounts → Manage Certificates → +) or download it
  from the Apple Developer portal, then import into Keychain Access.
- **Override:** set `CODE_SIGN_IDENTITY="…"` to sign with a different identity.
- **Do not switch identities mid-project.** A different identity means a
  different Team ID in the designated requirement, which orphans existing
  Keychain items (one-time re-login). Pick one and keep it.
- **Verify stability:** `./script/build_and_run.sh sign-info` prints the signing
  authority and designated requirement. The requirement (and its Team ID) must
  stay identical across rebuilds for saved tokens to remain readable. The full
  Keychain round-trip is exercised once token storage lands (issue #3).

## Where things live

Everything is one SwiftPM target (`VoqMail`). The source is grouped by role so a
newcomer can find things without opening every file:

```
Sources/VoqMail/
├── App/              App entry point and root view
│   ├── VoqMailApp.swift        @main; window size & lifecycle
│   └── ContentView.swift       root view; attaches window chrome
├── Models/           Plain data types + demo data
│   ├── Mailbox.swift           a sidebar folder
│   ├── MailMessage.swift       a single message
│   └── SampleData.swift        the .samples placeholder data
├── DesignSystem/     Shared visual building blocks
│   ├── Constants.swift             named layout/motion/color tokens
│   ├── SplitSurfaceShapes.swift    the curved-seam Shapes
│   ├── SidebarColorCalibration.swift  the sidebar tint filter pipeline
│   └── VisualEffectBackground.swift   NSVisualEffectView bridge
├── Views/            The on-screen UI
│   ├── MainLayout/MailSplitView.swift   the 5-layer split layout
│   ├── Sidebar/                          mailbox list, rows, toggle button
│   └── Detail/                           detail-pane content views
├── AppKitBridge/     AppKit interop
│   └── WindowChromeConfigurator.swift   titlebar + traffic-light setup
└── Reference/        Example code NOT used by the running app
    ├── DemoViews.swift          two- and three-column example layouts
    └── SidebarList.swift        a native-List sidebar alternative
```

## Start reading here

1. **`App/VoqMailApp.swift` → `App/ContentView.swift`** — how the app boots.
2. **`Views/MainLayout/MailSplitView.swift`** — the heart of the layout. Its
   `body` documents the five ZStack layers (sidebar, seam fill, detail, border,
   toggle) and how they animate when the sidebar collapses.
3. **`DesignSystem/Constants.swift`** — every tunable number (sidebar width,
   corner radius, animation curves, colors, window size) with a name and a note.

## Things worth knowing

- **The curved seam** between sidebar and detail is drawn by three `Shape`s in
  `SplitSurfaceShapes.swift`. They share their corner math via `SidebarSeam` and
  animate via `animatableData` so the seam stays smooth during collapse/expand.
- **The sidebar tint** in `SidebarColorCalibration.swift` is an empirically
  calibrated Core Image filter chain. The float constants are exact on purpose —
  treat that file as read-only unless you are re-deriving the look.
- **Window chrome** (hidden titlebar, transparent background, repositioned
  traffic lights) is configured in `AppKitBridge/WindowChromeConfigurator.swift`.
- **`Reference/`** holds example layouts that the running app does not use; they
  are there to learn from, not to wire up.

## Gmail / OAuth setup

Gmail access uses a Google Cloud OAuth client (project setup tracked in issue
#1). The client is **External** type and runs in **Testing** mode.

- **Client type: iOS** — a *public* client with no client secret. The PKCE flow
  runs through `ASWebAuthenticationSession`.
- **Where the settings live:** `Sources/VoqMail/Services/OAuthConfiguration.swift`
  holds the `clientID`, the reversed-client-ID `redirectScheme`, the `redirectURI`,
  and the requested `scopes` (`gmail.modify`, `gmail.send`, `openid`/`email`/`profile`).
- **Secret handling:** because an iOS client has no secret, the `clientID` is not
  sensitive and is committed to the repo. Nothing secret is stored here.
- **Redirect scheme:** the reversed client ID is registered as a custom URL scheme
  in the app's `Info.plist` (`CFBundleURLTypes`). `build_and_run.sh` writes it from
  `OAUTH_REDIRECT_SCHEME`, which must stay in sync with
  `OAuthConfiguration.redirectScheme`.

**Testing-mode constraints (accepted for now):**

- The consent screen shows an "unverified app" warning. Only registered test
  users (every Gmail account we use, including personal `@gmail.com`) can sign in.
- **Refresh tokens expire after 7 days.** Re-auth will be needed weekly until the
  app is moved to Production. Token-expiry handling is a separate slice.

## Adding things

- A new mailbox or message: edit `Models/SampleData.swift`.
- A layout/spacing/color tweak: change the named token in
  `DesignSystem/Constants.swift` (one edit updates every call site).
- A new detail view: add it under `Views/Detail/` and show it from `MailSplitView`.
