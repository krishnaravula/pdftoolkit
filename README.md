# PDF Tools - Merge, Split & Scan

Offline-first Flutter PDF utility for Android 10+ (API 29).

## Features

- Merge, split, compress, and reorder or delete PDF pages
- Image to PDF and scan-to-PDF with crop and grayscale/B&W filters
- Remove PDF password (with correct password)
- Built-in PDF viewer
- Save, open, and share outputs locally
- Recent files with thumbnails
- AdMob and Play Billing wired behind compile-time toggles (off by default)

## Run

```bash
flutter pub get
dart run build_runner build
flutter run
```

## Test

```bash
flutter test
flutter test integration_test
```

Integration tests require an emulator/device attached (for example Android emulator).

## Enable monetization (optional)

```bash
flutter run --dart-define=ENABLE_ADS=true --dart-define=ENABLE_BILLING=true
```

Use the same `--dart-define` flags on `flutter build appbundle --release` when shipping a monetized build.

## Release

See [store/README.md](store/README.md), [store/play_listing.md](store/play_listing.md), and [docs/privacy_policy.md](docs/privacy_policy.md).

```bash
flutter build appbundle --release
```

## Architecture

- **State:** Riverpod
- **Navigation:** go_router
- **PDF engine:** pdfrx (PDFium, MIT)
- **Database:** Drift (recent files)
- **Scan:** cunning_document_scanner + crop_your_image review step

All core PDF processing runs on-device with no backend dependency.
