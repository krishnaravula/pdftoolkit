# Architecture guide

This document is the technical map of PDF Tools. It is intentionally explicit
so a new contributor or coding agent can locate behavior without scanning every
file first.

## System overview

```text
Android PDF intent / user action
              |
              v
       Flutter feature screen
              |
              v
       Riverpod provider graph
        /          |          \
       v           v           v
PDF processing   storage     recent files
   service       services      repository
       |            |             |
       v            v             v
pdfrx/PDFium   Kotlin channels   Drift/SQLite
```

The app has no server component. Flutter owns product behavior and rendering;
Kotlin is limited to Android facilities that require platform APIs.

## Startup and navigation

1. `lib/main.dart` calls `bootstrap()`.
2. `lib/bootstrap.dart` installs diagnostics and clears stale temporary files.
3. `lib/app.dart` creates the Riverpod scope, resolves preferences, and starts
   Android intent handling.
4. `lib/core/routing/app_router.dart` provides the `go_router` route graph.

Primary shell tabs are `/home`, `/recent`, and `/settings`. Full-screen feature
routes are:

| Route | Screen | Purpose |
| --- | --- | --- |
| `/merge` | `MergeScreen` | Combine PDFs |
| `/split` | `SplitScreen` | Extract or divide pages |
| `/compress` | `CompressScreen` | Reduce file size |
| `/image-to-pdf` | `ImageToPdfScreen` | Convert images |
| `/remove-password` | `RemovePasswordScreen` | Create an unlocked copy |
| `/scan` | `ScanScreen` | Camera-to-PDF workflow |
| `/page-editor` | `PageEditorScreen` | Unified page organizer |
| `/esign` | `EsignScreen` | Place visual signatures and optional dates |
| `/viewer` | `PdfViewerScreen` | Read, search, navigate, and resume |
| `/privacy-policy` | `PrivacyPolicyScreen` | Bundled policy |

Feature names, routes, descriptions, and recent-file labels are centralized in
`lib/domain/entities/pdf_feature.dart`.

## Layer responsibilities

### Presentation: `lib/features/`

Screens own user interaction, selection state, progress presentation, and
navigation. They obtain services from Riverpod rather than constructing
long-lived dependencies directly.

Cross-feature UI belongs in `lib/core/widgets/` or `lib/features/shared/`.

### Provider graph: `lib/core/di/providers.dart`

This file is the composition root for databases, repositories, services, job
state, scan sessions, and selected features. Add dependencies here when they
need lifecycle management or substitution in tests.

### Domain: `lib/domain/entities/`

Domain types are UI-independent values shared across features and services.
Notable types include:

- `PdfFeatureType`: supported tools and route metadata;
- `PdfJobProgress`: status and progress for long operations;
- `PdfPageOperation`: source page plus rotation used by the page organizer;
- `PdfStampPlacement`: one-based page and normalized displayed-page bounds for a visual image mark;
- app-setting enums: save destination, theme, quality, compression, and sort;
- `RecentFileItem`: durable recent-file data;
- `ScanPage`: scan review state.

### PDF services: `lib/services/pdf/`

`PdfProcessingService` is the feature-facing facade. It validates inputs,
creates temporary output paths, delegates work, removes failed outputs, and
turns implementation errors into user-facing exceptions.

`PdfService` performs document operations. Supporting files handle page
geometry, merge normalization, target page sizes, and cancellable job progress.
`PdfJobNotifier` mirrors `PdfJobRunner` progress into Riverpod state through a
synchronous stream so the final success, failure, or cancelled state is always
applied. Only `StateError('cancelled')` and `PdfOperationCancelledException`
map to cancellation; other errors propagate to the screen and are shown with
`userFriendlyError`.
`pdfrx` supplies rendering/document access and `pdfium_dart` supplies native
PDFium operations needed for lossless manipulation.

`PdfStampEmbedder` adds transparent raster marks to existing PDF pages through
PDFium image objects. The page content remains vector/text content. Signature
image creation, layout, and optional date stamps are handled by the e-sign
feature; `SignatureStorageService` stores a reusable signature only after the
user opts in.

Keep page-number conversions close to the API that requires them. Application
and domain page numbers are one-based.

### Persistence: `lib/data/`

- `AppPreferences` wraps `SharedPreferences` for settings and per-document
  reading positions.
- `SignatureStorageService` stores an optional reusable signature in app-private
  storage; the signing UI exposes deletion.
- `AppDatabase` is a Drift database containing recent-file records.
- `RecentFilesRepository` coordinates database rows, durable files, metadata,
  and thumbnails.
- `FileStorageService` owns private application directories, including the
  cache directory where pending processing outputs wait to be saved, and stale
  temporary file cleanup.

The generated Drift implementation is
`lib/data/local/database/app_database.g.dart`.

### Storage and export: `lib/services/storage/`

`FileSaveService` creates and validates temporary output paths.
`StorageRepository` copies completed files into private durable storage, creates
unique filenames, and invokes Android export APIs. The save screen removes each
temporary output after `RecentFilesService` records the durable copy. If one
file fails, retry resumes at that file and keeps the earlier results available.
Pending outputs live in `FileStorageService.processingOutputsDirectory`
(`<cache>/temp`); startup cleanup applies age and size limits there, and
`RecentFilesService.clearTemporaryFiles` empties it.

