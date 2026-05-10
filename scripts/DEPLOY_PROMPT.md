# System Organizer — Desktop Commander Deploy Prompt

> Copy everything inside the box below and paste it directly into Desktop Commander.

---

```
You are deploying "System Organizer", a native macOS SwiftUI app located at:
/Users/eduardofgiovannini/Documents/Active_Projects/System_Org

Execute every step below in order. After each step, confirm it succeeded before
continuing. If a step fails, report the exact error and stop.

─────────────────────────────────────────────────────────────
STEP 1 — VERIFY PREREQUISITES
─────────────────────────────────────────────────────────────
Run these checks and report the results:

  xcode-select --print-path
  swift --version
  brew --version
  git -C /Users/eduardofgiovannini/Documents/Active_Projects/System_Org log --oneline -1

If Xcode command-line tools are missing, run:
  xcode-select --install

─────────────────────────────────────────────────────────────
STEP 2 — INSTALL & START OLLAMA
─────────────────────────────────────────────────────────────
Check if Ollama is installed:
  which ollama

If NOT installed:
  brew install ollama

Start the Ollama background service:
  brew services start ollama

Wait 3 seconds, then verify it is running:
  curl -s http://localhost:11434/api/tags | python3 -m json.tool

Pull the default AI model (this may take a few minutes on first run):
  ollama pull llama3.2

Confirm the model is available:
  ollama list

─────────────────────────────────────────────────────────────
STEP 3 — BUILD THE APP
─────────────────────────────────────────────────────────────
Navigate to the project:
  cd /Users/eduardofgiovannini/Documents/Active_Projects/System_Org

Clean any previous build artifacts:
  rm -rf .build

Build in release mode:
  swift build -c release 2>&1

If the build succeeds you will see:
  Build complete!

If it fails, report the full compiler error output and stop.

─────────────────────────────────────────────────────────────
STEP 4 — CREATE THE APP BUNDLE
─────────────────────────────────────────────────────────────
Run this entire block as one script:

  PROJECT=/Users/eduardofgiovannini/Documents/Active_Projects/System_Org
  BINARY=$PROJECT/.build/release/SystemOrganizer
  BUNDLE=/Applications/SystemOrganizer.app
  MACOS=$BUNDLE/Contents/MacOS
  RESOURCES=$BUNDLE/Contents/Resources

  # Remove old bundle if present
  rm -rf "$BUNDLE"

  # Create bundle structure
  mkdir -p "$MACOS" "$RESOURCES"

  # Copy binary
  cp "$BINARY" "$MACOS/SystemOrganizer"
  chmod +x "$MACOS/SystemOrganizer"

  # Write Info.plist
  cat > "$BUNDLE/Contents/Info.plist" << 'PLIST'
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
      <key>CFBundleIdentifier</key>
      <string>com.autogio.systemorganizer</string>
      <key>CFBundleName</key>
      <string>System Organizer</string>
      <key>CFBundleDisplayName</key>
      <string>System Organizer</string>
      <key>CFBundleExecutable</key>
      <string>SystemOrganizer</string>
      <key>CFBundleVersion</key>
      <string>2.0.0</string>
      <key>CFBundleShortVersionString</key>
      <string>2.0</string>
      <key>CFBundlePackageType</key>
      <string>APPL</string>
      <key>CFBundleIconFile</key>
      <string>AppIcon</string>
      <key>LSMinimumSystemVersion</key>
      <string>13.0</string>
      <key>LSUIElement</key>
      <false/>
      <key>NSPrincipalClass</key>
      <string>NSApplication</string>
      <key>NSHighResolutionCapable</key>
      <true/>
      <key>NSSupportsAutomaticGraphicsSwitching</key>
      <true/>
      <key>NSCalendarsUsageDescription</key>
      <string>System Organizer reads your calendar to display and automate events.</string>
      <key>NSUserNotificationsUsageDescription</key>
      <string>System Organizer sends notifications when automations complete or fail.</string>
      <key>NSAppleEventsUsageDescription</key>
      <string>System Organizer runs AppleScript automations on your behalf.</string>
      <key>NSAppleScriptEnabled</key>
      <true/>
  </dict>
  </plist>
  PLIST

  echo "✅ Bundle created at $BUNDLE"

─────────────────────────────────────────────────────────────
STEP 5 — GRANT PERMISSIONS
─────────────────────────────────────────────────────────────
Open System Settings so the user can grant required permissions.
Run these one at a time:

  # Calendar access
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"

  # Notifications
  open "x-apple.systempreferences:com.apple.preference.notifications"

  # Accessibility (required for global hotkey ⌘⌥Space)
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

Tell the user:
  "Please add System Organizer to the allowed list in each Privacy panel that opened,
   then press Enter here to continue."

Wait for user confirmation before proceeding.

─────────────────────────────────────────────────────────────
STEP 6 — LAUNCH THE APP
─────────────────────────────────────────────────────────────
Open the app:
  open /Applications/SystemOrganizer.app

Wait 3 seconds, then verify it is running:
  pgrep -x SystemOrganizer && echo "✅ SystemOrganizer is running" || echo "❌ Not running"

─────────────────────────────────────────────────────────────
STEP 7 — VERIFY OLLAMA IS REACHABLE FROM THE APP
─────────────────────────────────────────────────────────────
Confirm the API is responding on localhost:
  curl -s http://localhost:11434/api/tags | python3 -c "
  import sys, json
  data = json.load(sys.stdin)
  models = [m['name'] for m in data.get('models', [])]
  print('✅ Ollama online — models:', ', '.join(models) if models else 'none pulled yet')
  "

If no models are listed, run:
  ollama pull llama3.2

─────────────────────────────────────────────────────────────
STEP 8 — FINAL STATUS REPORT
─────────────────────────────────────────────────────────────
After all steps complete, print this summary:

  echo "================================================"
  echo "  System Organizer — Deploy Report"
  echo "================================================"
  echo "App bundle :  $(ls -d /Applications/SystemOrganizer.app 2>/dev/null && echo OK || echo MISSING)"
  echo "Running    :  $(pgrep -x SystemOrganizer > /dev/null && echo YES || echo NO)"
  echo "Ollama     :  $(curl -s http://localhost:11434/api/tags > /dev/null 2>&1 && echo ONLINE || echo OFFLINE)"
  echo "Models     :  $(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | tr '\n' ' ')"
  echo "Git HEAD   :  $(git -C /Users/eduardofgiovannini/Documents/Active_Projects/System_Org log --oneline -1)"
  echo "================================================"

Deploy complete. The app is ready to use.
```
