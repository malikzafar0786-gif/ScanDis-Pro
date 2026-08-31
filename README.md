# ScanDis — Setup Guide

100% on-device document scanner: scanning, OCR, offline TTS "podcast" playback,
signature stamping, and PDF export/merge/split/password-protection. No backend,
no analytics, no network calls anywhere in this codebase.

## 1. Create the Flutter project shell

This package ships only `lib/` and `pubspec.yaml` — you need the platform
scaffolding (`android/`, `ios/`) which can't be generated outside a real
Flutter SDK install:

```bash
flutter create --org com.yourcompany scandis_shell
# then copy this pubspec.yaml and lib/ into scandis_shell, overwriting the defaults
```

Or, if you already have a Flutter project, just copy `lib/` and merge
`pubspec.yaml`'s `dependencies:` block into yours.

## 2. Install dependencies

```bash
flutter pub get
```

## 3. Generate the Isar schema code

`document_model.dart` declares `part 'document_model.g.dart';` — that file
is generated, not written by hand:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Re-run this any time you change a field on `ScanDocument` or `ScanPage`.

## 4. Platform-specific setup

**Android** (`android/app/build.gradle`):
- `minSdkVersion 21` or higher (ML Kit document scanner requirement)
- Add camera permission in `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="android.permission.CAMERA" />
  ```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSCameraUsageDescription</key>
<string>ScanDis needs camera access to scan documents.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Not used for audio recording — required only if TTS voice packs need it on your iOS version.</string>
```

`google_mlkit_document_scanner` is Android-only today (the underlying Play
Services Document Scanner API has no iOS counterpart). On iOS you'll want to
swap that one screen (`scan_screen.dart`) for a package like `cunning_document_scanner`
or a `camera` + custom edge-detection flow — everything downstream (OCR, TTS,
PDF, signatures) is cross-platform as written.

## 5. Syncfusion license (PDF merge/split/encryption)

`syncfusion_flutter_pdf` is free under the **Syncfusion Community License**
for individuals and small teams (revenue/funding thresholds apply — check
https://www.syncfusion.com/products/communitylicense). Register a license key
once you have one:

```dart
// call before runApp(), e.g. at the top of main()
SyncfusionLicense.registerLicense('YOUR_KEY_HERE');
```

If that license doesn't fit your situation, `mergePdfs`/`splitPdf`/password
protection in `pdf_service.dart` are isolated behind `PdfService` — swap the
implementation for a native platform-channel binding (PDFKit/PdfBox) without
touching any calling code.

## 6. Run it

```bash
flutter run
```

## What's wired up end-to-end

- **Dashboard** → tap a document card → **Document Detail** screen
- Document Detail → **Listen as podcast** (OCR → TTS, cached per page in Isar)
- Document Detail → **Add signature** (canvas capture, transparent PNG)
- Document Detail → **Export as PDF** / **password-protected** / **watermarked**
- Document Detail → **Share** → OS share sheet (still fully local — no upload)

## Known gaps to fill in before shipping

- Signature stamp is captured but not yet composited onto the PDF pages in
  `pdf_service.dart` — `compileDocument` would need an extra `PdfBitmap`
  draw call per page using `_signaturePath` from the detail screen.
- No merge/split UI yet — `PdfService.mergePdfs`/`splitPdf` are implemented
  and unit-testable, just not hooked to a picker screen.
- No app-level lock screen (biometric/PIN) gating the vault itself — worth
  adding given the "secure vault" framing, e.g. via `local_auth`.
