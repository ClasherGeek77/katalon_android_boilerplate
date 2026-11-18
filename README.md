# katalon_android_boilerplate

A Katalon Studio mobile test project for Android: 7 tests of a small Flutter app (counter page, login screen, login errors, login and logout) driven through Appium with xpath locators stored in the Object Repository. The app under test is downloaded from a GitHub release, so you never build it.

The `legacy` branch holds the full history of the older predecessor repo (`katalon_mobile_automation_framework`).

## when to use it

Use it to learn or start a Katalon mobile project: mobile Object Repository, `Mobile.*` keywords, one custom keyword for typing into Flutter fields.

Do not use it if:

- you want mobile tests as Python code with pytest and Appium: use https://github.com/ClasherGeek77/pytest_android_boilerplate
- you want iOS: use https://github.com/ClasherGeek77/katalon_ios_boilerplate
- you want to start with the simplest Katalon project (no emulator): use https://github.com/ClasherGeek77/katalon_web_boilerplate or https://github.com/ClasherGeek77/katalon_api_boilerplate

This is the heaviest of the Katalon boilerplates: it needs the Android SDK, an emulator and an Appium setup next to Katalon.

## what you need

| need | detail |
|---|---|
| Katalon Studio 7.9.1 | the version recorded in `.classpath`; the project was created with it. Download from https://katalon.com/download (older versions are listed on Katalon's release pages). On macOS 10.15, 7.9.1 is the build to use. On a newer OS a current Studio should open and upgrade the project (not verified). |
| Katalon account / licence | Studio asks you to sign in. Running from the command line needs Katalon Runtime Engine, a licensed product; check the current terms on https://katalon.com. Not verified here. |
| Android SDK | `platform-tools` (adb) and `emulator`. The runner script expects them in `~/Library/Android/sdk` (the macOS default of Android Studio); set `ANDROID_HOME` in your shell for another place. |
| an Android emulator (AVD) | named `android9` (Android 9, x86_64 was used). Create it with Android Studio's Device Manager or `avdmanager`. |
| JDK 8 | the script exports a `JAVA_HOME` for it; edit that line in `run_katalon.sh` to your JDK 8 path |
| Node.js | needed by the Appium shim below (command-line path only) |
| git, curl | `fetch_app.sh` uses `curl` and `shasum` or `sha256sum` |

The command-line path also needs the "environment for mobile runs" below. Running in Studio does not (see next section).

## quick start

Get the project and the app:

```bash
git clone https://github.com/ClasherGeek77/katalon_android_boilerplate.git
cd katalon_android_boilerplate
./fetch_app.sh
```

`fetch_app.sh` downloads the two APKs from https://github.com/ClasherGeek77/mobile_app_mock/releases/tag/v1.0.0 into `apps/` (git-ignored) and checks them against the release `SHA256SUMS.txt`. You should see:

```
ok  ted_mobile_app_test-v1.0.0-debug.apk
ok  a11y-enabler.apk
app ready in apps/
```

`APP_VERSION=v1.0.0 ./fetch_app.sh` picks a release tag. A checksum mismatch deletes the file and exits 1; run it again.

- `ted_mobile_app_test-v1.0.0-debug.apk`: the app under test, package `com.ted.ted_mobile_app_test`
- `a11y-enabler.apk`: a tiny accessibility service, package `net.ted.a11yenabler`. A Flutter app only publishes its widget tree to Android (and so to Appium) while an accessibility service is on. Without it the tests find nothing.

Start your `android9` emulator, then install and enable the helper once:

```bash
adb install -r apps/a11y-enabler.apk
adb shell settings put secure enabled_accessibility_services net.ted.a11yenabler/.Enabler
adb shell settings put secure accessibility_enabled 1
```

(`run_katalon.sh` re-sets the two `settings` lines on every run but does not install the APK. Whether the service then binds without opening its own screen once is not verified.)

### run in Katalon Studio (no shims of your own)

1. Open Katalon Studio and sign in.
2. File > Open Project, pick the cloned folder (it contains `katalon_boilerplate_android.prj`).
3. Make sure the emulator is running and shows up in `adb devices`.
4. Open `Test Suites/android/android_smoke`, choose the Android device in the run dropdown and run it.

