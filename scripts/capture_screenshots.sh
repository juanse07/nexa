#!/usr/bin/env bash
#
# capture_screenshots.sh — FlowShift Manager
#
# Boots iOS simulators, sets clean status bars, runs screenshot
# integration tests, and organizes output into screenshots/store/.
#
# Usage:
#   ./scripts/capture_screenshots.sh          # All devices
#   ./scripts/capture_screenshots.sh ios      # iOS only
#   ./scripts/capture_screenshots.sh android  # Android only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCREENSHOTS_DIR="$PROJECT_DIR/screenshots/store"

# iOS simulator names (App Store requirements)
IOS_DEVICES=(
  "iPhone 15 Pro Max"
  "iPhone 15 Pro"
  "iPad Pro 12.9-inch (6th generation)"
)

# ── Helpers ────────────────────────────────────────────────────────────

log() { echo "📸 $*"; }
err() { echo "❌ $*" >&2; }

setup_ios_statusbar() {
  local device="$1"
  xcrun simctl status_bar "$device" override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --cellularMode active \
    --cellularBars 4 \
    --wifiBars 3 \
    --operatorName "" 2>/dev/null || true
}

clear_ios_statusbar() {
  local device="$1"
  xcrun simctl status_bar "$device" clear 2>/dev/null || true
}

# ── iOS Screenshots ───────────────────────────────────────────────────

capture_ios() {
  log "Starting iOS screenshot capture..."

  for device in "${IOS_DEVICES[@]}"; do
    local device_dir="$SCREENSHOTS_DIR/$device"
    mkdir -p "$device_dir"

    log "Booting $device..."
    xcrun simctl boot "$device" 2>/dev/null || true
    sleep 2

    log "Setting clean status bar on $device..."
    setup_ios_statusbar "$device"

    log "Running screenshot tests on $device..."
    cd "$PROJECT_DIR"
    flutter test integration_test/screenshots/screenshot_test.dart \
      -d "$device" \
      --dart-define=SCREENSHOT_MODE=true \
      || err "Test run failed on $device (continuing)"

    log "Clearing status bar on $device..."
    clear_ios_statusbar "$device"

    log "✅ Done with $device"
  done

  log "All iOS screenshots captured in $SCREENSHOTS_DIR"
}

# ── Android Screenshots ───────────────────────────────────────────────

capture_android() {
  log "Starting Android screenshot capture..."

  # Check for connected Android devices/emulators
  if ! command -v adb &>/dev/null; then
    err "adb not found. Install Android SDK or set ANDROID_HOME."
    return 1
  fi

  local connected
  connected=$(adb devices | grep -c "device$" || true)
  if [[ "$connected" -eq 0 ]]; then
    err "No Android devices connected. Start an emulator first."
    return 1
  fi

  # Set demo mode
  adb shell settings put global sysui_demo_allowed 1
  adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941
  adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
  adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4
  adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false

  log "Running screenshot tests on connected Android device..."
  cd "$PROJECT_DIR"
  flutter test integration_test/screenshots/screenshot_test.dart \
    -d "$(adb devices | grep 'device$' | head -1 | awk '{print $1}')" \
    --dart-define=SCREENSHOT_MODE=true \
    || err "Android test run failed (continuing)"

  # Exit demo mode
  adb shell am broadcast -a com.android.systemui.demo -e command exit

  log "✅ Android screenshots captured"
}

# ── Main ──────────────────────────────────────────────────────────────

mkdir -p "$SCREENSHOTS_DIR"

case "${1:-all}" in
  ios)     capture_ios ;;
  android) capture_android ;;
  all)
    capture_ios
    capture_android
    ;;
  *)
    echo "Usage: $0 [ios|android|all]"
    exit 1
    ;;
esac

log "🎉 Screenshot capture complete! Output: $SCREENSHOTS_DIR"
