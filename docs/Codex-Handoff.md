# FLsing Codex Handoff

Last updated: 2026-07-30

## Project

- Workspace: `D:\FLsing`
- Product: Android Flutter client backed by `flutter_sing_box` / sing-box.
- Current package version: `1.1.0+3`.
- Latest committed baseline: `13383af 完成T1相关设置，跳过VPN绕过开关（插件未暴露）`.

## User Constraints

- Do not run local APK builds unless the user explicitly asks.
- Do not commit, push, create releases, or move tags unless explicitly asked.
- No `gh` CLI. The user watches GitHub in a browser.
- Updates are manual only: Settings -> About -> Version. No automatic update check, download, or install.
- The app should remain approachable through good defaults and navigation, not by removing advanced capability.
- Do not implement multilingual UI. T1 uses the wording `启动后自动连接`, never Android boot auto-start.
- Preserve unrelated worktree changes. The current T2 files below are intentionally uncommitted.

## Committed Baseline

### T0-T1 settings

The `13383af` baseline includes the T0 features below plus the accepted T1 settings:

- Settings redesign into category pages.
- Auto reconnect with explicit user-intent handling and retry backoff.
- Log stream collection, sanitized log copy/share, diagnostic snapshot, and battery-optimization guidance.
- Manual GitHub update flow from About.
- ABI-aware APK selection: device ABI is read on Android and the matching release APK is preferred over universal.
- Subscription traffic/expiry fields are rendered when `Subscription-Userinfo` reaches `Profile.userInfo`.
- Atomic latency-test result behavior was committed earlier in `262a424`.
- Startup auto-connect, per-app proxy, dynamic notification, system HTTP proxy,
  subscription update policy, and settings backup/restore.

Key files:

- `lib/ui/pages/settings_page.dart`
- `lib/providers/app_state.dart`
- `lib/data/services/app_update_service.dart`
- `android/app/src/main/kotlin/com/flsing/flsing/MainActivity.kt`
- `docs/Settings-Roadmap.md`

## Current Uncommitted Work: T2 Phase 1

### Implemented behavior

1. DNS override
   - Three modes: preserve subscription, FLsing default, and manual DNS.
   - Manual mode supports DoH/DoT, IPv4/IPv6 strategy, cache, independent
     cache, FakeIP, and client subnet.
   - The FLsing preset follows the bundled template and only adds geo rule-set
     references when those tags exist in the active configuration.

2. TUN override
   - Optional override for MTU, stack, auto/strict route, sniffing, destination
     override, IPv4/IPv6 interface addresses, and excluded routes.
   - Override is disabled by default, preserving every subscription's TUN
     settings until the user opts in.

3. Safe configuration pipeline
   - `MainActivity.kt` exposes `Libbox.checkConfig` on
     `flsing/configuration`; the app module pins the same libbox 1.13.14 used
     by `flutter_sing_box` so Kotlin can compile the bridge.
   - `SingBoxService` builds a candidate from the subscription source and local
     settings, validates it with the real core, then replaces `using_config`
     through temporary and backup files.
   - Interrupted replacement is recovered during initialization. Advanced
     settings are persisted only after candidate validation succeeds.

4. UI and backup
   - Settings has a separate Advanced Network page with DNS and TUN third-level
     forms, per-section reset, and explicit reload/next-connect status.
   - Existing schema-v1 backups now include the advanced network object while
     remaining compatible with older backups that omit it.

### Current changed files

- `android/app/build.gradle.kts`
- `android/app/src/main/kotlin/com/flsing/flsing/MainActivity.kt`
- `docs/Settings-Roadmap.md`
- `docs/Codex-Handoff.md`
- `lib/data/services/advanced_network_config_service.dart` (new)
- `lib/data/services/advanced_network_settings.dart` (new)
- `lib/data/services/app_settings.dart`
- `lib/data/services/settings_backup_service.dart`
- `lib/data/services/sing_box_service.dart`
- `lib/providers/app_state.dart`
- `lib/ui/pages/advanced_network_page.dart` (new)
- `lib/ui/pages/settings_page.dart`
- `test/advanced_network_config_service_test.dart` (new)

## Important Caveats

- T2 phase 1 has not been Gradle-compiled or exercised on Android because local
  APK builds still require explicit permission. The Dart patcher is unit-tested,
  but the native `Libbox.checkConfig` channel needs device verification.
- `independent_cache`, inbound `sniff`, and `sniff_override_destination` are
  deprecated by newer sing-box schemas. They remain supported by the pinned
  1.13.14 core and are protected by runtime core validation; revisit them when
  upgrading libbox.
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
- T1: accepted and committed in `13383af`. VPN bypass remains a plugin dependency, not an app UI item.
- T2 phase 1: DNS/TUN overrides and the validated local override pipeline are implemented in the current worktree.
- T2 next: route rules, complex DNS/response rules, URL-test tuning, log/cache controls, a manual update channel selector, and core maintenance.
- T3: root redirect, local proxy-service mode, transport tuning, Clash API, raw config editor, memory controls, and Shizuku.

## Verification Already Run

After the current T2 phase-1 changes:

```powershell
flutter analyze
flutter test
git diff --check
```

Results:

- `flutter analyze`: no issues.
- Full test suite: 19 tests passed (including 8 new advanced-network tests).
- `git diff --check`: no whitespace errors.

No APK build, Gradle compilation, installation, commit, push, release, or tag operation was performed after the T2 edits.

## Suggested Continuation

1. Review the T2 phase-1 diff and, when authorized, build/install a device APK
   to verify FLsing/default/manual DNS, invalid DNS rejection, all three TUN
   stacks, route exclusions, connected reload, reset, and backup round-trip.
2. Implement route rules and complex DNS rules on top of the validated patch
   pipeline after phase-1 device checks pass.
3. Resolve subscription usage/expiry only with sanitized captured response
   metadata; do not add automatic User-Agent spoofing.
