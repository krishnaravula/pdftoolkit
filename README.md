# PDF Tools

PDF Tools is a free, offline-first PDF reader and utility app for Android. It is
designed to be useful without accounts, subscriptions, advertising, analytics,
or cloud uploads.

The app targets Android 10 and newer (`minSdk 29`) and can be selected as the
system's default PDF viewer.

## What it does

- Opens PDFs from Android Files and other apps
- Supports text selection and in-document search
- Shows page thumbnails and document outlines
- Remembers the last-read page when reopening a local PDF or the same Android document
- Prompts for a password when opening a protected PDF
- Merges, splits, and compresses PDFs
- Organizes pages in one editor: reorder, rotate, duplicate, insert, extract,
  delete, undo, and redo
- Converts images to PDF
- Scans documents with crop, grayscale, and black-and-white filters
- Removes PDF passwords when the correct password is supplied
- Adds a visual signature and optional date to a PDF; draw, type, or import a
  signature, then move and resize it on the page
- Optionally saves one reusable signature in app-private storage on the device
- Saves results to `Documents/PDF Tools`, a user-selected folder, or a location
  chosen for each operation
- Keeps an on-device recent-files history with thumbnails

All document processing happens locally on the device. Visual e-signatures are
appearance marks; they do not provide certificate-based identity verification
or a cryptographic digital signature.

## Product principles

- **Free for everyone:** no advertisements, billing, premium tier, or feature
  gates.
- **Private by default:** no account, backend, telemetry, or document upload.
- **Android-native behavior:** scoped storage, Storage Access Framework folder
  selection, share/open intents, and default PDF-app support.
- **Safe file handling:** processing occurs in temporary storage; successful
  results are copied to app-managed storage before optional export.
- **Accessible UI:** Material 3 components, clear progress and error states,
  dark mode, and large touch targets.

## Technology

| Area | Implementation |
| --- | --- |
| UI | Flutter / Material 3 |
| State | Riverpod |
| Navigation | `go_router` |
| PDF rendering | `pdfrx` / PDFium |
| PDF manipulation | `pdfrx`, `pdfium_dart`, and `pdf` |
| Local database | Drift / SQLite |
| Preferences | `shared_preferences` |
| Android integration | Kotlin method channels |
| Scanning | `cunning_document_scanner` and `crop_your_image` |

For the component map, data flows, native bridge contract, and common change
paths, read [docs/architecture.md](docs/architecture.md). Coding agents should
also read [AGENTS.md](AGENTS.md) before editing.

## Repository layout

```text
lib/
  core/          app-wide configuration, routing, theme, diagnostics, utilities
  data/          preferences, Drift database, and recent-file repository
  domain/        shared entities and operation models
  features/      screens grouped by user-facing feature
  services/      PDF, scan, storage, sharing, and Android bridge services
android/         Android manifest, Kotlin bridge, Gradle, and resources
assets/          bundled privacy policy
test/            unit and widget tests mirroring the application layers
integration_test/ device-level application tests
docs/            architecture, privacy, and troubleshooting documentation
store/           Play Store copy and source artwork
```

## Requirements

- Flutter stable with Dart 3.12 or newer
- Android Studio or Android SDK with API 36
- Java 17 or newer
- An Android 10+ device or emulator for integration testing

Check the local setup with:

```bash
flutter doctor -v
```

## Getting started

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

The generated Drift file, `lib/data/local/database/app_database.g.dart`, is
committed. Regenerate it whenever the database schema changes.

## Quality checks

Run these before submitting changes:

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

Device tests require an attached emulator or physical device:

```bash
flutter test integration_test
```

Some current analyzer findings are non-blocking Flutter deprecation or lint
notices. New changes should not add analyzer errors or warnings.

## Use as the default PDF viewer

1. Install PDF Tools.
2. Open a PDF from Android Files.
3. Choose **PDF Tools**.
4. Select **Always**.

The Android activity accepts `application/pdf` view intents on cold and warm
launches. PDFs opened through another app are copied into short-lived cache
storage. Use **Save a copy** to retain one permanently.

## Output storage

Every completed operation first creates a durable app-managed copy used by the
viewer and recent-files list. App-managed results stay on the device until you
delete them or clear the app's data. Depending on the selected preference, the
app can also:

- export automatically to `Documents/PDF Tools` through MediaStore;
- export to a remembered Storage Access Framework folder; or
- ask for a destination each time.

Files are never silently written to arbitrary shared-storage paths.

## Build an APK

For local testing:

```bash
flutter build apk --debug
```

Release builds require an upload keystore. Copy
`android/key.properties.example` to the ignored `android/key.properties`, place
the keystore outside version control, and fill in its values. Then run:

```bash
flutter build apk --release
```

On Windows machines whose application-control policy blocks Flutter's
`font-subset.exe`, use:

```bash
flutter build apk --release --no-tree-shake-icons
```

Never commit `android/key.properties`, `.jks`, or `.keystore` files. For Play
Store submission, prefer:

```bash
flutter build appbundle --release
```

See [store/README.md](store/README.md) for release assets and
[store/play_listing.md](store/play_listing.md) for listing copy.

## Privacy and monetization

PDF Tools contains no advertising SDK, billing SDK, account system, analytics,
or remote document-processing service. Android cloud backup is disabled for the
app's private data. The user-facing policy is bundled from
[assets/privacy_policy.md](assets/privacy_policy.md); the publication copy is
[docs/privacy_policy.md](docs/privacy_policy.md).

Changes that add network access, telemetry, monetization, or document upload
must not be introduced without an explicit product decision and corresponding
privacy documentation.

## Troubleshooting

For startup, intent, and native-library issues, see
[docs/android_launch_debugging.md](docs/android_launch_debugging.md).
