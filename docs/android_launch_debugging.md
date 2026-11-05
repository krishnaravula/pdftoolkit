# Android launch crash debugging

If the app crashes before the Home screen on Android 16 (or other devices), capture native logs:

```powershell
# If adb is not on PATH (Windows), use the SDK copy:
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

& $adb logcat -c
& $adb logcat *:E | findstr /i "FATAL AndroidRuntime pdfrx sqlite pdf_toolkit UnsatisfiedLink PdfToolkitStartup MlKit"
```

Launch the app, then look for:

| Log pattern | Likely cause |
|-------------|--------------|
| `PdfToolkitStartup: pdfrxFlutterInitialize failed` | PDFium native init |
| `FATAL EXCEPTION` + `sqlite` / `libsqlite3` | Drift database native |
| `UnsatisfiedLinkError` | Missing or incompatible native `.so` (16KB page size) |
| `ClassNotFoundException` after release build | R8/ProGuard stripping |

The app tags startup phases with `PdfToolkitStartup` in logcat (debug and profile builds).

## Release build isolation

To test whether R8 minification causes the crash, build with minify disabled:

```bash
flutter build apk --release --dart-define=DISABLE_MINIFY=true
```

Or temporarily set `isMinifyEnabled = false` in `android/app/build.gradle.kts`.
