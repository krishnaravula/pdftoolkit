# Play Store assets

Prepare the following before submitting to Google Play:

## Required

- **App name (device):** PDF Tools
- **Play Store title (≤30 chars):** See [play_listing.md](play_listing.md) — e.g. `PDF Tools: Merge & Scan`
- **Short / full description:** See [play_listing.md](play_listing.md)
- **Support email:** `Env.supportEmail` in `lib/core/config/env.dart` (configured)
- **Privacy policy URL:** Host `docs/privacy_policy.md` and set `Env.privacyPolicyUrl` before release
- **App icon:** `store/app_icon_v2.png` — full-color launcher source
- **Adaptive foreground:** `store/app_icon_foreground_v2.png` — transparent foreground source
- **Previous icon:** `store/app_icon.png` — retained as a rollback asset
- **Feature graphic:** 1024 x 500 px (create in Play Console or design tool)
- **Phone screenshots:** Capture each tool flow on a device or emulator (min. 2, recommend 4–8)

## Build release bundle

1. Copy `android/key.properties.example` to `android/key.properties` and create an upload keystore.
2. Release signing is wired in `android/app/build.gradle.kts` when `key.properties` exists.
3. Run:

```bash
flutter pub get
dart run flutter_launcher_icons
flutter build appbundle --release
```

4. Upload `build/app/outputs/bundle/release/app-release.aab` to an **internal testing** track first.
5. Verify on a physical device before promoting to production.

## Pre-submit checklist

- [ ] Privacy policy hosted and `Env.privacyPolicyUrl` updated
- [ ] Upload keystore created and `android/key.properties` configured (back up keystore safely)
- [ ] Release AAB tested on at least one physical Android 10+ device
- [ ] Play Console Data safety form completed (on-device files only for default build)
- [ ] Content rating (IARC) questionnaire completed
- [ ] Store listing text pasted from `play_listing.md`
- [ ] Screenshots and feature graphic uploaded

## Data safety

- Declare **files and docs** processed on-device.
- Confirm that no document content, advertising identifier, or analytics data is collected.

## Content rating

Complete the IARC questionnaire as a utilities/productivity app with no online UGC.
