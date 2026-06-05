# Changelog

All notable changes to CloudMedia will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.0.2] - 2026-06-05

### Added
- Web platform support with conditional imports and IndexedDB caching
- Video thumbnails via `flutter_video_thumbnail_plus`
- ML Kit background removal (Selfie Segmenter) with fallback chain
- Full `image_cropper` integration for cropping dialog
- Complete editor screen with crop, rotate, flip, brightness, contrast, saturation, blur
- Video compression with H.264 encoding, resolution scaling, and progress streaming
- HEIC/HEIF to JPEG conversion, GIF support, MKV video, FLAC audio
- Background sync with WorkManager (Android) and BGTaskScheduler (iOS)
- New APIs: `compressVideo()`, `removeBackground()`, `edit()`, `deleteMany()`, `restoreMany()`, `pauseSync()`, `resumeSync()`, `getCacheSize()`, `updateMetadata()`

### Changed
- `CloudMediaWatcher.watchUntil()` now completes correctly on target status
- `MediaGrid` performance improved with builder pattern and keep-alive
- All Riverpod `StateProvider` migrated to `NotifierProvider` for v3.x compatibility

### Fixed
- `isMediaSyncingProvider` boolean access (was throwing on `.when()` call)
- `syncStatusTextProvider` uses `.when()` instead of `.valueOrNull`
- `FilePicker` static method usage for v12.x API
- `share_plus` API updated to v13 (`ShareParams`)
- Memory leak in `CloudMediaWatcher` subscriptions

### Deprecated
- `CloudMediaListExtension` methods — use `CloudMedia.list()` directly with options

### Removed
- `LocalBackgroundRemovalProvider` stub (replaced by ML Kit, kept as fallback)

### Security
- Download URLs expire after 7 days via Firebase Storage rules
- MIME type sniffing prevents extension spoofing

---

## [0.0.1] - 2026-06-05

### Added
- Core API: `pick()`, `list()`, `watch()`, `delete()`, `restore()`, `download()`, `share()`, `get()`, `sync()`, `initialize()`
- Media support: images (JPG, PNG, WebP), videos (MP4, MOV), audio (MP3, AAC, M4A), PDFs
- Automatic image compression to WebP @ 85% quality
- On-device thumbnails (200×200 WebP)
- Offline sync with `riverpod_offline_sync` queue
- LRU disk cache (500MB, 30-day TTL)
- UI widgets: `CloudImage`, `CloudVideo`, `CloudAudio`, `CloudFile`, `MediaGrid`, `UploadProgress`, `SyncStatusIndicator`
- Screens: `MediaPickerScreen`, `ReviewScreen`, `MediaLibraryScreen`, `BackgroundRemovalScreen`
- Services: Firebase, upload, cache, compression, thumbnail, offline sync, permissions
- 13 typed exceptions for error handling
- `CloudMediaConfig` with 14 configurable options

### Dependencies
- Firebase (Core, Auth, Storage, Firestore): ^4.10.0–^6.5.0
- Image Picker, File Picker, Video Player, Audio Players
- Riverpod 3.x with offline sync
- Hive, Path Provider, Share Plus, Connectivity Plus

### Supported Platforms
- Android, iOS, macOS, Windows, Linux (fully supported)
- Web (partial — requires platform abstraction)

### Known Limitations
- Video compression pass-through only (resolved in 0.0.2)
- Video thumbnails not implemented (resolved in 0.0.2)
- Cropping dialog stub (resolved in 0.0.2)
- Background removal stub (resolved in 0.0.2)
- Editor screen stub (resolved in 0.0.2)
- Web platform requires conditional imports (resolved in 0.0.2)