#!/bin/zsh
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/../.." && pwd)"
APP_NAME="SystemOrganizer"
DISPLAY_NAME="System Organizer"
BUNDLE_ID="com.giovannini.SystemOrganizer"
VERSION="2.1.0"
BUILD_VERSION="$(/bin/date +%Y%m%d%H%M%S)"
INSTALL_BUNDLE="/Applications/SystemOrganizer.app"
BACKUP_ROOT="$PROJECT/dist/deploy-backups"
STAGING_ROOT="$PROJECT/dist/deploy"
STAGING_BUNDLE="$STAGING_ROOT/SystemOrganizer.app"
BINARY="$PROJECT/.build/release/$APP_NAME"

require_file() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    echo "Missing required path: $path" >&2
    exit 1
  fi
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
}

print_step() {
  printf '\n== %s ==\n' "$1"
}

verify_host() {
  print_step "Host"
  /usr/bin/sw_vers
  arch="$(/usr/bin/uname -m)"
  echo "Architecture: $arch"
  if [[ "$arch" != "arm64" ]]; then
    echo "This deployment is Apple Silicon only. Refusing to deploy on: $arch" >&2
    exit 1
  fi
}

build_release() {
  print_step "Build"
  cd "$PROJECT"
  require_command swift
  # Scratch outside iCloud Documents avoids Finder xattr codesign failures on *.xctest
  /usr/bin/xcrun swift test --scratch-path /tmp/SystemOrganizer-spm-build
  /usr/bin/xcrun swift build -c release --arch arm64
  /usr/bin/xattr -cr "$PROJECT/.build" 2>/dev/null || true
  require_file "$BINARY"
}

write_info_plist() {
  local plist="$1"
  /bin/cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>26.0</string>
  <key>LSRequiresNativeExecution</key>
  <true/>
  <key>LSUIElement</key>
  <false/>
  <key>NSAppleEventsUsageDescription</key>
  <string>System Organizer runs local AppleScript automations on your behalf.</string>
  <key>NSAppleScriptEnabled</key>
  <true/>
  <key>NSCalendarsFullAccessUsageDescription</key>
  <string>System Organizer reads local calendar events for personal automation.</string>
  <key>NSCalendarsUsageDescription</key>
  <string>System Organizer reads local calendar events for personal automation.</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSUserNotificationsUsageDescription</key>
  <string>System Organizer sends local notifications when automations complete or fail.</string>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
  <key>NSAccessibilityUsageDescription</key>
  <string>System Organizer uses Accessibility to register a global hotkey for quick launch.</string>
</dict>
</plist>
PLIST
  /usr/bin/plutil -lint "$plist" >/dev/null
}

package_bundle() {
  print_step "Package"
  /bin/rm -rf "$STAGING_ROOT"
  /bin/mkdir -p "$STAGING_BUNDLE/Contents/MacOS" "$STAGING_BUNDLE/Contents/Resources"
  /bin/cp "$BINARY" "$STAGING_BUNDLE/Contents/MacOS/$APP_NAME"
  /bin/chmod +x "$STAGING_BUNDLE/Contents/MacOS/$APP_NAME"
  write_info_plist "$STAGING_BUNDLE/Contents/Info.plist"

  if [[ -f "$PROJECT/assets/logo.png" ]]; then
    /bin/cp "$PROJECT/assets/logo.png" "$STAGING_BUNDLE/Contents/Resources/logo.png"
  elif [[ -f "$PROJECT/logo.jpg" ]]; then
    /bin/cp "$PROJECT/logo.jpg" "$STAGING_BUNDLE/Contents/Resources/logo.jpg"
  fi

  /usr/bin/xattr -cr "$STAGING_BUNDLE" 2>/dev/null || true
  /usr/bin/codesign --force --deep --sign - "$STAGING_BUNDLE" >/dev/null
  /usr/bin/codesign --verify --deep --strict "$STAGING_BUNDLE"
  echo "Staged bundle: $STAGING_BUNDLE"
}

stop_running_app() {
  if /usr/bin/pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    print_step "Stop Running App"
    /usr/bin/osascript -e 'tell application "System Organizer" to quit' >/dev/null 2>&1 || true
    sleep 2
    if /usr/bin/pgrep -x "$APP_NAME" >/dev/null 2>&1; then
      /usr/bin/pkill -x "$APP_NAME" || true
      sleep 1
    fi
  fi
}

install_bundle() {
  print_step "Install"
  /bin/mkdir -p "$BACKUP_ROOT"
  if [[ -d "$INSTALL_BUNDLE" ]]; then
    backup="$BACKUP_ROOT/SystemOrganizer.app.bak-$BUILD_VERSION"
    /bin/rm -rf "$backup"
    /bin/mv "$INSTALL_BUNDLE" "$backup"
    echo "Existing app backup: $backup"
  fi
  /usr/bin/ditto "$STAGING_BUNDLE" "$INSTALL_BUNDLE"
  /usr/bin/xattr -cr "$INSTALL_BUNDLE" 2>/dev/null || true
  /usr/bin/codesign --verify --deep --strict "$INSTALL_BUNDLE"
  /usr/bin/xattr -dr com.apple.quarantine "$INSTALL_BUNDLE" 2>/dev/null || true
  echo "Installed: $INSTALL_BUNDLE"
}

install_live_config() {
  print_step "Live Configuration"
  "$PROJECT/scripts/SystemOrganizer/configure_system_organizer.sh"
}

launch_and_verify() {
  print_step "Launch"
  /usr/bin/open "$INSTALL_BUNDLE"
  sleep 4
  if ! /usr/bin/pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    echo "SystemOrganizer did not start." >&2
    exit 1
  fi
  echo "SystemOrganizer is running."
}

final_report() {
  print_step "Deploy Report"
  echo "App bundle: $INSTALL_BUNDLE"
  echo "Version: $VERSION ($BUILD_VERSION)"
  echo "Architecture: $(/usr/bin/file "$INSTALL_BUNDLE/Contents/MacOS/$APP_NAME")"
  echo "Process: $(/usr/bin/pgrep -x "$APP_NAME" | /usr/bin/tr '\n' ' ')"
  echo "Ollama: $(/usr/bin/curl -s http://localhost:11434/api/tags >/dev/null 2>&1 && echo online || echo offline)"
  echo "Repo health:"
  "$PROJECT/scripts/SystemOrganizer/repo_health_check.sh"
}

verify_host
build_release
package_bundle
stop_running_app
install_bundle
install_live_config
launch_and_verify
final_report
