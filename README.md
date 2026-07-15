# EnodePlugin

Cordova plugin wrapping Enode's LinkKit SDK (Android + iOS) for vehicle/charger linking. Built for OutSystems O11 mobile apps, added via Service Studio Extensibility Configurations.

The plugin does not create link sessions. It takes a `linkToken` obtained server-side by the O11 backend (`POST /users/{userId}/link`) and presents Enode's native linking UI with it.

## Repo Structure

| Path | What's there |
|---|---|
| `plugin.xml` | The actual Cordova plugin manifest — native dependencies (LinkKit AAR/pod), permissions, and config merged into the host app. This is what OutSystems reads. |
| `www/EnodePlugin.js` | The JS-facing API (`openLinkUI`), called from OutSystems via `exec()`. |
| `src/android/EnodePlugin.kt` | Android native implementation. |
| `src/android/res/` | Android resource overrides, e.g. `enode_themes.xml` for the LinkKit theme. |
| `src/ios/EnodePlugin.swift` | iOS native implementation. |
| `scripts/verify-build.sh` | Builds a disposable scratch Cordova app against this plugin to confirm it actually builds — see CI section below. |
| `.github/workflows/build.yml` | GitHub Actions workflow that runs `verify-build.sh` automatically. |
| `build.gradle.kts`, `settings.gradle.kts`, `gradlew*`, `gradle/` | Local Gradle wrapper, only so `EnodePlugin.kt` can be opened/edited with IDE support (syntax checking, autocomplete). Not part of the real build — the actual Android build happens inside the scratch app `verify-build.sh` creates, driven by `plugin.xml`. |
| `package.json` | Cordova/npm plugin metadata (name, version). |

## Requirements

**Android**
- minSdk 24 (Android 8) - Requirement set by LinkKit (Enode's SDK)
- Permissions (merged into the host app's manifest automatically): 
- `INTERNET`, `BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`
- The permissions `BLUETOOTH`/`BLUETOOTH_ADMIN` should normally be capped at `maxSdkVersion="30"` (Android 12+/API 31+ uses the granular `BLUETOOTH_CONNECT`/`BLUETOOTH_SCAN` permissions instead).  The cap is currently **removed** because it conflicted with another package during Sandbox DEV testing. Low practical impact (may trigger a Play Store warning at most), but the cap should be restored once that conflict is resolved — see the comment in `plugin.xml`.
- `ACCESS_COARSE_LOCATION`/`ACCESS_FINE_LOCATION` are required because Android has tied BLE scanning to location permission since Android 6 — not because this plugin or LinkKit reads actual location data. iOS has no such requirement (see below).


**iOS**
- Deployment target 14.0 (iOS 14.0) - Requirement set by OS (IONFilesystemLibrary plugin /builtin/ requires 14.0). Plugin requirement - iOS 13.1
- Permission: `NSBluetoothAlwaysUsageDescription` (merged into the host app's `Info.plist` automatically). No location usage-description is needed — unlike Android, iOS's CoreBluetooth was never tied to location authorization for BLE scanning (confirmed against Enode's own demo app, which also only declares the Bluetooth key).

## Architecture & JS API

1. The OutSystems app calls the plugin's JS action, passing the `linkToken` the O11 backend generated.
2. `www/EnodePlugin.js` hands that call across the Cordova bridge to whichever platform is running.
3. The native plugin code opens Enode's own LinkKit screen, styled per the `themeMode` argument.
4. When the user finishes, cancels, or something goes wrong, LinkKit reports that outcome back to the native plugin code.
5. The native plugin translates that outcome into a plain `{ status: ... }` object and sends it back across the bridge to the callback the OutSystems app provided.

```js
EnodePlugin.openLinkUI(linkToken, themeMode, successCallback, errorCallback);
```

| Param | Type | Required | Notes |
|---|---|---|---|
| `linkToken` | string | yes | From the O11 backend |
| `themeMode` | `"light"` \| `"dark"` \| `"system"` | no | Defaults to `"system"` |
| `successCallback` | function | yes | Called for both success and cancellation — see below |
| `errorCallback` | function | yes | Called only for genuine errors |

## Error Handling

Three outcomes, delivered via two callbacks:

| Outcome | Callback | Payload |
|---|---|---|
| **Success** | `successCallback` | `{ status: "success" }` |
| **Cancelled** | `successCallback` | `{ status: "cancelled" }` |
| **Error** | `errorCallback` | `{ status: "error", code, message }` (SDK-level) / `{ status: "error", message }` (plugin-level, e.g. invalid arguments) |

Cancellation is **not** an error — it goes through `successCallback` with a different `status`. This covers the user closing the UI, and SDK-level cancellation cases (`cancelledByUser`, `dismissedViaDismissFunction`, `earlyExitRequestedFromFrontend` on iOS; the `USER_INTERACTION` error code on Android).

`errorCallback` only fires for real failures: missing/malformed token, backend errors, unknown SDK errors, or plugin-level exceptions. `code` is a stable SDK-provided string (e.g. `missingLinkToken`, `backendError`) and is present on both platforms for SDK-level errors.

## Upgrading the Enode SDK

Both platform versions are pinned in `plugin.xml`, and the target version must already exist upstream before bumping it here:

- Android: `<framework src="io.enode:linkkit:X.Y.Z" />` — requires Enode to have published that version to Maven
- iOS: `<pod name="EnodeLinkKit" git="https://github.com/enode/enode-link-ios.git" tag="X.Y.Z" />` — requires Enode to have pushed a matching tag to their GitHub repo

To upgrade: check Enode's release notes for the target version, bump the version/tag, then rebuild in OS. Retest on a real device after upgrading, not just a clean build.

## CI

`.github/workflows/build.yml` runs on every push/PR (and manually via `workflow_dispatch`). It lints `plugin.xml`/`package.json`/`www/EnodePlugin.js`, then runs `scripts/verify-build.sh` for Android and iOS separately.

`verify-build.sh` creates a disposable scratch Cordova app, adds this plugin to it, and runs a real `cordova build`. This is the same pipeline OutSystems' Mobile Apps Build Service runs under the hood — so a `plugin.xml`/Gradle/CocoaPods/compile mistake fails here in minutes on GitHub Actions, instead of only surfacing after a full OutSystems mobile build (5-10+ minutes, and only triggered by publishing/testing the app itself).

Run it locally the same way CI does: `bash scripts/verify-build.sh android|ios|both`.
