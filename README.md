# cloud_media

A complete, Firebase-native media management package for Flutter.

**Pick → Edit → Compress → Upload → Cache → Stream — in one line.**

```dart
final items = await CloudMedia.pick(context: context);
```

---

## Features

- **One-line pick** — image, video, audio, PDF, file
- **Auto upload** — Firebase Storage with offline queue via `riverpod_offline_sync`
- **Image editing** — crop, rotate, undo via `flutter_img_editor`
- **Background removal** — on-device via `native_cutout` (ML Kit on Android, Vision on iOS 17+)
- **Compression profiles** — `high`, `product`, `avatar`, `thumbnail`, `none`
- **Preview before upload** — review screen before anything is committed
- **Flexible folder API** — `folder` + `subFolder` → clean Storage paths
- **Auto thumbnails** — JPEG for images, WebP for videos
- **Real-time status** — watch upload progress and sync state
- **Offline-first** — operations queue and retry on reconnect
- **HLS streaming** — play `.m3u8` streams via `CloudHlsPlayerScreen`
- **Viewer widget** — `CloudMediaViewer` handles every media type automatically
- **Upload overlay** — `CloudMediaUploadOverlay` shows progress anywhere in the tree
- **Cache helpers** — `CloudMedia.clearCache()` / `CloudMedia.cacheSize()`
- **Delete dialog** — `CloudMedia.showDeleteDialog(context, item)`

---

## Installation

```yaml
dependencies:
  cloud_media: ^1.0.0
```

```bash
flutter pub get
```

---

## Setup

Initialize once in `main()` after `Firebase.initializeApp()`:

```dart
await CloudMedia.initialize(
  config: const CloudMediaConfig(
    imageQuality: 85,      // 1–100, default 85
    maxSelection: 20,      // max files per pick, default 20
    enableOfflineSync: true,
    enableLogging: false,
  ),
);
```

---

## Pick media

### Simple image pick

```dart
final items = await CloudMedia.pick(context: context);
```

### All options

```dart
final items = await CloudMedia.pick(
  context: context,

  // Media type — image (default), video, audio, file
  type: CloudMediaType.image,

  // Max number of files to select (1–100)
  maxCount: 1,

  // Open crop/rotate editor after picking (requires context)
  enableEditing: true,

  // Run on-device background removal after editing
  enableBackgroundRemoval: true,

  // Show a review screen before committing any upload
  showPreview: true,

  // Storage path: users/{uid}/media/{folder}/{subFolder}/{mediaId}/{file}
  folder: 'products',
  subFolder: productId,

  // Override compression for this pick only
  compressionProfile: CompressionProfile.product,
);
```

### Compression profiles

| Profile | Quality | Thumbnail |
|---------|---------|-----------|
| `high` | 90 | 400px |
| `product` | 85 | 300px |
| `avatar` | 75 | 150px |
| `thumbnail` | 60 | 100px |
| `none` | pass-through | 200px |

```dart
await CloudMedia.pick(compressionProfile: CompressionProfile.avatar)
```

---

## Display media

### Unified viewer — handles every type automatically

```dart
// Automatically picks CloudImage / CloudVideo / CloudAudio / CloudFile
CloudMediaViewer(media: item)

// With options
CloudMediaViewer(
  media: item,
  autoPlay: true,
  showControls: true,
  enableZoom: true,       // images only — pinch-to-zoom
  onDownload: () { ... }, // files only
)
```

### Individual widgets

```dart
CloudImage(media: item, fit: BoxFit.cover, enableZoom: true)
CloudVideo(media: item, autoPlay: false, showControls: true)
CloudAudio(media: item)
CloudFile(media: item, onDownload: () { ... })
```

### Thumbnail (for grids and lists)

```dart
CloudMediaThumbnail(
  media: item,
  size: 80,
  onTap: () { ... },
)
```

---

## Upload overlay

Shows upload/sync progress automatically. Invisible when nothing is happening.

```dart
// Wrap a screen
CloudMediaUploadOverlay.wrap(child: YourScreen())

// Or place in a Stack manually
Stack(
  children: [
    YourScreen(),
    CloudMediaUploadOverlay(position: OverlayPosition.bottomRight),
  ],
)
```

---

## HLS video streaming (m3u8)

Use `CloudHlsPlayerScreen` for `.m3u8` stream URLs.
Use `CloudVideoPlayerScreen` for regular Firebase Storage video uploads (mp4/mov).

```dart
// Full-screen player from a CloudMediaItem
Navigator.push(context, MaterialPageRoute(
  builder: (_) => CloudHlsPlayerScreen.fromMedia(item),
));

// Full-screen player from a raw m3u8 URL
Navigator.push(context, MaterialPageRoute(
  builder: (_) => CloudHlsPlayerScreen.fromUrl(
    url: 'https://example.com/stream.m3u8',
    title: 'Live Stream',
  ),
));

// Inline player — embed in any layout
CloudHlsPlayer(
  url: 'https://example.com/stream.m3u8',
  aspectRatio: 16 / 9,
  autoPlay: true,
)
```

---

## Watch upload status

