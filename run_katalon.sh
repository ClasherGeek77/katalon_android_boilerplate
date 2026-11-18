#!/bin/bash
# runs the mobile suite through the offline Katalon KRE, which drives the
# LOCAL appium 2.11.5 (uiautomator2@4.2.9) against the android9 AVD.
# device + appium are prepared here first, one JVM at a time
cd "$(dirname "$0")"

SUITE="${1:-Test Suites/android/android_smoke}"
mkdir -p ~/katalon_cli_runs
TS=$(date +%Y-%m-%d_%H-%M-%S)
LOG="$HOME/katalon_cli_runs/android-$TS.log"

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
# the appium server of this stack wants a JDK 8, point JAVA_HOME_8 at yours
export JAVA_HOME="${JAVA_HOME_8:-$HOME/Library/Java/jdk8u512-b09/Contents/Home}"
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
# KRE resolves its appium dir through APPIUM_HOME + the android settings file:
# appium 1.22.3 tree (~/.katalon_appium1, ui2 driver 1.75.0, ui2-server 4.29.1)
# behind the shim (~/.katalon_appium_shim) that strips KRE's bogus
# --webkit-debug-proxy-port 0. appium1 listens on a KRE-chosen random port, so
# no clash with the appium 2 stack on 4723.
export APPIUM_HOME="$HOME/.katalon_appium_shim"

# the emulator: boot it when dark, same lean flags as the pytest twin
if ! "$ANDROID_HOME/platform-tools/adb" devices | grep -q "emulator-.*device"; then
    echo "booting android9 (cold boot about 90 s)"
    nohup "$ANDROID_HOME/emulator/emulator" -avd "${AVD_NAME:-android9}" -gpu host \
        -no-boot-anim -memory 1536 -no-snapshot-save \
        >> "${TMPDIR:-/tmp}/android-emulator.log" 2>&1 &
    for _ in $(seq 1 36); do
        [ "$("$ANDROID_HOME/platform-tools/adb" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && break
        sleep 5
    done
fi

# the settings file KRE reads is machine specific (appium dir), so it is written
# here from $HOME and git-ignored
mkdir -p settings/internal
cat > settings/internal/com.kms.katalon.core.mobile.android.properties <<JSON
{
 "ANDROID_DRIVER": {
  "autoGrantPermissions": true,
  "androidInstallTimeout": 300000.0,
  "appWaitActivity": "*",
  "appWaitDuration": 30000.0,
  "autoLaunch": true,
  "appPackage": "com.ted.ted_mobile_app_test",
  "appActivity": ".MainActivity",
  "chromedriverExecutableDir": "chrome_drivers",
  "chromedriverChromeMappingFile": "chrome_drivers/mapping.json",
  "newCommandTimeout": 1800.0,
  "deviceId": "emulator-5554",
  "appiumPath": "$APPIUM_HOME",
  "executionMode": "Local installation",
  "appiumDirectory": "$APPIUM_HOME"
 }
}
JSON

# the a11y enabler must be installed and enabled or the flutter tree is invisible
# (see the README, "why an enabler apk"); settings persist across boots, this just re-asserts
if ! "$ANDROID_HOME/platform-tools/adb" shell pm list packages | grep -q net.ted.a11yenabler; then
    [ -f apps/a11y-enabler.apk ] || ./fetch_app.sh
    "$ANDROID_HOME/platform-tools/adb" install -r apps/a11y-enabler.apk >/dev/null
fi
"$ANDROID_HOME/platform-tools/adb" shell settings put secure enabled_accessibility_services net.ted.a11yenabler/.Enabler
"$ANDROID_HOME/platform-tools/adb" shell settings put secure accessibility_enabled 1

# KRE starts its OWN appium: free the port from the pytest-side server first
pkill -f "appium --port 4723" 2>/dev/null || true
# clear appium-1 servers orphaned by a killed parent (a stale ui2 session
# holds the package and wedges the next streamed install)
pkill -f "katalon_appium" 2>/dev/null || true

# the app comes from the release (./fetch_app.sh), not from a local build
APK="$(pwd)/apps/ted_mobile_app_test-v1.0.0-debug.apk"
[ -f "$APK" ] || ./fetch_app.sh

# the app must exist for the replace install; the SDK adb streams this
# 59 MB apk far more reliably than KRE's bundled one
if ! "$ANDROID_HOME/platform-tools/adb" shell pm path com.ted.ted_mobile_app_test >/dev/null 2>&1; then
    "$ANDROID_HOME/platform-tools/adb" install -r -g \
        "$APK" \
        >/dev/null 2>&1 || true
fi

echo "running $SUITE -> $LOG"
# optional live progress watcher, point KATALON_WATCH at any script that takes the log path
WPID=""
if [ -x "${KATALON_WATCH:-}" ]; then "$KATALON_WATCH" "$LOG" & WPID=$!; fi
"${KATALON_BIN:-$HOME/.local/bin/katalon}" "$(pwd)" \
    -testSuitePath="$SUITE" \
    -browserType=Android \
    -executionProfile=default \
    -retry=0 -data ~/.katalon_console/ws-android \
    --executionProperties "devicePlatform=ANDROID deviceId=emulator-5554" > "$LOG" 2>&1
RC=$?
[ -n "$WPID" ] && kill $WPID 2>/dev/null

grep -E "Test Suites:|Test Cases:|FAILED|ERROR" "$LOG" | tail -8
if [ $RC -eq 0 ]; then
    echo "GREEN: katalonc exited 0, report in Reports/"
else
    echo "RED: katalonc exit $RC, full log: $LOG"
fi
exit $RC
