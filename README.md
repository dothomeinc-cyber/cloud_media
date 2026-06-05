# CloudMedia

A complete Firebase-native media management Flutter package.  
One line to pick. One model returned. Everything else automated.

```dart
final items = await CloudMedia.pick();
```

---

## Table of Contents

- [Installation](#installation)
- [Setup](#setup)
- [Images](#images)
- [Videos](#videos)
- [Audio](#audio)
- [Files & PDF](#files--pdf)
- [List & Filter](#list--filter)
- [Upload & Sync](#upload--sync)
- [Delete & Restore](#delete--restore)
- [Download & Share](#download--share)
- [Cache](#cache)
- [UI Widgets](#ui-widgets)
- [Riverpod Providers](#riverpod-providers)
- [Error Handling](#error-handling)
- [Platform Support](#platform-support)

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  cloud_media:
    path: ../cloud_media
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
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await PermissionHandler.initialize();

  await OfflineSyncLayer.instance.initialize();

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
  enableEditing: true,
);
```

### Pick with background removal

```dart
final items = await CloudMedia.pick(
  type: CloudMediaType.image,
  enableBackgroundRemoval: true,
);
```

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
```

### Watch status changes

```dart
final watcher = CloudMediaWatcher();

watcher.watchStatus(item.id).listen((status) {
  print(status.displayName); // Pending, Syncing, Synced, Failed
});
```

### Watch multiple items

```dart
final watcher = CloudMediaWatcher();

watcher.watchMultiple([id1, id2, id3]).listen((items) {
  print('${items.length} items updated');
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

---

## UI Widgets

### Media grid

```dart
MediaGrid(
  mediaItems: items,
  crossAxisCount: 3,
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

// Floating
SyncStatusIndicator(showAsFloatingAction: true)
```

### Permission-aware picker widget

```dart
PermissionAwareMediaPicker(
  mediaType: CloudMediaType.image,
  maxCount: 5,
  onMediaSelected: (files) {
    print('Got ${files.length} files');
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
MediaLibraryScreen(
  type: CloudMediaType.image,
  onMediaTap: (item) => print('tapped: ${item.id}'),
)
```

---

## Riverpod Providers

### Watch sync state

```dart
final isSyncing = ref.watch(isMediaSyncingProvider);

if (isSyncing) {
  return const CircularProgressIndicator();
}
```

### Watch pending count

```dart
final pendingAsync = ref.watch(pendingMediaCountProvider);

pendingAsync.when(
  data: (count) => Text('$count pending'),
  loading: () => const CircularProgressIndicator(),
  error: (e, _) => Text('Error: $e'),
);
```

### Watch single media item

```dart
final mediaAsync = ref.watch(mediaStreamProvider(item.id));

mediaAsync.when(
  data: (item) => item != null
      ? Text('Status: ${item!.status.displayName}')
      : const Text('Not found'),
  loading: () => const CircularProgressIndicator(),
  error: (e, _) => Text('Error: $e'),
);
```

### Watch sync status text

```dart
final statusText = ref.watch(syncStatusTextProvider);
// Returns: 'Syncing...', '3 pending items', 'All synced'

Text(statusText)
```

---

## Error Handling

All exceptions are typed. No need to inspect Firebase errors directly.

```dart
try {
  final items = await CloudMedia.pick();
} on CloudMediaPermissionDeniedException {
  print('Permission denied');
} on CloudMediaPermissionPermanentlyDeniedException {
  print('Permanently denied — opening settings');
  await PermissionService.openSettings();
} on CloudMediaFileTooLargeException catch (e) {
  print(e.message); // 'File 15MB exceeds 10MB limit'
} on CloudMediaUnsupportedFileTypeException catch (e) {
  print(e.message); // 'File type .gif not supported'
} on CloudMediaSelectionLimitExceededException {
  print('Too many files selected');
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
}
```

---

## CloudMediaItem Model

Every operation returns a `CloudMediaItem`:

```dart
final item = items.first;

item.id           // unique media ID
item.userId       // Firebase Auth UID
item.type         // CloudMediaType.image / video / audio / file
item.fileName     // original file name
item.mimeType     // image/jpeg, video/mp4, etc.
item.size         // file size in bytes
item.width        // image/video width (nullable)
item.height       // image/video height (nullable)
item.duration     // audio/video duration (nullable)
item.storagePath  // Firebase Storage path
item.downloadUrl  // Firebase download URL (empty until synced)
item.thumbnailUrl // thumbnail URL (empty until synced)
item.status       // CloudMediaStatus.pending/syncing/synced/failed/deleted
item.localPath    // local file path (available immediately after pick)
item.createdAt    // DateTime
item.syncedAt     // DateTime (nullable — set when synced)
item.deletedAt    // DateTime (nullable — set when soft deleted)
item.metadata     // Map<String, dynamic> for custom data
```

---

## Status Lifecycle

```
pending → processing → syncing → synced
                               → failed
```

| Status | Meaning |
|---|---|
| `pending` | Selected, waiting in queue |
| `processing` | Compressing, generating thumbnail |
| `syncing` | Uploading to Firebase |
| `synced` | Upload complete, URL available |
| `failed` | Upload failed permanently |
| `deleted` | Soft deleted |

---

## Configuration

```dart
await CloudMedia.initialize(
  config: const CloudMediaConfig(
    maxCacheSizeMb: 500,        // disk cache limit
    imageQuality: 85,           // WebP compression quality (1–100)
    thumbnailSize: 200,         // thumbnail dimensions (px)
    maxSelection: 20,           // default multi-select limit
    enableOfflineSync: true,    // queue uploads when offline
    enableReviewScreen: true,   // show review screen after picking
    enableBackgroundRemoval: true, // enable BG removal option
    compressAutomatically: true,   // auto compress images to WebP
    autoGenerateThumbnails: true,  // auto generate 200×200 thumbnails
    uploadTimeout: Duration(minutes: 5),
    maxRetries: 3,
    enableLogging: false,       // set true for debug
  ),
);
```

---

## Platform Support

| Platform | Status |
|---|---|
| Android | ✅ Fully supported |
| iOS | ✅ Fully supported |
| macOS | ✅ Supported |
| Windows | ✅ Supported |
| Linux | ✅ Supported |
| Web | ⚠️ Partial — `dart:io` guards needed |

---

## What CloudMedia Handles Automatically

| Feature | Automated |
|---|---|
| Permission requests | ✅ |
| Media picker UI | ✅ |
| Review screen | ✅ |
| Image compression (WebP) | ✅ |
| Thumbnail generation (200×200 WebP) | ✅ |
| Firebase Storage upload | ✅ |
| Firestore metadata write | ✅ |
| Offline queue | ✅ |
| Auto sync on reconnect | ✅ |
| Status tracking | ✅ |
| LRU cache (500MB, 30-day TTL) | ✅ |
| Error handling (13 typed exceptions) | ✅ |
| Background removal (pluggable) | ✅ |
| Pause / resume / cancel uploads | ✅ |

---

## License

MIT