```dart
// Watch a single item
CloudMedia.watch(item.id).listen((updated) {
  print(updated.status); // pending → processing → syncing → synced
  print(updated.downloadUrl); // available when status == synced
});

// Wait until synced (with timeout)
final watcher = CloudMediaWatcher();
final synced = await watcher.watchUntil(
  item.id,
  status: CloudMediaStatus.synced,
  timeout: const Duration(minutes: 2),
);
watcher.dispose();

// Watch multiple items
final watcher = CloudMediaWatcher();
watcher.watchMultiple([id1, id2, id3]).listen((items) {
  for (final item in items) { print(item.status); }
});
watcher.dispose();

// Watch upload progress (0.0–1.0)
watcher.watchUploadProgress(item.id).listen((progress) {
  print('${(progress * 100).toInt()}%');
});

// Watch status only
watcher.watchStatus(item.id).listen((status) {
  print(status.displayName);
});
```

---

## List media

```dart
// All media
final all = await CloudMedia.list();

// Images only
final images = await CloudMedia.list(type: CloudMediaType.image);

// Date range
final recent = await CloudMedia.list(
  startDate: DateTime.now().subtract(const Duration(days: 7)),
);

// With pagination
final page2 = await CloudMedia.list(limit: 20, offset: 20);

// Using CloudMediaListExtension helpers
final recent = await CloudMediaListExtension.listRecent(limit: 10);
final images = await CloudMediaListExtension.listByType(CloudMediaType.image);
final range  = await CloudMediaListExtension.listByDateRange(from, to);
```

---

## Delete

```dart
// Delete by id (silent)
await CloudMedia.delete(item.id);

// Delete from a CloudMediaItem reference
await CloudMedia.deleteRef(item);

// Show confirmation dialog, then delete if confirmed
final deleted = await CloudMedia.showDeleteDialog(context, item);
// Returns true if deleted, false if cancelled
```

---

## Cache

```dart
// Clear all local cache
await CloudMedia.clearCache();

// Get current cache size in bytes
final bytes = await CloudMedia.cacheSize();
final mb = (bytes / 1024 / 1024).toStringAsFixed(1);
print('Cache: ${mb}MB');
```

---

## Sync

```dart
// Force-flush pending operations
await CloudMedia.sync();

// Check how many operations are queued
final pending = await CloudMedia.getPendingCount();
```

---

## Image editing

After picking, the editor opens automatically when `enableEditing: true`.
You can also open it manually:

```dart
// Full editor (crop, rotate)
final editedPath = await CloudMediaImageEditor.edit(
  context: context,
  imagePath: originalPath,
);

// Preset crop dialogs
final cropped = await CroppingDialog.show(
  context: context,
  imagePath: path,
  aspectRatio: 16 / 9,
);
final square = await CroppingDialog.showSquareCrop(context: context, imagePath: path);
final circle = await CroppingDialog.showCircleCrop(context: context, imagePath: path);
final wide   = await CroppingDialog.showWideScreenCrop(context: context, imagePath: path);
```

---

## Background removal

```dart
// Via pick (recommended)
await CloudMedia.pick(enableBackgroundRemoval: true)

// Manual — using BackgroundRemovalService directly
final service = const BackgroundRemovalService();

// Check if ML model is ready (Android only)
final ready = await service.isModelAvailable();
if (!ready) await service.downloadModel();

// Remove background from a local image path
final outputPath = await service.removeBackground(
  imagePath,
  cropToSubject: true,
);

// Monitor model download progress (Android)
service.downloadProgress.listen((progress) {
  print('${progress.percentage}%');
});
```

> **Note:** `native_cutout` requires Android Google Play Services for ML Kit.
> On iOS it requires iOS 17+ on a real device (not simulator).

---

## Permissions

`cloud_media` requests permissions automatically when you call `CloudMedia.pick()`.

To request permissions manually:

```dart
// All media permissions at once
await PermissionService.requestMediaPermissions(context, ref);

// Individual permissions
await PermissionService.requestCameraPermission(context, ref);
await PermissionService.requestStoragePermission(context, ref);
await PermissionService.requestMicrophonePermission(context, ref);

// Open device settings (if permanently denied)
await PermissionService.openSettings(ref);
```

### Android — `AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<!-- Android 12 and below -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
```

### iOS — `Info.plist`

```xml
<key>NSCameraUsageDescription</key>
<string>Used to capture photos and videos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Used to pick photos and videos</string>
<key>NSMicrophoneUsageDescription</key>
<string>Used to record audio</string>
```

For HLS streaming add:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

---

## Configuration reference

```dart
CloudMediaConfig(
  maxCacheSizeMb: 500,           // local disk cache limit
  imageQuality: 85,              // WebP compression quality (1–100)
  thumbnailSize: 200,            // thumbnail dimension in pixels
  maxSelection: 20,              // max files per pick session
  enableOfflineSync: true,       // queue uploads when offline
  enableReviewScreen: true,      // show review before upload by default
  enableBackgroundRemoval: true, // make bg removal available in pick flow
  uploadTimeout: Duration(minutes: 5),
  maxRetries: 3,
  autoGenerateThumbnails: true,
  compressAutomatically: true,
  enableLogging: false,
)
```

---

## License

MIT