The normal output flow is:

```text
selected input
  -> validated source
  -> private temporary output
  -> durable app-managed copy
  -> recent-files database
  -> optional Documents/SAF export
  -> viewer, share, or external open
```

Visual signing follows this same flow. It writes a signed copy to temporary
storage and never edits the selected source in place. PDFs with existing
cryptographic signatures trigger a warning because rewriting a copy can make
those signatures fail verification.

Do not point recent-file entries at cache or external input locations.

## Android integration

`MainActivity.kt` owns two method channels.

### `pdf_toolkit/android`

| Direction | Method | Meaning |
| --- | --- | --- |
| Dart -> Kotlin | `consumeInitialPdf` | Return the cold-start PDF import, if present |
| Dart -> Kotlin | `openDefaultPdfSettings` | Open Android default-app settings |
| Kotlin -> Dart | `openPdf` | Deliver a warm PDF import |
| Kotlin -> Dart | `openPdfError` | Report failure to import an intent URI |

`AndroidIntegrationService` is the Dart wrapper. Android `content://` PDF URIs
are copied to private cache before Flutter receives `path` and
`readingPositionKey`. The reading-position key is derived from a SHA-256 hash of
the source URI and stays stable across cache copies. The activity
accepts both `ACTION_VIEW` and `ACTION_SEND`, resolving the URI from `data`,
`EXTRA_STREAM`, or `ClipData` to accommodate OEM file-manager differences.

### `pdf_toolkit/storage`

The storage channel supports:

- exporting a PDF to `Documents/PDF Tools` through MediaStore;
- opening an `ACTION_OPEN_DOCUMENT_TREE` picker;
- persisting and checking folder write permission; and
- exporting a PDF to a chosen tree URI through `DocumentFile`.

Treat method names and argument keys as a versioned contract across Kotlin and
Dart.

## Viewer behavior

`PdfViewerScreen` owns a `PdfViewerController` and `PdfTextSearcher`. It loads
outlines and thumbnails from the opened document, supports selectable text and
search navigation, and stores reading position through `AppPreferences`.

The reading-position key is the absolute local path for local PDFs or the
source-derived key for Android imports. An inability to load or save preferences
must never prevent a document from opening.

## Unified page organizer

`PageEditorScreen` models the output as an ordered list of `PdfPageOperation`
values. A page operation identifies its source document, source page number,
and rotation. This allows one output to contain reordered pages, duplicates,
rotations, and pages inserted from other PDFs.

Undo and redo operate on organizer state. Final output is produced by
`PdfProcessingService.organizePages`, not by modifying source PDFs in place.

## Error handling and diagnostics

Typed exceptions live in `lib/core/errors/app_exception.dart`. Convert
low-level failures through `lib/core/utils/error_messages.dart` before showing
them in UI.

`StartupDiagnostics` is for startup and integration troubleshooting. It must
not record document contents, PDF passwords, signing values, or other secrets.

## Testing map

| Change | Minimum relevant tests |
| --- | --- |
| PDF operation | Matching `test/services/pdf_*_test.dart` |
| Page organizer | Domain and organizer service tests |
| Storage/export | Storage and save-service tests; Android APK build |
| Preferences/resume | `test/data/app_preferences_test.dart` |
| Recent files | Repository, logic, and screen tests |
| Routing/UI | Widget test plus integration test when navigation changes |
| Kotlin/Gradle/plugins | APK build on Android toolchain |

Run the full commands listed in `AGENTS.md` before release.

## Common change paths

### Add a PDF tool

1. Add the feature to `PdfFeatureType`.
2. Add a domain request/result type if needed.
3. Implement the low-level operation in `PdfService` or a focused helper.
4. Expose validation and temp-file handling through `PdfProcessingService`.
5. Wire providers in `providers.dart`.
6. Add a feature screen and route.
7. Record successful durable output in recent files.
8. Add service and UI tests; update README and store copy.

### Add visual signatures

Use `/esign` from either the viewer or home tool. Keep page placements in
normalized displayed-page coordinates, convert them to PDF page coordinates in
the PDF service, and embed PNGs with PDFium so existing text/vector content is
preserved. Do not describe the result as a cryptographic signature or identity
verification. Update both privacy-policy copies when changing signature
retention behavior.

### Change saving behavior

Trace `SaveResultScreen` -> `FileSaveService` / `StorageRepository` ->
`MainActivity.kt`. Verify private durable storage, MediaStore export, remembered
SAF folder export, permission loss, cancellation, and filename collision cases.

### Change the default-viewer flow

Update the manifest intent filter, `MainActivity.kt`,
`AndroidIntegrationService`, and app-level navigation together. Test both a
cold start and a new intent delivered while the activity is already running.

## Build and generated artifacts

- `app_database.g.dart` is generated and committed.
- Launcher PNG/XML resources are generated from `store/app_icon_v2.png` and
  `store/app_icon_foreground_v2.png` with `dart run flutter_launcher_icons`.
- `build/`, `.dart_tool/`, signing files, and keystores are local artifacts and
  must remain untracked.
- Release identity comes from `version:` in `pubspec.yaml`.
