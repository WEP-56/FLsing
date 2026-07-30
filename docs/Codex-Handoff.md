# FLsing Codex Handoff

Last updated: 2026-07-30

## Project

- Workspace: `D:\FLsing`
- Product: Android Flutter client backed by `flutter_sing_box` / sing-box.
- Current package version: `1.1.0+3`.
- Latest committed baseline: `dd89dbf 完成T0 设置，优化订阅显示（用量、日期）`.

## User Constraints

- Do not run local APK builds unless the user explicitly asks.
- Do not commit, push, create releases, or move tags unless explicitly asked.
- No `gh` CLI. The user watches GitHub in a browser.
- Updates are manual only: Settings -> About -> Version. No automatic update check, download, or install.
- The app should remain approachable through good defaults and navigation, not by removing advanced capability.
- Do not implement multilingual UI. T1 uses the wording `启动后自动连接`, never Android boot auto-start.
- Preserve unrelated worktree changes. The current T1 files below are intentionally uncommitted.

## Committed Baseline

### T0 settings

The `dd89dbf` baseline already includes:

- Settings redesign into category pages.
- Auto reconnect with explicit user-intent handling and retry backoff.
- Log stream collection, sanitized log copy/share, diagnostic snapshot, and battery-optimization guidance.
- Manual GitHub update flow from About.
- ABI-aware APK selection: device ABI is read on Android and the matching release APK is preferred over universal.
- Subscription traffic/expiry fields are rendered when `Subscription-Userinfo` reaches `Profile.userInfo`.
- Atomic latency-test result behavior was committed earlier in `262a424`.

Key files:

- `lib/ui/pages/settings_page.dart`
- `lib/providers/app_state.dart`
- `lib/data/services/app_update_service.dart`
- `android/app/src/main/kotlin/com/flsing/flsing/MainActivity.kt`
- `docs/Settings-Roadmap.md`

## Current Uncommitted Work: T1 Settings

### Implemented behavior

1. Startup auto-connect
   - `AppSettings.autoConnectOnLaunch` defaults to false.
   - `AppSettings.connectionRequested` records whether the user last kept the VPN connected.
   - At app initialization, auto-connect runs only if both flags are true and an active subscription exists.
   - Manual disconnect and a VPN-permission denial clear the persisted connection intent.
   - No `RECEIVE_BOOT_COMPLETED`, receiver, or device-boot behavior is used.
   - Main code: `lib/providers/app_state.dart`.

2. Per-app proxy
   - Supports disabled, include-only, and exclude modes.
   - Uses `flutter_sing_box`'s `CsSettingsStorage`, which the plugin's Android `VPNService` reads when it recreates the TUN interface.
   - A third-level selector lists launchable installed apps, searches name/package, and hides system apps by default.
   - Saving reloads VPN when connected; otherwise it applies on the next connection.
   - New Dart service: `lib/data/services/per_app_proxy_service.dart`.
   - Android package query bridge: `MainActivity.kt`, channel `flsing/device`.
   - `android.permission.QUERY_ALL_PACKAGES` was added because a complete picker needs package visibility. This should be reviewed against the target distribution store's policy before public release.

3. System HTTP proxy and dynamic notification
   - `lib/data/services/platform_settings_service.dart` stores plugin-recognized MMKV keys in `cs_settings`.
   - System HTTP proxy is enabled only if the active TUN config already provides `platform.http_proxy.server` and `server_port`; otherwise UI reports incompatibility.
   - `SingBoxService.setSystemHttpProxyEnabled()` patches the current config and then `AppState` reloads VPN.
   - Dynamic notification enables/disables the plugin's `dynamic_notification` setting, requesting Android 13+ notification permission before enabling.
   - `POST_NOTIFICATIONS` was added to the manifest.

4. Subscription update policy
   - Added Wi-Fi-only auto updates and 0-3 extra retries for automatic refreshes.
   - Manual refresh is never Wi-Fi restricted and does not add retry delay.
   - Automatic refresh records a concise last-status message in `AppSettings.lastSubscriptionUpdateError`.
   - A successful refresh reloads the running active VPN config.