Studio is the intended GUI path and does not use the shim environment below; whether Studio 7.9.1 then runs with its own bundled Appium on your machine is not verified here. One catch: the tracked file `settings/internal/com.kms.katalon.core.mobile.android.properties` points `appiumPath` and `appiumDirectory` at the shim folder of the author's machine, and sets `deviceId` to `emulator-5554`. On your machine remove or correct those two Appium keys (or reset them in Studio's project settings for Android) before the first run. Not verified in Studio here.

You should see 7 test cases run on the emulator and pass.

### run from the command line

```bash
./run_katalon.sh                                  # Test Suites/android/android_smoke
./run_katalon.sh "Test Suites/android/only_and005"   # one test only
KATALON_BIN=/path/to/your/launcher ./run_katalon.sh
```

What the script does, in order:

1. exports `ANDROID_HOME`, `JAVA_HOME` and `APPIUM_HOME=$HOME/.katalon_appium_shim`
2. boots the `android9` emulator if `adb devices` shows none (`-gpu host -no-boot-anim -memory 1536 -no-snapshot-save`), waiting up to about 3 minutes, and writes the emulator log to `$TMPDIR/android-emulator.log`
3. writes `settings/internal/com.kms.katalon.core.mobile.android.properties` (git-ignored, machine specific), installs `apps/a11y-enabler.apk` when missing and turns the accessibility service on
4. kills a running `appium --port 4723` and any leftover `katalon_appium` process (so do not run it while you rely on such a server)
5. runs `./fetch_app.sh` if the debug APK is missing, and installs it with `adb install -r -g` if the package is absent
6. calls `$KATALON_BIN <project dir> -testSuitePath=<suite> -browserType=Android -executionProfile=default -retry=0 -data ~/.katalon_console/ws-android --executionProperties "devicePlatform=ANDROID deviceId=emulator-5554"`

`KATALON_BIN` defaults to `~/.local/bin/katalon`; that launcher is not part of this repo. It must accept the project directory first, then the options above, and start Katalon in console mode. With only the stock `katalonc` you need a wrapper that adds `-runMode=console`, `-projectPath=<dir>` and your `-apiKey`. Not verified with the stock binary. Optional `KATALON_WATCH`: an executable that takes the log path, started in the background.

The log goes to `~/katalon_cli_runs/android-<timestamp>.log`. You should see `GREEN: katalonc exited 0, report in Reports/` and a `JUnit_Report.xml` with `tests="7" failures="0"` (`tests="1"` for a single-test suite).

## environment for mobile runs (command-line path only)

Katalon Runtime 7.9.1 drives Appium 1 style servers, and the script points it at two folders in your home directory. They are not part of this repo and not created by any script here:

| folder | what it is |
|---|---|
| `~/.katalon_appium1` | an npm install of `appium` 1.22.3. On the machine these runs were recorded on, its nested uiautomator2 driver was 1.75.0 and uiautomator2-server 4.29.1. How that upgrade was done: not verified. |
| `~/.katalon_appium_shim` | `node_modules/appium/build/lib/main.js`, a small wrapper Katalon launches instead of Appium. Katalon 7.9.1 starts Appium with `--webkit-debug-proxy-port 0`, which Appium 1.22 rejects; the wrapper drops that flag, starts the real Appium from `~/.katalon_appium1`, forwards termination signals and kills the child on exit so a killed run cannot leave a stale server that blocks the next install. |

The wrapper's logic is a few lines (your own version, with your own paths, must do the same; this form was not run as written):

```js
// ~/.katalon_appium_shim/node_modules/appium/build/lib/main.js
const cp = require("child_process");
const os = require("os");
const a = process.argv.slice(2);
const i = a.indexOf("--webkit-debug-proxy-port");
if (i > -1 && a[i + 1] === "0") a.splice(i, 2);
const real = os.homedir() + "/.katalon_appium1/node_modules/appium/build/lib/main.js";
const c = cp.spawn(process.execPath, [real, ...a], { stdio: "inherit" });
c.on("exit", code => process.exit(code || 0));
["SIGINT", "SIGTERM", "SIGHUP"].forEach(s => process.on(s, () => { try { c.kill("SIGTERM"); } catch (e) {} }));
process.on("exit", () => { try { c.kill("SIGKILL"); } catch (e) {} });
```

Katalon starts its own Appium on a random port, so an Appium 2 server on :4723 would not clash, but the script kills it anyway.

## the 7 tests

