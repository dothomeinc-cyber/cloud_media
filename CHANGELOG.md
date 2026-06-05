# Changelog

All notable changes to CloudMedia will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.0.1] - 2026-06-05

### Added

#### Core API
- `CloudMedia.pick()` — pick images, videos, audio, PDFs in one line
- `CloudMedia.list()` — fetch all media for authenticated user with filtering
- `CloudMedia.watch()` — real-time stream of media lifecycle (`pending → syncing → synced`)
- `CloudMedia.delete()` / `CloudMedia.deleteRef()` — soft delete by ID or reference
- `CloudMedia.restore()` — restore soft-deleted media
- `CloudMedia.download()` — download media to local device storage
- `CloudMedia.share()` — share via platform share sheet
- `CloudMedia.get()` — fetch single media item by ID
- `CloudMedia.sync()` — force flush offline queue
- `CloudMedia.getPendingCount()` — count of queued operations
- `CloudMedia.clearCache()` — clear all local cache
- `CloudMedia.initialize()` — configure and boot the package

#### Media Support
- Image picking — JPG, JPEG, PNG, WebP (max 10MB)
- Video picking — MP4, MOV (max 100MB, pass-through upload)
- Audio picking — MP3, AAC, M4A (max 50MB)
- PDF picking (max 25MB)
- Multi-select support (default 20, max 100 files)

#### Processing
- Automatic image compression to WebP at 85% quality (40–80% size reduction)
- On-device thumbnail generation — 200×200 WebP at quality 80
- Background removal screen with 30-second timeout, retry, and use-original fallback
- Pluggable `BackgroundRemovalProvider` contract for custom ML providers

#### Offline Sync
- Queue-based offline-first architecture via `riverpod_offline_sync`
- Auto-sync on reconnect
- Exponential backoff retry (max 5 retries)
- `CloudMediaOfflineAdapter` isolates all queue interactions
- Upload, metadata create, thumbnail upload, and delete operations queued separately
- Idempotency keys prevent duplicate operations

#### Cache
- Three-layer cache — memory, disk (Hive), Firebase source
- LRU eviction policy
- 500MB default disk cache limit (configurable)
- 30-day TTL with automatic expiry cleanup
- Cache invalidated on delete

#### UI Widgets
- `CloudImage` — local + remote image display, zoom, Hero animation support
- `CloudVideo` — video player with controls, local + remote playback
- `CloudAudio` — audio player with seek bar and duration display
- `CloudFile` — file tile with download and share actions
- `MediaGrid` — 3-column grid with upload overlay and video badge
- `UploadProgress` — linear progress bar with percentage and byte display
- `UploadProgressIndicator` — progress with pause, resume, cancel controls
- `SyncStatusIndicator` — shows sync state and pending count badge
- `PermissionAwareMediaPicker` — wraps any widget with automatic permission flow

#### Screens
- `MediaPickerScreen` — orchestrates permissions + picking flow
- `ReviewScreen` — swipeable page view before upload confirmation
- `MediaLibraryScreen` — full browsable media library with refresh
- `EditorScreen` — placeholder for crop, rotate, brightness (stub)
- `BackgroundRemovalScreen` — full implementation with timeout + retry UI

#### Dialogs
- `ErrorDialog` — with retry and dismiss actions
- `LoadingDialog` — with optional progress percentage
- `ConfirmationDialog` — with customizable confirm color
- `CroppingDialog` — stub returning original (ready for `image_cropper` integration)

#### Services
- `FirebaseService` — Firestore + Storage operations with `FirebaseAuth` integration
- `UploadService` — file picking, validation, progress streaming
- `CacheService` — Hive-backed LRU disk cache
- `CompressionService` — WebP compression via `flutter_image_compress`
- `ThumbnailService` — on-device thumbnail generation via `image` package
- `OfflineSyncService` — wraps `riverpod_offline_sync` with operation handlers
- `StorageQueueService` — pause/resume/cancel individual uploads
- `PermissionService` — typed permission requests via `permission_handler_package`

#### State Management
- `cloudMediaProvider` — core provider orchestrating all services
- `mediaListProvider` — Riverpod family provider for media lists
- `mediaStreamProvider` — real-time stream provider for single item
- `uploadProvider` — upload progress stream management
- `syncStateProvider` — global sync state (idle / syncing / error)
- `pendingMediaCountProvider` — pending queue count
- `isMediaSyncingProvider` — boolean sync state
- `syncStatusTextProvider` — human-readable sync status string
- `connectivityStatusProvider` — network connectivity state