5. Settings backup and restore
   - Export/import is in Settings -> Privacy and Data.
   - The JSON includes app preferences, platform switches, and per-app package selections.
   - It deliberately excludes subscription URLs, node configuration, profile data, update APK cache, and transient errors.
   - Restore shows a confirmation, re-applies the config patch, updates theme immediately, and reloads a connected VPN.
   - New service: `lib/data/services/settings_backup_service.dart`.

### Current changed files

- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/flsing/flsing/MainActivity.kt`
- `docs/Settings-Roadmap.md`
- `lib/data/services/app_settings.dart`
- `lib/data/services/device_service.dart`
- `lib/data/services/per_app_proxy_service.dart` (new)
- `lib/data/services/platform_settings_service.dart` (new)
- `lib/data/services/settings_backup_service.dart` (new)
- `lib/data/services/sing_box_service.dart`
- `lib/providers/app_state.dart`
- `lib/ui/pages/settings_page.dart`

## Important Caveats

- T1 has only passed `flutter analyze`; Android Kotlin and actual VPN behavior have not been built or exercised on a device because the user asked not to build locally.
- The package picker relies on `QUERY_ALL_PACKAGES`. It should be verified on an Android device and reviewed for distribution-policy compliance.
- `flutter_sing_box` v1.1.4 has `builder.allowBypass()` commented out in its Android `VPNService`. Do not expose a VPN bypass switch: it will not work. The roadmap has been corrected accordingly.
- System HTTP proxy is configuration-dependent. The bundled template supports it (`tun.platform.http_proxy` plus a local mixed inbound), but arbitrary imported configs may not.
- `serviceReload()` causes a real plugin service restart. Settings pages correctly describe the short VPN interruption.
- `SettingsBackupService` uses `ConfigurationFileImporter`, whose Android picker is also used for configuration import. It accepts JSON, but the user-facing native chooser is not specialized to backup files.

## Subscription Usage Investigation

- The UI now maps `Profile.userInfo` to `SubscriptionItem` and conditionally renders usage and expiry in `lib/ui/pages/subscription_sheet.dart`.
- `SingBoxService` parses the standard `subscription-userinfo` header for its custom share-link parser; the plugin handles it for its own profile-import branch.
- A phone screenshot showed no usage data. No conclusion was reached because the working-tree source was not built/installed. The user believes their providers may vary the response based on client User-Agent.
- This issue is explicitly deferred. Do not add an automatic User-Agent spoof without first capturing sanitized response headers or receiving a user decision.

## Settings Roadmap

`docs/Settings-Roadmap.md` is the authoritative T0-T3 plan.

- T0: complete in the committed baseline.
- T1: all currently real plugin-backed items are now implemented in the uncommitted work above. VPN bypass remains a plugin dependency, not an app UI item.
- T2 next: DNS presets/overrides, full DNS rules, TUN parameters, route rules, URL-test tuning, log/cache controls, configuration overrides, and a manual update channel selector.
- T3: root redirect, local proxy-service mode, transport tuning, Clash API, raw config editor, memory controls, and Shizuku.

## Verification Already Run

After the current T1 changes:

```powershell
flutter analyze
flutter test test/app_update_service_test.dart
git diff --check
```

Results:

- `flutter analyze`: no issues.
- Update-service test file: 8 tests passed.
- `git diff --check`: no whitespace errors.

No APK build, Gradle compilation, installation, commit, push, release, or tag operation was performed after the T1 edits.

## Suggested Continuation

1. Review the T1 diff and, when authorized, build/install a device APK for focused verification:
   - startup auto-connect after a user-initiated connection;
   - manual disconnect must prevent relaunch auto-connect;
   - per-app include/exclude behavior after VPN reload;
   - notification permission denial path;
   - HTTP proxy on both bundled and external configs;
   - Wi-Fi-only subscription behavior and backup round-trip.
2. Resolve the subscription usage/expiry header behavior only with sanitized captured response metadata.
3. Start T2 with DNS settings and TUN parameters only after the T1 device checks pass.