| test case | what it checks |
|---|---|
| `and-001-app-opens-on-the-counter-page` | Login button and the counter label are visible |
| `and-002-login-screen-opens` | tapping Login shows the Sign In button |
| `and-003-empty-username-is-refused` | error `Epic sadface: Username is required` |
| `and-004-empty-password-is-refused` | error `Epic sadface: Password is required` |
| `and-005-wrong-password-is-refused` | error `Epic sadface: Username and password do not match any user in this service` |
| `and-006-locked-out-is-refused` | `locked_out_user` gets `Epic sadface: Sorry, this user has been locked out.` |
| `and-007-login-success-then-logout` | `standard_user` / `secret_sauce` logs in, name shown, Logout returns to the Login button |

Naming: test cases are `and-<number>-<what happens, in words>`; the suite is `android_smoke`; `only_and001`, `only_and004`, `only_and005`, `only_and006` and `only_and007` are one-test suites for debugging a single case (copy one for another test).

## how to read the code

```
Object Repository/{home,login}/*.rs                      11 mobile objects, xpath locators
Test Cases/android/*.tc                                  the test case entries
Scripts/android/<test case>/Script<timestamp>.groovy     the steps of each test case
Test Suites/android/android_smoke.ts, only_and00X.ts     the full suite and one-test suites
Keywords/android/common/FlutterInput.groovy              the one custom keyword (typing)
Profiles/default.glbl                                    APK_PATH = <project>/apps/ted_mobile_app_test-v1.0.0-debug.apk
settings/internal/...mobile.android.properties           device id, app package and activity, Appium location
run_katalon.sh, fetch_app.sh                             runner, app downloader
```

Locators are xpath, stored in the Object Repository, not in scripts. Open `Object Repository/login/input_username.rs`: the locator is `(//android.widget.EditText)[1]`, strategy XPATH. Buttons and texts use the accessibility description Flutter publishes, e.g. `//*[@content-desc='Login']`. The four error sentences are four separate objects (`txt_error_username_required`, `txt_error_password_required`, `txt_error_wrong_credentials`, `txt_error_locked_out`) instead of one xpath built in code. A script names the object, never the xpath:

```groovy
Mobile.startApplication(GlobalVariable.APK_PATH.toString(), false)
Mobile.tap(findTestObject('Object Repository/home/button_login'), 20)
FlutterInput.type(findTestObject('Object Repository/login/input_username'), 'standard_user')
Mobile.verifyElementVisible(findTestObject('Object Repository/home/txt_user_standard_user'), 25)
```

Typing is the one custom call. Flutter fields refuse `Mobile.setText` here (no keyboard on the emulator), so `FlutterInput.type` finds the field from the Object Repository xpath, long-presses it to open the edit toolbar, puts the value on the clipboard, taps Paste and waits for the toolbar to close.

The settings file also sets `autoLaunch`, `appPackage` `com.ted.ted_mobile_app_test` and `appActivity` `.MainActivity`; without an explicit launch identity the app installs but never starts.

Debugging a failure: run one test case at a time with a one-test suite (`./run_katalon.sh "Test Suites/android/only_and005"`), the full suite last.

Not included on purpose: Cucumber, data-driven CSV, TestOps, image-based keywords, real devices.

## if it breaks

| symptom | cause | fix |
|---|---|---|
| tests start but every element is missing | accessibility service off or not installed | install `apps/a11y-enabler.apk` and enable it (commands above) |
| `fetch_app.sh`: `checksum mismatch` | broken download | run it again |
| session installs the app but never launches it | missing launch identity in the settings file | keep `autoLaunch`, `appPackage`, `appActivity` in `com.kms.katalon.core.mobile.android.properties` |
| Appium fails at start with `--webkit-debug-proxy-port` error | Katalon launched plain Appium 1.22 without the wrapper | use the wrapper described above |
| install hangs or fails on the second run | a stale Appium server from a killed run | `pkill -f katalon_appium`, rerun |
| `adb: command not found` or emulator not found | wrong `ANDROID_HOME` | `export ANDROID_HOME=/path/to/sdk` before running (default `~/Library/Android/sdk`) |
| `./run_katalon.sh`: no such file or directory | no launcher at `~/.local/bin/katalon` | set `KATALON_BIN`, or run in Studio |
| blocking native dialog in console runs | stale workspace index in `~/.katalon_console/ws-android` | delete that folder and rerun |

## next

- the same journeys in pytest and Appium 2: https://github.com/ClasherGeek77/pytest_android_boilerplate
- iOS in Katalon: https://github.com/ClasherGeek77/katalon_ios_boilerplate
- the app under test and its releases: https://github.com/ClasherGeek77/mobile_app_mock
