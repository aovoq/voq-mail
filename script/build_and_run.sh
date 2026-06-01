#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="VoqMail"
BUNDLE_ID="work.aovoq.voqmail"
MIN_SYSTEM_VERSION="14.0"
SHORT_VERSION="0.1.0"
BUILD_VERSION="1"
# Stable code-signing identity (issue #2). A stable identity keeps the app's
# designated requirement constant across rebuilds, so Keychain items created by
# the app (OAuth refresh tokens) stay readable instead of being orphaned every
# build — which is what ad-hoc signing (changing cdhash) does.
#
# Defaults to the personal-team Developer ID; override with CODE_SIGN_IDENTITY.
# WARNING: switching identity changes the Team ID in the designated requirement,
# which orphans existing Keychain items (one-time re-login). Pick one and keep it.
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-Developer ID Application: ao hirata (XDZ7L87T5C)}"
# Reversed client ID of the iOS OAuth client (issue #1). Registered below as a
# custom URL scheme so ASWebAuthenticationSession can receive the redirect.
# Mirror of OAuthConfiguration.redirectScheme — keep the two in sync.
OAUTH_REDIRECT_SCHEME="com.googleusercontent.apps.1023809986523-4os0v0qhf63kp1l25k1ifotj88fcltgb"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

cd "$ROOT_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$SHORT_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key>
      <string>$BUNDLE_ID.oauth</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>$OAUTH_REDIRECT_SCHEME</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
PLIST

# Sign the finished bundle with the stable identity. Must run after the binary
# and Info.plist are in place, since the signature seals the whole bundle.
codesign --force --identifier "$BUNDLE_ID" --sign "$CODE_SIGN_IDENTITY" "$APP_BUNDLE"
# Fail the build loudly if the signature is not valid/stable.
codesign --verify --strict "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --sign-info|sign-info)
    # Print the signing authority and designated requirement. The team ID in the
    # requirement is what Keychain ACLs bind to; it must stay constant across
    # rebuilds for saved tokens to remain readable.
    codesign -dv --verbose=4 "$APP_BUNDLE" 2>&1 | grep -Ei "authority|identifier|teamident"
    echo "--- designated requirement ---"
    codesign -d --requirements - "$APP_BUNDLE" 2>&1 | tail -1
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--sign-info]" >&2
    exit 2
    ;;
esac
