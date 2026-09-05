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
<key>NSPhotoLibraryUsageDescription</key>
<string>Not required for scanning, but some iOS versions prompt for this alongside camera access.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Not used for audio recording — required only if TTS voice packs need it on your iOS version.</string>
<key>NSFaceIDUsageDescription</key>
<string>ScanDis uses Face ID to unlock your local document vault.</string>
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

- **Dashboard** → **Vault lock screen** gates entry (biometric/OS passcode via
  `local_auth`, with an app-level PIN fallback hashed into secure storage if
  the device has no biometrics/passcode enrolled)
- Dashboard → tap a document card → **Document Detail** screen
- Document Detail → **Listen as podcast** (OCR → TTS, cached per page in Isar)
- Document Detail → **Add signature** (canvas capture, transparent PNG) →
  composited onto the last exported page automatically
- Document Detail → **Export as PDF** / **password-protected** / **watermarked**
- Document Detail → **Merge or split PDFs** → dedicated picker screen using
  `file_picker`, backed by `PdfService.mergePdfs`/`splitPdf`
- Document Detail → **Share** → OS share sheet (still fully local — no upload)
- **iOS scanning**: `google_mlkit_document_scanner` is Android-only, so on iOS
  the app falls back to a repeated `image_picker` camera loop (no auto edge
  detection — swap in `cunning_document_scanner` if you need that specifically)

## Remaining polish items (not blockers, just worth knowing)

- The iOS camera-loop fallback has no edge detection/auto-crop, unlike the
  Android ML Kit flow — pages come in as raw camera captures.
- The vault PIN is a single shared PIN, not per-user; if you need per-document
  locking (not just app-level), that's a further layer on top of this.
- `local_auth`'s `authenticate()` already falls back to the OS passcode/pattern
  UI when biometrics fail, so the app-level PIN screen only appears when the
  device has neither biometrics nor a passcode configured at all.
