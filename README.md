# voq-mail

A lightweight SwiftUI macOS app scaffold: a single-window mail UI with a
collapsible sidebar, a custom translucent sidebar material, and a curved seam
between the sidebar and the detail pane.

## Run it

```sh
./script/build_and_run.sh
```

The script builds with SwiftPM, assembles a `.app` bundle under `dist/`, writes
an `Info.plist`, and launches the app. Other modes: `debug`, `logs`,
`telemetry`, `verify` (see the script).

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

## Adding things

- A new mailbox or message: edit `Models/SampleData.swift`.
- A layout/spacing/color tweak: change the named token in
  `DesignSystem/Constants.swift` (one edit updates every call site).
- A new detail view: add it under `Views/Detail/` and show it from `MailSplitView`.