#### Error Handling
- `CloudMediaPermissionDeniedException`
- `CloudMediaPermissionPermanentlyDeniedException`
- `CloudMediaUnsupportedFileTypeException`
- `CloudMediaFileTooLargeException`
- `CloudMediaUploadFailedException`
- `CloudMediaOfflineQueueException`
- `CloudMediaSyncException`
- `CloudMediaNetworkException`
- `CloudMediaCompressionException`
- `CloudMediaThumbnailGenerationException`
- `CloudMediaBackgroundRemovalTimeoutException`
- `CloudMediaSelectionLimitExceededException`
- `CloudMediaNotFoundException`

#### Utilities
- `CloudLogger` — debug/info/warning/error logging with enable/disable flag
- `ErrorHandler` — translates Firebase exceptions into typed CloudMedia exceptions
- `FileUtils` — extension, mime type, size formatting, delete helpers
- `Validators` — file type, size, and selection count validation
- `DateFormatter` — relative time, date, duration formatting
- `PlatformUtils` — platform detection helpers
- `FirestorePaths` — centralized Firestore path constants
- `FileConstants` — file size limits, extensions, cache settings
- `ErrorMessages` — centralized error message strings
- `UIConstants` — spacing, border radius, animation durations

#### Configuration (`CloudMediaConfig`)
- `maxCacheSizeMb` — default 500
- `imageQuality` — default 85 (range 1–100)
- `thumbnailSize` — default 200px
- `maxSelection` — default 20 (hard max 100)
- `enableOfflineSync` — default true
- `enableReviewScreen` — default true
- `enableBackgroundRemoval` — default true
- `compressAutomatically` — default true
- `autoGenerateThumbnails` — default true
- `uploadTimeout` — default 5 minutes
- `maxRetries` — default 3
- `enableLogging` — default false
- `customStorageBucket` — optional custom Firebase Storage bucket

### Dependencies

| Package | Version |
|---|---|
| firebase_core | ^4.10.0 |
| firebase_auth | ^6.5.2 |
| firebase_storage | ^13.4.2 |
| cloud_firestore | ^6.5.0 |
| image_picker | ^1.1.2 |
| file_picker | ^12.0.0-beta.5 |
| video_player | ^2.9.2 |
| audioplayers | ^6.1.0 |
| flutter_riverpod | ^3.3.2-dev.2 |
| riverpod_offline_sync | ^1.0.3 |
| permission_handler_package | ^1.0.5 |
| flutter_image_compress | ^2.3.0 |
| image | ^4.2.0 |
| hive_flutter | ^1.1.0 |
| photo_view | ^0.15.0 |
| cached_network_image | ^3.4.1 |
| share_plus | ^13.1.0 |
| connectivity_plus | ^7.1.1 |
| path_provider | ^2.1.4 |
| flutter_screenutil | ^5.9.3 |
| uuid | ^4.5.1 |
| mime | ^2.0.0 |
| intl | ^0.20.2 |

### Supported Platforms

| Platform | Status |
|---|---|
| Android | ✅ Fully supported |
| iOS | ✅ Fully supported |
| macOS | ✅ Supported |
| Windows | ✅ Supported |
| Linux | ✅ Supported |
| Web | ⚠️ Partial — `dart:io` used throughout, Web requires platform abstraction layer |

### Known Limitations

- **Video compression** — pass-through only; transcoding not implemented in v1
- **Video thumbnails** — not implemented; requires `video_thumbnail` package
- **Cropping dialog** — stub; returns original file; requires `image_cropper` integration
- **Background removal** — UI and timeout fully implemented; `LocalBackgroundRemovalProvider` is a stub returning the original image; plug in `remove_bg`, ML Kit, or `rembg` for real removal
- **Web platform** — `dart:io` (`File`, `Directory`) used in services; Web requires conditional imports and browser file API abstractions
- **Editor screen** — stub; crop, rotate, brightness not yet implemented

---

*For questions or issues visit the [GitHub repository](https://github.com/yourusername/cloud_media).*
