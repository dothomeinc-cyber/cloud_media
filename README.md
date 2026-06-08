# CloudMedia v0.0.2

A complete Firebase-native media management Flutter package.  
One line to pick. One model returned. Everything else automated.

**Now with ONNX-powered background removal, video thumbnails, and native image cropping!**

```dart
final items = await CloudMedia.pick();
```

---

## Table of Contents

- [New in v0.0.2](#new-in-v002)
- [Installation](#installation)
- [Setup](#setup)
- [Images](#images)
- [Image Cropping](#image-cropping)
- [Videos](#videos)
- [Audio](#audio)
- [Files & PDF](#files--pdf)
- [List & Filter](#list--filter)
- [Upload & Sync](#upload--sync)
- [Delete & Restore](#delete--restore)
- [Download & Share](#download--share)
- [Cache](#cache)
- [UI Widgets](#ui-widgets)
- [Dialogs](#dialogs)
- [Riverpod Providers](#riverpod-providers)
- [Error Handling](#error-handling)
- [CloudMediaItem Model](#cloudmediaitem-model)
- [Status Lifecycle](#status-lifecycle)
- [Configuration](#configuration)
- [Platform Support](#platform-support)
- [What CloudMedia Handles Automatically](#what-cloudmedia-handles-automatically)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## New in v0.0.2

- ✅ **Background Removal** — On-device ONNX model (`image_background_remover`) with 30s timeout and progress indicator
- ✅ **Video Thumbnails** — Automatic video previews (`flutter_video_thumbnail_plus`)
- ✅ **Image Cropping** — Full native cropping UI (`image_cropper`) with rectangle/circle support
- ✅ **Improved Performance** — Faster thumbnail generation with square crop
- ✅ **Better Error Handling** — 13 typed exceptions covering all scenarios
- ✅ **Enhanced Documentation** — Full API reference with examples

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  cloud_media:
    path: ../cloud_media
    # or from git:
    # git:
    #   url: https://github.com/yourusername/cloud_media.git
```

Then run:

```bash
flutter pub get
```

---

## Setup

### Android — `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

### iOS — `ios/Runner/Info.plist`

```xml
<key>NSCameraUsageDescription</key>
<string>Required to pick photos and videos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Required to access your media library</string>
<key>NSMicrophoneUsageDescription</key>
<string>Required to record audio</string>
```

### Firebase Security Rules

**Firestore:**

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/media/{mediaId} {
      allow read, write: if request.auth.uid == userId;
    }
  }
}
```

**Storage:**

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth.uid == userId;
    }
  }
}
```

### `main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler_package/permission_handler_package.dart';
import 'package:riverpod_offline_sync/riverpod_offline_sync.dart';
import 'package:cloud_media/cloud_media.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await PermissionHandler.initialize();

  await OfflineSyncLayer.instance.initialize(
    config: const SyncConfig(
      autoSyncOnReconnect: true,
      syncImmediately: true,
      maxConcurrentOperations: 2,
      enableMetrics: true,
      enableDebugLogging: false,
      syncOnWiFiOnly: false,
      maxRetries: 5,
      initialRetryDelay: Duration(seconds: 2),
      maxQueueSize: 500,
    ),
  );

  await CloudMedia.initialize(
    config: const CloudMediaConfig(
      maxCacheSizeMb: 500,
      imageQuality: 85,
      thumbnailSize: 200,
      maxSelection: 20,
      enableOfflineSync: true,
      enableReviewScreen: true,
      enableBackgroundRemoval: true,
      enableLogging: true,
      compressAutomatically: true,
      autoGenerateThumbnails: true,
    ),
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'My App',
          theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
          home: child,
        );
      },
      child: const MyHomePage(),
    );
  }
}
```

---

## Images

### Pick single image

```dart
final items = await CloudMedia.pick();
final image = items.first;
```

### Pick multiple images

```dart
final items = await CloudMedia.pick(
  type: CloudMediaType.image,
  maxCount: 10,
);
```

### Pick with crop and rotate

```dart
final items = await CloudMedia.pick(
  type: CloudMediaType.image,
  enableEditing: true,  // Shows cropping UI automatically
);
```

### Pick with background removal

**Now uses ONNX Runtime + u2net model — runs entirely on-device, no API calls!**

```dart
final items = await CloudMedia.pick(
  type: CloudMediaType.image,
  enableBackgroundRemoval: true,  // ONNX-powered, 30s timeout
);
```

The background removal screen shows:
- Animated progress indicator (0-100%)
- Cancel button to use original image
- Retry option on timeout/failure
- 30-second timeout with fallback

**Performance:** ~2-5 seconds on modern devices for 1080p images.

### Display image

```dart
CloudImage(
  media: item,
  width: 200,
  height: 200,
  fit: BoxFit.cover,
)
```

### Display with zoom

```dart
CloudImage(
  media: item,
  enableZoom: true,
)
```

### Display with Hero animation

```dart
Hero(
  tag: 'img_${item.id}',
  child: CloudImage(media: item),
)
```

### Get all images

```dart
final images = await CloudMedia.list(
  type: CloudMediaType.image,
);
```

### Get recent images (last 7 days)

```dart
final recent = await CloudMedia.list(
  type: CloudMediaType.image,
  startDate: DateTime.now().subtract(const Duration(days: 7)),
);
```

---

## Image Cropping

### Crop after picking (built-in)

```dart
final items = await CloudMedia.pick(
  type: CloudMediaType.image,
  enableEditing: true,  // ← Shows cropping UI automatically
);
```

### Manual cropping dialog

```dart
import 'package:cloud_media/cloud_media.dart';

// Square crop (1:1) — perfect for profile pictures
final cropped = await CroppingDialog.showSquareCrop(
  context: context,
  imagePath: '/path/to/image.jpg',
);

// Circle crop — perfect for avatars
final cropped = await CroppingDialog.showCircleCrop(
  context: context,
  imagePath: '/path/to/image.jpg',
);

// Wide screen crop (16:9)
final cropped = await CroppingDialog.showWideScreenCrop(
  context: context,
  imagePath: '/path/to/image.jpg',
);

// Custom aspect ratio
final cropped = await CroppingDialog.show(
  context: context,
  imagePath: '/path/to/image.jpg',
  cropStyle: CropStyle.rectangle,  // rectangle or circle
  aspectRatio: 16 / 9,             // locked aspect ratio
  allowRotation: true,             // show rotation controls
);

if (cropped != null) {
  print('Cropped image saved to: ${cropped.path}');
  final size = await cropped.length();
  print('File size: ${FileUtils.formatFileSize(size)}');
}
```

### CroppingDialog API

| Method | Description |
|--------|-------------|
| `CroppingDialog.show()` | Full customizable crop dialog |
| `CroppingDialog.showSquareCrop()` | 1:1 aspect ratio (profile pictures) |
| `CroppingDialog.showCircleCrop()` | Circular crop (avatars) |
| `CroppingDialog.showWideScreenCrop()` | 16:9 aspect ratio (banners) |

**Parameters for `.show()`:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `cropStyle` | CropStyle | `rectangle` | `rectangle` or `circle` |
| `aspectRatio` | double? | `null` | Locked aspect ratio |
| `allowRotation` | bool | `true` | Show rotation controls |

---

## Videos

### Pick single video

```dart
final items = await CloudMedia.pick(
  type: CloudMediaType.video,
);
```

### Pick with editing

```dart
final items = await CloudMedia.pick(
  type: CloudMediaType.video,
  enableEditing: true,
);
```

### Display video player

```dart
CloudVideo(
  media: item,
  width: double.infinity,
  height: 300,
  autoPlay: true,
  showControls: true,
)
```

### Display as thumbnail (no controls)

```dart
CloudVideo(
  media: item,
  showControls: false,
  height: 150,
)
```

### Full width player

```dart
CloudVideo(
  media: item,
  width: MediaQuery.of(context).size.width,
  showControls: true,
)
```

### Get all videos

```dart
final videos = await CloudMedia.list(
  type: CloudMediaType.video,
);
```

### Video Thumbnails (Automatic)

Video thumbnails are **automatically generated** using `flutter_video_thumbnail_plus`:

```dart
final items = await CloudMedia.pick(type: CloudMediaType.video);
// Thumbnail generated at 1 second mark, 200×200 WebP, 80% quality

CloudVideo(media: items.first);  // Shows thumbnail before play
```

Thumbnail settings are configurable:

```dart
CloudMedia.initialize(
  config: CloudMediaConfig(
    thumbnailSize: 300,              // default: 200
    autoGenerateThumbnails: true,    // default: true
  ),
);
```

---

## Audio

### Pick single audio file

```dart
final items = await CloudMedia.pick(
  type: CloudMediaType.audio,
);
```

### Pick multiple audio files

```dart
final items = await CloudMedia.pick(
  type: CloudMediaType.audio,
  maxCount: 5,
);
```

### Display audio player

```dart
CloudAudio(
  media: item,
  autoPlay: false,
)
```

### Auto-play audio

```dart
CloudAudio(
  media: item,
  autoPlay: true,
)
```

### Get all audio files

```dart
final audio = await CloudMedia.list(
  type: CloudMediaType.audio,
);
```

---

## Files & PDF

### Pick PDF

```dart
final items = await CloudMedia.pick(
  type: CloudMediaType.file,
);
```

### Display file tile

```dart
CloudFile(
  media: item,
  onDownload: () async => await CloudMedia.download(item.id),
  onShare: () async => await CloudMedia.share(item.id),
)
```

### Get all documents

```dart
final docs = await CloudMedia.list(
  type: CloudMediaType.file,
);
```

---

## List & Filter

### All media

```dart
final all = await CloudMedia.list();
```

### First 20 items

```dart
final recent = await CloudMedia.list(limit: 20);
```

### Filter by type

```dart
final images = await CloudMedia.list(
  type: CloudMediaType.image,
);
```

### Filter by date range

```dart
final filtered = await CloudMedia.list(
  startDate: DateTime(2025, 1, 1),
  endDate: DateTime.now(),
);
```

### Pagination

```dart
final page1 = await CloudMedia.list(limit: 20, offset: 0);
final page2 = await CloudMedia.list(limit: 20, offset: 20);
```

### Search

```dart
final results = await CloudMedia.list(
  searchQuery: 'vacation',
);
```

### With options

```dart
final results = await CloudMedia.list(
  type: CloudMediaType.image,
  limit: 50,
  startDate: DateTime(2025, 1, 1),
  endDate: DateTime.now(),
);
```

### Using CloudMediaListExtension

```dart
// List with options object
final options = CloudMediaListOptions(
  type: CloudMediaType.image,
  limit: 20,
  startDate: DateTime(2025, 1, 1),
);
final items = await CloudMedia.listWithOptions(options);

// List by type
final images = await CloudMedia.listByType(CloudMediaType.image, limit: 30);

// List recent
final recent = await CloudMedia.listRecent(limit: 10);

// List by date range
final range = await CloudMedia.listByDateRange(
  DateTime(2025, 1, 1),
  DateTime(2025, 12, 31),
  type: CloudMediaType.image,
);
```

---

## Upload & Sync

### Watch upload progress

```dart
final watcher = CloudMediaWatcher();

watcher.watchUploadProgress(item.id).listen((progress) {
  print('${(progress * 100).toStringAsFixed(0)}%');
});
```

### Wait until synced

```dart
final watcher = CloudMediaWatcher();

final synced = await watcher.watchUntil(
  item.id,
  CloudMediaStatus.synced,
  timeout: const Duration(seconds: 60),
);
print('Upload complete! URL: ${synced.downloadUrl}');
```

### Watch status changes

```dart
final watcher = CloudMediaWatcher();

watcher.watchStatus(item.id).listen((status) {
  print(status.displayName); // Pending, Syncing, Synced, Failed
});
```

### Watch with status filter

```dart
final watcher = CloudMediaWatcher();

watcher.watchWithStatusFilter(
  item.id,
  [CloudMediaStatus.syncing, CloudMediaStatus.synced],
).listen((item) {
  print('Status changed: ${item.status}');
});
```

### Watch multiple items

```dart
final watcher = CloudMediaWatcher();

watcher.watchMultiple([id1, id2, id3]).listen((items) {
  print('${items.length} items updated');
  final synced = items.where((i) => i.status == CloudMediaStatus.synced);
  print('${synced.length} completed');
});
```

### Watch with Riverpod

```dart
CloudMedia.watch(item.id).listen((updated) {
  print(updated.status);
  print(updated.downloadUrl);
});
```

### Force sync

```dart
await CloudMedia.sync();
```

### Check pending count

```dart
final count = await CloudMedia.getPendingCount();
print('$count items waiting to upload');
```

### Pause/Resume/Cancel upload

```dart
// Using StorageQueueService
StorageQueueService.pauseUpload(mediaId);
StorageQueueService.resumeUpload(mediaId);
StorageQueueService.cancelUpload(mediaId);
```

---

## Delete & Restore

### Delete by ID

```dart
await CloudMedia.delete(item.id);
```

### Delete by item reference

```dart
await CloudMedia.deleteRef(item);
```

### Delete all images

```dart
final images = await CloudMedia.list(type: CloudMediaType.image);
for (final item in images) {
  await CloudMedia.delete(item.id);
}
```

### Restore soft-deleted item

```dart
await CloudMedia.restore(item.id);
```

---

## Download & Share

### Download to device

```dart
final localPath = await CloudMedia.download(item.id);
print('Saved to: $localPath');
```

### Share via platform sheet

```dart
await CloudMedia.share(item.id);
```

### Get single item

```dart
final item = await CloudMedia.get(mediaId);
print(item.fileName);
print(item.status.displayName);
print(item.type.displayName);
```

### Share latest item

```dart
final latest = (await CloudMedia.list(limit: 1)).first;
await CloudMedia.share(latest.id);
```

---

## Cache

### Clear all cache

```dart
await CloudMedia.clearCache();
```

### Check cache size

```dart
final cacheService = CacheService(config: CloudMediaConfig());
await cacheService.initialize();
final size = await cacheService.getCacheSize();
print('Cache size: ${FileUtils.formatFileSize(size)}');
```

---

## UI Widgets

### Media grid

```dart
MediaGrid(
  mediaItems: items,
  crossAxisCount: 3,
  crossAxisSpacing: 4,
  mainAxisSpacing: 4,
  onItemTap: (item) => print('tapped: ${item.id}'),
  onItemLongPress: (item) => print('long pressed: ${item.id}'),
)
```

### Upload progress bar

```dart
UploadProgress(
  uploadId: item.id,
  showDetails: true,
)
```

### Upload progress with pause/resume/cancel

```dart
UploadProgressIndicator(
  mediaId: item.id,
  onComplete: () => print('Done!'),
)
```

### Sync status indicator

```dart
// In AppBar actions
SyncStatusIndicator(showLabel: false)

// Inline with label
SyncStatusIndicator(showLabel: true)

// Floating action button style
SyncStatusIndicator(showAsFloatingAction: true)
```

### Permission-aware picker widget

```dart
PermissionAwareMediaPicker(
  mediaType: CloudMediaType.image,
  maxCount: 5,
  permissionTitle: 'Photos Access',
  permissionMessage: 'This app needs access to your photos.',
  onMediaSelected: (files) {
    print('Got ${files.length} files');
    for (final file in files) {
      print('File: ${file.name}');
    }
  },
  child: ElevatedButton(
    onPressed: () {},
    child: const Text('Pick Images'),
  ),
)
```

### Permission-aware FAB

```dart
PermissionAwareMediaPicker(
  mediaType: CloudMediaType.image,
  maxCount: 10,
  onMediaSelected: (files) => loadAllMedia(),
  child: FloatingActionButton(
    onPressed: () {},
    child: const Icon(Icons.add_photo_alternate),
  ),
)
```

### Full media library screen

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => MediaLibraryScreen(
      type: CloudMediaType.image,  // optional filter
      onMediaTap: (item) => print('tapped: ${item.id}'),
    ),
  ),
);
```

### Review screen

```dart
final items = await CloudMedia.pick();
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ReviewScreen(
      mediaItems: items,
      onConfirm: () => print('Confirmed!'),
      onCancel: () => print('Cancelled'),
    ),
  ),
);
```

---

## Dialogs

### Error Dialog

```dart
ErrorDialog.show(
  context,
  title: 'Upload Failed',
  message: 'Unable to upload image. Please check your connection.',
  onRetry: () => retryUpload(),
  onDismiss: () => print('Dismissed'),
);
```

### Loading Dialog

```dart
// Show
LoadingDialog.show(
  context,
  message: 'Processing...',
);

// Show with progress
LoadingDialog.show(
  context,
  message: 'Uploading...',
  showProgress: true,
  progress: 0.65,
);

// Hide
LoadingDialog.hide(context);
```

### Confirmation Dialog

```dart
final confirmed = await ConfirmationDialog.show(
  context,
  title: 'Delete Media',
  message: 'Are you sure you want to delete this file?',
  confirmText: 'Delete',
  cancelText: 'Cancel',
  confirmColor: Colors.red,
  onConfirm: () => deleteFile(),
);

if (confirmed == true) {
  print('User confirmed');
}
```

### Cropping Dialog

```dart
// Square crop
final cropped = await CroppingDialog.showSquareCrop(
  context: context,
  imagePath: imagePath,
);

// Circle crop
final cropped = await CroppingDialog.showCircleCrop(
  context: context,
  imagePath: imagePath,
);

// Custom crop
final cropped = await CroppingDialog.show(
  context: context,
  imagePath: imagePath,
  cropStyle: CropStyle.rectangle,
  aspectRatio: 16 / 9,
  allowRotation: true,
);
```

---

## Riverpod Providers

### Watch sync state

```dart
class SyncStatusWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncing = ref.watch(isMediaSyncingProvider);
    
    if (isSyncing) {
      return const CircularProgressIndicator();
    }
    return const Icon(Icons.cloud_done);
  }
}
```

### Watch pending count

```dart
class PendingBadge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingMediaCountProvider);
    
    return pendingAsync.when(
      data: (count) => count > 0
          ? Badge(label: Text('$count'), child: Icon(Icons.sync))
          : const SizedBox.shrink(),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => const Icon(Icons.error),
    );
  }
}
```

### Watch single media item

```dart
class MediaStatusWidget extends ConsumerWidget {
  final String mediaId;
  
  const MediaStatusWidget({required this.mediaId});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(mediaStreamProvider(mediaId));
    
    return mediaAsync.when(
      data: (item) => item != null
          ? Row(
              children: [
                Icon(item!.status.icon, color: item.status.color),
                const SizedBox(width: 8),
                Text(item.status.displayName),
              ],
            )
          : const Text('Not found'),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }
}
```

### Watch sync status text

```dart
class SyncStatusText extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusText = ref.watch(syncStatusTextProvider);
    // Returns: 'Syncing...', '3 pending items', 'All synced'
    
    return Text(statusText);
  }
}
```

### Watch connectivity

```dart
class ConnectivityWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(isConnectedProvider);
    
    return Icon(
      isConnected ? Icons.wifi : Icons.wifi_off,
      color: isConnected ? Colors.green : Colors.red,
    );
  }
}
```

### Get queue breakdown

```dart
class QueueBreakdown extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakdownAsync = ref.watch(queueBreakdownProvider);
    
    return breakdownAsync.when(
      data: (breakdown) => Column(
        children: breakdown.entries.map((e) => 
          Text('${e.key}: ${e.value}')
        ).toList(),
      ),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }
}
```

---

## Error Handling

All exceptions are typed. No need to inspect Firebase errors directly.

```dart
try {
  final items = await CloudMedia.pick();
} on CloudMediaPermissionDeniedException {
  print('Permission denied');
  // Show user-friendly message
} on CloudMediaPermissionPermanentlyDeniedException {
  print('Permanently denied — opening settings');
  await PermissionService.openSettings();
} on CloudMediaFileTooLargeException catch (e) {
  print(e.message); // 'File 15MB exceeds 10MB limit'
} on CloudMediaUnsupportedFileTypeException catch (e) {
  print(e.message); // 'File type .gif not supported'
} on CloudMediaSelectionLimitExceededException {
  print('Too many files selected (max 100)');
} on CloudMediaUploadFailedException {
  print('Upload failed — will retry when online');
} on CloudMediaNetworkException {
  print('No internet connection');
} on CloudMediaNotFoundException {
  print('Media not found');
} on CloudMediaSyncException {
  print('Sync failed');
} on CloudMediaOfflineQueueException {
  print('Queue error');
} on CloudMediaCompressionException {
  print('Compression failed');
} on CloudMediaThumbnailGenerationException {
  print('Thumbnail generation failed');
} on CloudMediaBackgroundRemovalTimeoutException {
  print('Background removal timed out after 30 seconds');
} catch (e) {
  print('Unknown error: $e');
}
```

### Using ErrorHandler

```dart
try {
  await CloudMedia.pick();
} catch (e) {
  final error = ErrorHandler.handle(e);
  print('Code: ${error.code}');
  print('Message: ${error.message}');
  
  if (ErrorHandler.isNetworkError(e)) {
    print('Network issue detected');
  }
  
  if (ErrorHandler.isPermissionError(e)) {
    print('Permission issue detected');
  }
}
```

---

## CloudMediaItem Model

Every operation returns a `CloudMediaItem`:

```dart
final item = items.first;

// Basic info
item.id           // unique media ID (UUID)
item.userId       // Firebase Auth UID
item.type         // CloudMediaType.image / video / audio / file
item.fileName     // original file name
item.mimeType     // image/jpeg, video/mp4, etc.
item.size         // file size in bytes

// Media dimensions
item.width        // image/video width (nullable)
item.height       // image/video height (nullable)
item.duration     // audio/video duration in seconds (nullable)

// Storage
item.storagePath  // Firebase Storage path
item.downloadUrl  // Firebase download URL (empty until synced)
item.thumbnailUrl // thumbnail URL (empty until synced)
item.localPath    // local file path (available immediately after pick)

// Status
item.status       // CloudMediaStatus.pending/syncing/synced/failed/deleted

// Timestamps
item.createdAt    // DateTime when picked
item.syncedAt     // DateTime when synced (nullable)
item.deletedAt    // DateTime when soft deleted (nullable)

// Metadata
item.metadata     // Map<String, dynamic> for custom data
```

### CopyWith method

```dart
final updated = item.copyWith(
  status: CloudMediaStatus.synced,
  downloadUrl: 'https://...',
  metadata: {'custom': 'data'},
);
```

---

## Status Lifecycle

```
pending → processing → syncing → synced
                               → failed
```

| Status | Icon | Color | Meaning |
|--------|------|-------|---------|
| `pending` | ⏳ | Orange | Selected, waiting in queue |
| `processing` | 🔧 | Blue | Compressing, generating thumbnail |
| `syncing` | 🔄 | Purple | Uploading to Firebase |
| `synced` | ✅ | Green | Upload complete, URL available |
| `failed` | ❌ | Red | Upload failed permanently |
| `deleted` | 🗑️ | Grey | Soft deleted |

### Status helpers

```dart
item.status.isFinal        // true for synced/failed/deleted
item.status.isUploading    // true for processing/syncing
item.status.displayName    // Human-readable name
item.status.icon           // Material icon
item.status.color          // Status color
```

---

## Configuration

```dart
await CloudMedia.initialize(
  config: const CloudMediaConfig(
    // Cache
    maxCacheSizeMb: 500,        // disk cache limit (default: 500)
    
    // Image Processing
    imageQuality: 85,           // WebP compression quality 1-100 (default: 85)
    thumbnailSize: 200,         // thumbnail dimensions in px (default: 200)
    
    // Selection
    maxSelection: 20,           // default multi-select limit (default: 20)
    
    // Features
    enableOfflineSync: true,    // queue uploads when offline (default: true)
    enableReviewScreen: true,   // show review screen after picking (default: true)
    enableBackgroundRemoval: true, // enable BG removal option (default: true)
    
    // Auto-processing
    compressAutomatically: true,   // auto compress images to WebP (default: true)
    autoGenerateThumbnails: true,  // auto generate thumbnails (default: true)
    
    // Advanced
    enableVideoCompression: false,  // video compression (pass-through) (default: false)
    videoCompressionBitrate: 1000000, // target bitrate for video (default: 1Mbps)
    
    // Timeouts
    uploadTimeout: Duration(minutes: 5), // upload timeout (default: 5 min)
    maxRetries: 3,               // max upload retries (default: 3)
    
    // Debug
    enableLogging: false,        // set true for debug logs (default: false)
    
    // Storage
    customStorageBucket: null,   // custom Firebase Storage bucket (default: null)
  ),
);
```

---

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Android | ✅ Fully supported | Full feature set |
| iOS | ✅ Fully supported | Full feature set |
| macOS | ✅ Supported | Most features work |
| Windows | ✅ Supported | Most features work |
| Linux | ✅ Supported | Most features work |
| Web | ⚠️ Partial | `dart:io` guards needed; limited file picker |

---

## What CloudMedia Handles Automatically

| Feature | Automated | Description |
|---------|-----------|-------------|
| Permission requests | ✅ | Handles all platform permissions |
| Media picker UI | ✅ | Built-in picker for all types |
| Review screen | ✅ | Preview before upload |
| Image compression (WebP) | ✅ | 40-80% size reduction |
| Image thumbnail generation | ✅ | 200×200 WebP on-device |
| Video thumbnail generation | ✅ | Frame at 1 second mark |
| Firebase Storage upload | ✅ | Automatic with retry |
| Firestore metadata write | ✅ | Status tracking |
| Offline queue | ✅ | Persists across app restarts |
| Auto sync on reconnect | ✅ | When connectivity returns |
| Status tracking | ✅ | Real-time updates |
| LRU cache | ✅ | 500MB limit, 30-day TTL |
| Error handling | ✅ | 13 typed exceptions |
| Background removal | ✅ | ONNX on-device model |
| Pause/Resume/Cancel uploads | ✅ | Full control |
| Image cropping | ✅ | Native UI |
| File validation | ✅ | Type, size, count |
| Logging | ✅ | Configurable debug logs |

---

## Troubleshooting

### Background removal not working?

Ensure you have added the ONNX model to your assets:

```yaml
flutter:
  assets:
    - assets/models/u2net.onnx  # Download from release page
```

### Cropping dialog type conflict?

If you see `CropStyle` conflicts, use the alias:

```dart
import 'package:image_cropper/image_cropper.dart' as image_cropper;
```

### Video thumbnails not generating?

Add to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

For iOS, add to `Info.plist`:

```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Required to save thumbnails</string>
```

### Upload stuck at pending?

Check:
1. Internet connection
2. Firebase Authentication (user must be logged in)
3. Firebase Storage rules
4. Run `await CloudMedia.sync()` to force sync

### Cache not clearing?

```dart
// Force clear
await CloudMedia.clearCache();

// Also clear Hive box
final box = await Hive.openBox('cloud_media_cache');
await box.clear();
```

### Permission issues on Android 13+?

Add these to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
```

### Debug logging

Enable logging to see what's happening:

```dart
CloudMedia.initialize(
  config: const CloudMediaConfig(enableLogging: true),
);

// Also enable debug logs
CloudLogger.isDebugEnabled = true;
```

---

## Dependencies (automatically included)

| Package | Version | Purpose |
|---------|---------|---------|
| firebase_core | ^4.10.0 | Firebase core |
| firebase_auth | ^6.5.2 | Authentication |
| firebase_storage | ^13.4.2 | Cloud Storage |
| cloud_firestore | ^6.5.0 | Firestore |
| image_picker | ^1.1.2 | Media picking |
| file_picker | ^12.0.0-beta.5 | File picking |
| video_player | ^2.9.2 | Video playback |
| audioplayers | ^6.1.0 | Audio playback |
| flutter_image_compress | ^2.3.0 | Image compression |
| image | ^4.2.0 | Thumbnail generation |
| image_background_remover | ^2.0.0 | ONNX background removal |
| flutter_video_thumbnail_plus | ^1.0.6 | Video thumbnails |
| image_cropper | ^11.0.0 | Native cropping |
| photo_view | ^0.15.0 | Zoomable images |
| cached_network_image | ^3.4.1 | Image caching |
| riverpod_offline_sync | ^1.0.5 | Offline queue |
| hive_flutter | ^1.1.0 | Local cache |
| permission_handler_package | ^1.0.6 | Permissions |
| share_plus | ^13.1.0 | Sharing |
| intl | ^0.20.2 | Date formatting |

---

## License

MIT

---

**Made with ❤️ for Flutter community**