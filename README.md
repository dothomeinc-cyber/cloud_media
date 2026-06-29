

```markdown
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
- [Responsive UI with ScreenUtil](#responsive-ui-with-screenutil)
- [Firebase Setup & Examples](#firebase-setup--examples)
  - [Firebase Project Setup](#firebase-project-setup)
  - [Firebase Authentication](#firebase-authentication)
  - [Upload to Firebase](#upload-to-firebase)
  - [Get from Firebase](#get-from-firebase)
  - [Delete from Firebase](#delete-from-firebase)
  - [Firebase Security Rules](#firebase-security-rules-complete)
  - [Firebase Storage Rules](#firebase-storage-rules)
  - [Firestore Indexes](#firestore-indexes)
- [Images](#images)
- [Image Cropping](#image-cropping)
- [Videos](#videos)
- [Audio](#audio)
- [Files & PDF](#files--pdf)
- [List & Filter](#list--filter)
- [Upload & Sync Watching](#upload--sync-watching)
- [Delete & Restore](#delete--restore)
- [Download & Share](#download--share)
- [Cache](#cache)
- [UI Widgets](#ui-widgets)
- [Screens](#screens)
- [Dialogs](#dialogs)
- [Riverpod Providers](#riverpod-providers)
- [Error Handling](#error-handling)
- [Background Removal](#background-removal)
- [Image Compression](#image-compression)
- [Permissions](#permissions)
- [Utilities](#utilities)
- [CloudMediaItem Model](#cloudmediaitem-model)
- [Status Lifecycle](#status-lifecycle)
- [Configuration](#configuration)
- [Platform Support](#platform-support)
- [What CloudMedia Handles Automatically](#what-cloudmedia-handles-automatically)
- [Troubleshooting](#troubleshooting)
- [Custom Paths & Collections](#custom-paths--collections)
  - [1. Image — Custom Path & Collection](#1-image--custom-path--collection)
  - [2. Video — Custom Path & Collection](#2-video--custom-path--collection)
  - [3. Audio — Custom Path & Collection](#3-audio--custom-path--collection)
  - [4. PDF — Custom Path & Collection](#4-pdf--custom-path--collection)
  - [5. Multiple Files — Batch Upload](#5-multiple-files--batch-upload)
  - [6. With Background Removal — Custom Path](#6-with-background-removal--custom-path)
  - [7. With Cropping — Custom Path](#7-with-cropping--custom-path)
  - [8. Offline Queue — Custom Collection](#8-offline-queue--custom-collection)
  - [9. Read Back from Custom Collection](#9-read-back-from-custom-collection)
  - [10. Core Upload Helper](#10-core-upload-helper)
  - [Custom Path Patterns Reference](#custom-path-patterns-reference)
- [License](#license)

---

## New in v0.0.2

- ✅ **Background Removal** — On-device ONNX model (`image_background_remover`) with 30s timeout and progress indicator
- ✅ **Video Thumbnails** — Automatic video previews (`flutter_video_thumbnail_plus`)
- ✅ **Image Cropping** — Full native cropping UI (`image_cropper`) with rectangle/circle support
- ✅ **Improved Performance** — Faster thumbnail generation with square crop
- ✅ **Better Error Handling** — 13 typed exceptions covering all scenarios
- ✅ **Enhanced Documentation** — Full API reference with examples
- ✅ **Responsive UI** — Built-in `flutter_screenutil` support for all widgets

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
  
  # Required for responsive UI
  flutter_screenutil: ^5.9.3
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

---

## Responsive UI with ScreenUtil

All CloudMedia widgets support `flutter_screenutil` for responsive sizing across different screen sizes.

### Setup ScreenUtil in your app

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize ScreenUtil before runApp
  await ScreenUtil.ensureScreenSize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), // Design size (e.g., iPhone 13)
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'My App',
          theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
          home: child,
        );
      },
      child: const HomePage(),
    );
  }
}
```

### ScreenUtil Methods Used in Widgets

| Method | Purpose | Example |
|--------|---------|---------|
| `.w` | Width scaling (horizontal) | `16.w` |
| `.h` | Height scaling (vertical) | `24.h` |
| `.r` | Radius / Square scaling | `8.r` |
| `.sp` | Font size scaling | `14.sp` |

### Example: Responsive CloudImage

```dart
// Width and height auto-scale with ScreenUtil
CloudImage(
  media: item,
  width: 200,   // automatically scaled as 200.w
  height: 200,  // automatically scaled as 200.h
  fit: BoxFit.cover,
)

// Without explicit dimensions - uses parent constraints
CloudImage(
  media: item,
  fit: BoxFit.cover,
)
```

---

## Firebase Setup & Examples

### Firebase Project Setup

1. **Create a Firebase project** at [https://console.firebase.google.com](https://console.firebase.google.com)

2. **Register your app**:
   - Android: Add package name, download `google-services.json`
   - iOS: Add bundle ID, download `GoogleService-Info.plist`
   - Web: Add app, get Firebase config

3. **Enable Firebase services**:
   - Authentication (enable Anonymous or Email/Password)
   - Firestore Database (create in test mode first)
   - Storage (create in test mode first)

4. **Add Firebase to your Flutter project**:

```bash
flutter pub add firebase_core firebase_auth cloud_firestore firebase_storage
```

5. **Generate Firebase options**:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Firebase Authentication

**Anonymous Sign-in (simplest for testing):**

```dart
import 'package:firebase_auth/firebase_auth.dart';

Future<void> signInAnonymously() async {
  try {
    final userCredential = await FirebaseAuth.instance.signInAnonymously();
    print('Signed in with: ${userCredential.user?.uid}');
  } on FirebaseAuthException catch (e) {
    print('Failed: ${e.message}');
  }
}
```

**Email/Password Sign-in:**

```dart
Future<void> signInWithEmail(String email, String password) async {
  try {
    final userCredential = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);
    print('User: ${userCredential.user?.uid}');
  } on FirebaseAuthException catch (e) {
    if (e.code == 'user-not-found') {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    }
  }
}
```

**Google Sign-in:**

```dart
import 'package:google_sign_in/google_sign_in.dart';

Future<void> signInWithGoogle() async {
  final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
  final GoogleSignInAuthentication googleAuth = 
      await googleUser!.authentication;
  
  final credential = GoogleAuthProvider.credential(
    accessToken: googleAuth.accessToken,
    idToken: googleAuth.idToken,
  );
  
  await FirebaseAuth.instance.signInWithCredential(credential);
}
```

### Upload to Firebase

**Automatic Upload (CloudMedia handles everything):**

```dart
// Just pick - CloudMedia auto-uploads to Firebase!
final items = await CloudMedia.pick();

// The item automatically uploads to:
// Firestore: /users/{userId}/media/{mediaId}
// Storage: /users/{userId}/media/{mediaId}/{fileName}

// Watch for completion
CloudMedia.watch(items.first.id).listen((item) {
  if (item.status == CloudMediaStatus.synced) {
    print('Uploaded to: ${item.downloadUrl}');
  }
});
```

**Manual Upload Control:**

```dart
// Force sync immediately
await CloudMedia.sync();

// Check pending uploads
final pending = await CloudMedia.getPendingCount();
print('$pending items uploading');
```

**Custom Upload with Metadata:**

```dart
// Pick with custom metadata
final items = await CloudMedia.pick();

// Add custom metadata after upload
final item = items.first;
await CloudMedia.updateMetadata(item.id, {
  'category': 'profile',
  'tags': ['vacation', 'summer'],
  'location': 'Paris',
  'customField': 'any value',
});
```

### Get from Firebase

**Get all user media from Firebase:**

```dart
// List all media from Firestore
final allMedia = await CloudMedia.list();
print('Total items: ${allMedia.length}');

// List filtered
final images = await CloudMedia.list(
  type: CloudMediaType.image,
  limit: 20,
);

// Get single item by ID
final item = await CloudMedia.get('media_id_here');
print(item.downloadUrl);
```

**Real-time listening with Stream:**

```dart
// Listen to real-time updates from Firestore
CloudMedia.watch(mediaId).listen((item) {
  print('Status: ${item.status}');
  print('URL: ${item.downloadUrl}');
  print('Thumbnail: ${item.thumbnailUrl}');
});

// Listen to multiple items
final watcher = CloudMediaWatcher();
watcher.watchMultiple([id1, id2, id3]).listen((items) {
  print('${items.length} items updated');
});
```

**Query Firestore directly (advanced):**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

// Get Firestore instance
final firestore = FirebaseFirestore.instance;
final userId = FirebaseAuth.instance.currentUser!.uid;

// Direct query (same as CloudMedia.list())
final snapshot = await firestore
    .collection('users')
    .doc(userId)
    .collection('media')
    .where('deletedAt', isNull: true)
    .orderBy('createdAt', descending: true)
    .limit(50)
    .get();

for (final doc in snapshot.docs) {
  print(doc.data());
}
```

### Delete from Firebase

**Delete via CloudMedia (recommended):**

```dart
// Delete single item (removes from Storage + Firestore)
await CloudMedia.delete(mediaId);

// Delete by item reference
await CloudMedia.deleteRef(item);

// Delete all images
final images = await CloudMedia.list(type: CloudMediaType.image);
for (final img in images) {
  await CloudMedia.delete(img.id);
}
```

**Restore deleted item:**

```dart
// Restore soft-deleted item
await CloudMedia.restore(mediaId);
```

**Direct Firebase delete (advanced):**

```dart
// Delete from Storage and Firestore manually
final userId = FirebaseAuth.instance.currentUser!.uid;

// Delete from Storage
final storageRef = FirebaseStorage.instance
    .ref('users/$userId/media/$mediaId/filename.jpg');
await storageRef.delete();

// Delete from Firestore
await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .collection('media')
    .doc(mediaId)
    .delete();
```

### Firebase Security Rules (Complete)

**Firestore Security Rules — `firestore.rules`:**

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAuthenticated() { return request.auth != null; }
    function isOwner(userId) { return request.auth.uid == userId; }
    
    match /users/{userId} {
      allow read, write: if isAuthenticated() && isOwner(userId);
      
      match /media/{mediaId} {
        allow read: if isAuthenticated() && isOwner(userId);
        allow write: if isAuthenticated() && isOwner(userId);
        
        allow create: if isAuthenticated() && isOwner(userId) 
          && request.resource.data.keys().hasAll([
            'userId', 'type', 'fileName', 'mimeType', 
            'size', 'storagePath', 'status', 'createdAt'
          ]);
          
        allow update: if isAuthenticated() && isOwner(userId)
          && request.resource.data.userId == resource.data.userId;
          
        allow update: if resource.data.status == 'pending' 
          && request.resource.data.status == 'syncing'
          || resource.data.status == 'syncing' 
          && request.resource.data.status == 'synced'
          || resource.data.status == 'syncing' 
          && request.resource.data.status == 'failed'
          || resource.data.status == 'synced' 
          && request.resource.data.status == 'deleted';
      }
    }
  }
}
```

**Firebase Storage Rules — `storage.rules`:**

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    function isAuthenticated() { return request.auth != null; }
    function isOwner(userId) { return request.auth.uid == userId; }
    
    match /users/{userId}/{allPaths=**} {
      allow read, write: if isAuthenticated() && isOwner(userId);
      
      allow create: if isAuthenticated() && isOwner(userId)
        && request.resource.size < 100 * 1024 * 1024
        && request.resource.contentType.matches('image/.*|video/.*|audio/.*|application/pdf');
        
      match /thumbnails/{thumbnailId} {
        allow create: if request.resource.size < 500 * 1024;
      }
    }
  }
}
```

### Firestore Indexes

Create these indexes in Firebase Console → Firestore → Indexes:

```json
{
  "collectionId": "media",
  "fields": [
    {"fieldPath": "deletedAt", "mode": "ASCENDING"},
    {"fieldPath": "createdAt", "mode": "DESCENDING"}
  ]
}

{
  "collectionId": "media",
  "fields": [
    {"fieldPath": "deletedAt", "mode": "ASCENDING"},
    {"fieldPath": "type", "mode": "ASCENDING"},
    {"fieldPath": "createdAt", "mode": "DESCENDING"}
  ]
}
```

### Complete main.dart with Firebase & ScreenUtil

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler_package/permission_handler_package.dart';
import 'package:riverpod_offline_sync/riverpod_offline_sync.dart';
import 'package:cloud_media/cloud_media.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ScreenUtil.ensureScreenSize();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAuth.instance.signInAnonymously();

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
          title: 'CloudMedia Demo',
          theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
          home: child,
          debugShowCheckedModeBanner: false,
        );
      },
      child: const HomePage(),
    );
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  List<CloudMediaItem> _mediaItems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    setState(() => _loading = true);
    final items = await CloudMedia.list();
    setState(() {
      _mediaItems = items;
      _loading = false;
    });
  }

  Future<void> _pickAndUpload() async {
    try {
      final items = await CloudMedia.pick();
      if (items.isNotEmpty) {
        setState(() {
          _mediaItems.insertAll(0, items);
        });
        
        for (final item in items) {
          CloudMedia.watch(item.id).listen((updated) {
            if (updated.status == CloudMediaStatus.synced) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Uploaded: ${updated.fileName}')),
              );
              _loadMedia();
            }
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteFromFirebase(CloudMediaItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "${item.fileName}" from Firebase?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await CloudMedia.delete(item.id);
        setState(() => _mediaItems.removeWhere((i) => i.id == item.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deleted from Firebase')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('CloudMedia Demo', style: TextStyle(fontSize: 18.sp)),
        actions: [
          SyncStatusIndicator(showLabel: false),
          IconButton(
            icon: Icon(Icons.refresh, size: 20.r),
            onPressed: _loadMedia,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _mediaItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library, size: 64.r, color: Colors.grey),
                      SizedBox(height: 16.h),
                      Text('No media yet. Tap + to upload!', style: TextStyle(fontSize: 14.sp)),
                    ],
                  ),
                )
              : MediaGrid(
                  mediaItems: _mediaItems,
                  onItemTap: (item) => _showMediaDetail(item),
                  onItemLongPress: (item) => _deleteFromFirebase(item),
                ),
      floatingActionButton: PermissionAwareMediaPicker(
        mediaType: CloudMediaType.image,
        maxCount: 5,
        onMediaSelected: (_) => _pickAndUpload(),
        child: FloatingActionButton(
          onPressed: () {},
          child: Icon(Icons.add, size: 24.r),
        ),
      ),
    );
  }

  void _showMediaDetail(CloudMediaItem item) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.cloud_download),
            title: const Text('Download from Firebase'),
            subtitle: Text(item.downloadUrl.isNotEmpty ? 'URL available' : 'Still uploading...'),
            onTap: () async {
              if (item.downloadUrl.isNotEmpty) {
                final path = await CloudMedia.download(item.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Downloaded to: $path')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share'),
            onTap: () async => await CloudMedia.share(item.id),
          ),
          ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete from Firebase'),
            onTap: () {
              Navigator.pop(context);
              _deleteFromFirebase(item);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text('Firestore ID: ${item.id.substring(0, 8)}...'),
            subtitle: Text('Status: ${item.status.displayName}'),
          ),
        ],
      ),
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

### Display image (responsive)

```dart
CloudImage(
  media: item,
  width: 200,   // auto-scaled with ScreenUtil
  height: 200,  // auto-scaled with ScreenUtil
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
  enableEditing: true,
);
```

### Manual cropping dialog

```dart
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
  cropStyle: CropStyle.rectangle,
  aspectRatio: 16 / 9,
  allowRotation: true,
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

### Display video player (responsive)

```dart
CloudVideo(
  media: item,
  width: double.infinity,
  height: 300,   // auto-scaled with ScreenUtil
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

```dart
final items = await CloudMedia.pick(type: CloudMediaType.video);
CloudVideo(media: items.first);
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

### Using CloudMediaListExtension

```dart
final options = CloudMediaListOptions(
  type: CloudMediaType.image,
  limit: 20,
  startDate: DateTime(2025, 1, 1),
);
final items = await CloudMedia.listWithOptions(options);

final images = await CloudMedia.listByType(CloudMediaType.image, limit: 30);
final recent = await CloudMedia.listRecent(limit: 10);
```

---

## Upload & Sync Watching

### Watch single item

```dart
CloudMedia.watch(item.id).listen((updated) {
  print(updated.status.displayName);
  print(updated.downloadUrl);
});
```

### Watch with helper class

```dart
final watcher = CloudMediaWatcher();

final synced = await watcher.watchUntil(
  item.id,
  CloudMediaStatus.synced,
  timeout: const Duration(minutes: 2),
);

watcher.watchUploadProgress(item.id).listen((progress) {
  print('${(progress * 100).toStringAsFixed(0)}%');
});

watcher.watchStatus(item.id).listen((status) {
  print(status.displayName);
});

watcher.watchMultiple([id1, id2, id3]).listen((items) {
  print('${items.length} items updated');
});

watcher.dispose();
```

### Force sync & pending count

```dart
await CloudMedia.sync();
final pending = await CloudMedia.getPendingCount();
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

---

## Cache

### Clear all cache

```dart
await CloudMedia.clearCache();
```

### Get cache size

```dart
final cacheService = CacheService(config: const CloudMediaConfig());
await cacheService.initialize();
final size = await cacheService.getCacheSize();
print(FileUtils.formatFileSize(size));
```

---

## UI Widgets

### Media grid (responsive)

```dart
MediaGrid(
  mediaItems: items,
  crossAxisCount: 3,
  crossAxisSpacing: 4,   // auto-scaled with ScreenUtil
  mainAxisSpacing: 4,    // auto-scaled with ScreenUtil
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
SyncStatusIndicator(showLabel: false)  // AppBar
SyncStatusIndicator(showLabel: true)   // Inline
SyncStatusIndicator(showAsFloatingAction: true) // FAB
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

---

## Screens

### Media Library Screen

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => MediaLibraryScreen(
      type: CloudMediaType.image,
      onMediaTap: (item) => print('tapped: ${item.id}'),
    ),
  ),
);
```

### Review Screen

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
await ErrorDialog.show(
  context,
  title: 'Upload Failed',
  message: 'Check your connection and try again.',
  onRetry: () => _retryUpload(),
  onDismiss: () => print('dismissed'),
);
```

### Loading Dialog

```dart
LoadingDialog.show(context, message: 'Uploading...');
LoadingDialog.hide(context);

LoadingDialog.show(
  context,
  message: 'Processing...',
  showProgress: true,
  progress: 0.65,
);
```

### Confirmation Dialog

```dart
final confirmed = await ConfirmationDialog.show(
  context,
  title: 'Delete Media',
  message: 'This cannot be undone.',
  confirmText: 'Delete',
  confirmColor: Colors.red,
);
if (confirmed == true) await CloudMedia.delete(item.id);
```

---

## Riverpod Providers

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncing = ref.watch(isMediaSyncingProvider);
    final pending = ref.watch(pendingMediaCountProvider);
    final syncText = ref.watch(syncStatusTextProvider);
    final isOnline = ref.watch(isConnectedProvider);
    
    return Column(children: [
      Text(syncText),
      Text(isSyncing ? 'Uploading...' : 'Idle'),
      Text(isOnline ? 'Online' : 'Offline'),
    ]);
  }
}
```

---

## Error Handling

```dart
try {
  final items = await CloudMedia.pick();
} on CloudMediaPermissionDeniedException {
  print('Permission denied');
} on CloudMediaPermissionPermanentlyDeniedException {
  await PermissionService.openSettings(ref);
} on CloudMediaFileTooLargeException catch (e) {
  print(e.message);
} on CloudMediaUnsupportedFileTypeException catch (e) {
  print(e.message);
} on CloudMediaSelectionLimitExceededException {
  print('Too many files selected');
} on CloudMediaUploadFailedException {
  print('Queued for offline sync');
} on CloudMediaNetworkException {
  print('No internet — queued');
} catch (e) {
  final message = ErrorHandler.getUserFriendlyMessage(e);
  print(message);
}
```

---

## Background Removal

### Automatic in pick flow

```dart
final items = await CloudMedia.pick(
  type: CloudMediaType.image,
  enableBackgroundRemoval: true,
);
```

### Manual screen

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => BackgroundRemovalScreen(
      media: item,
      onComplete: (processedPath) => print('Result: $processedPath'),
    ),
  ),
);
```

### Custom provider

```dart
class RemoveBgApiProvider implements BackgroundRemovalProvider {
  @override
  Future<void> initialize() async {}
  @override
  Future<File> removeBackground(File image) async { /* API call */ }
  @override
  void dispose() {}
}
```

---

## Image Compression

### Auto-compressed

```dart
final items = await CloudMedia.pick(type: CloudMediaType.image);
```

### Manual compression

```dart
final compressionService = CompressionService(
  config: const CloudMediaConfig(imageQuality: 85),
);
final compressedPath = await compressionService.compressImage('/path/to/image.jpg');
```

---

## Permissions

### Auto-handled

```dart
final items = await CloudMedia.pick();
```

### Manual requests

```dart
await PermissionService.requestMediaPermissions(context, ref);
await PermissionService.requestCameraPermission(context, ref);
await PermissionService.requestStoragePermission(context, ref);
await PermissionService.requestMicrophonePermission(context, ref);
await PermissionService.openSettings(ref);
```

---

## Utilities

### File utils

```dart
FileUtils.formatFileSize(1024 * 1024);
FileUtils.getFileExtension('photo.jpg');
FileUtils.getMimeType('video.mp4');
await FileUtils.deleteFile('/path/to/file');
```

### Validators

```dart
Validators.validateFileType('photo.jpg');
Validators.validateFileSize(bytes, CloudMediaType.image);
Validators.validateSelectionCount(5);
Validators.isValidUrl('https://example.com');
```

### Date formatter

```dart
DateFormatter.formatDate(item.createdAt);
DateFormatter.formatDateTime(item.createdAt);
DateFormatter.formatTimeAgo(item.createdAt);
DateFormatter.formatDuration(Duration(seconds: 125));
```

### Logger

```dart
CloudLogger.isEnabled = true;
CloudLogger.info('Upload started');
CloudLogger.debug('Compressed: 4.2MB → 1.1MB');
CloudLogger.error('Upload failed', error: e);
```

### Platform utils

```dart
PlatformUtils.isAndroid;
PlatformUtils.isIOS;
PlatformUtils.isWeb;
PlatformUtils.platformName;
```

---

## CloudMediaItem Model

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
item.downloadUrl  // Firebase download URL
item.thumbnailUrl // thumbnail URL
item.status       // CloudMediaStatus
item.localPath    // local file path
item.createdAt    // DateTime
item.metadata     // Map<String, dynamic>
```

---

## Status Lifecycle

```
pending → processing → syncing → synced → failed
```

| Status | Icon | Color | Meaning |
|--------|------|-------|---------|
| `pending` | ⏳ | Orange | Waiting in queue |
| `processing` | 🔧 | Blue | Compressing, generating thumbnail |
| `syncing` | 🔄 | Purple | Uploading to Firebase |
| `synced` | ✅ | Green | Upload complete |
| `failed` | ❌ | Red | Upload failed |
| `deleted` | 🗑️ | Grey | Soft deleted |

---

## Configuration

```dart
await CloudMedia.initialize(
  config: const CloudMediaConfig(
    maxCacheSizeMb: 500,
    imageQuality: 85,
    thumbnailSize: 200,
    maxSelection: 20,
    enableOfflineSync: true,
    enableReviewScreen: true,
    enableBackgroundRemoval: true,
    compressAutomatically: true,
    autoGenerateThumbnails: true,
    uploadTimeout: Duration(minutes: 5),
    maxRetries: 3,
    enableLogging: false,
  ),
);
```

---

## Platform Support

| Platform | Status |
|----------|--------|
| Android | ✅ Fully supported |
| iOS | ✅ Fully supported |
| macOS | ✅ Supported |
| Windows | ✅ Supported |
| Linux | ✅ Supported |
| Web | ⚠️ Partial |

---

## What CloudMedia Handles Automatically

| Feature | Automated |
|---------|-----------|
| Permission requests | ✅ |
| Media picker UI | ✅ |
| Review screen | ✅ |
| Image compression (WebP) | ✅ |
| Thumbnail generation | ✅ |
| Video thumbnail generation | ✅ |
| Firebase Storage upload | ✅ |
| Firestore metadata write | ✅ |
| Offline queue | ✅ |
| Auto sync on reconnect | ✅ |
| Status tracking | ✅ |
| LRU cache (500MB) | ✅ |
| 13 typed exceptions | ✅ |
| Background removal | ✅ |
| Image cropping | ✅ |

---

## Troubleshooting

### Background removal not working?
```yaml
flutter:
  assets:
    - assets/models/u2net.onnx
```

### Cropping dialog type conflict?
```dart
import 'package:image_cropper/image_cropper.dart' as image_cropper;
```

### Video thumbnails not generating?
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

### Debug logging
```dart
CloudMedia.initialize(config: CloudMediaConfig(enableLogging: true));
CloudLogger.isDebugEnabled = true;
```

---

## Custom Paths & Collections

### Setup — Initialize Services Directly

```dart
import 'package:cloud_media/cloud_media.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
```

### 1. Image — Custom Path & Collection

```dart
class CustomMediaService {
  final _uploadService = UploadService(config: const CloudMediaConfig());
  final _compressionService = CompressionService(
    config: const CloudMediaConfig(imageQuality: 85),
  );
  final _thumbnailService = ThumbnailService(
    config: const CloudMediaConfig(thumbnailSize: 200),
  );

  Future<void> uploadProfilePhoto({required String userId}) async {
    final files = await _uploadService.pickMedia(
      type: CloudMediaType.image,
      maxCount: 1,
    );
    if (files.isEmpty) return;
    final file = files.first;
    final mediaId = const Uuid().v4();

    final compressed = await _compressionService.compressImage(file.path);
    final thumbPath = await _thumbnailService.generateThumbnail(compressed, CloudMediaType.image);

    final storagePath = 'profiles/$userId/avatar/$mediaId.webp';
    final thumbStoragePath = 'profiles/$userId/thumbnails/$mediaId.webp';

    final downloadUrl = await _uploadToStorage(
      filePath: compressed,
      storagePath: storagePath,
      contentType: 'image/webp',
    );

    String thumbUrl = '';
    if (thumbPath != null) {
      thumbUrl = await _uploadToStorage(
        filePath: thumbPath,
        storagePath: thumbStoragePath,
        contentType: 'image/webp',
      );
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('profile')
        .doc('avatar')
        .set({
      'mediaId': mediaId,
      'userId': userId,
      'downloadUrl': downloadUrl,
      'thumbnailUrl': thumbUrl,
      'storagePath': storagePath,
      'fileName': file.name,
      'mimeType': 'image/webp',
      'size': await File(compressed).length(),
      'type': 'image',
      'createdAt': Timestamp.now(),
    });
  }
}
```

### 2. Video — Custom Path & Collection

```dart
Future<void> uploadPostVideo({
  required String postId,
  required String userId,
  required String caption,
}) async {
  final files = await _uploadService.pickMedia(
    type: CloudMediaType.video,
    maxCount: 1,
  );
  if (files.isEmpty) return;
  final file = files.first;
  final mediaId = const Uuid().v4();

  final thumbPath = await _thumbnailService.generateThumbnail(
    file.path,
    CloudMediaType.video,
    size: 400,
  );

  final storagePath = 'posts/$postId/videos/$mediaId/${file.name}';
  final thumbStoragePath = 'posts/$postId/thumbnails/$mediaId.webp';

  final downloadUrl = await _uploadToStorage(
    filePath: file.path,
    storagePath: storagePath,
    contentType: file.mimeType,
  );

  String thumbUrl = '';
  if (thumbPath != null) {
    thumbUrl = await _uploadToStorage(
      filePath: thumbPath,
      storagePath: thumbStoragePath,
      contentType: 'image/webp',
    );
  }

  await FirebaseFirestore.instance
      .collection('posts')
      .doc(postId)
      .collection('media')
      .doc(mediaId)
      .set({
    'mediaId': mediaId,
    'userId': userId,
    'postId': postId,
    'caption': caption,
    'downloadUrl': downloadUrl,
    'thumbnailUrl': thumbUrl,
    'storagePath': storagePath,
    'fileName': file.name,
    'mimeType': file.mimeType,
    'type': 'video',
    'size': await File(file.path).length(),
    'createdAt': Timestamp.now(),
  });
}
```

### 3. Audio — Custom Path & Collection

```dart
Future<void> uploadTrack({
  required String albumId,
  required String userId,
  required String trackName,
}) async {
  final files = await _uploadService.pickMedia(
    type: CloudMediaType.audio,
    maxCount: 1,
  );
  if (files.isEmpty) return;
  final file = files.first;
  final mediaId = const Uuid().v4();

  final storagePath = 'music/$userId/albums/$albumId/$mediaId/${file.name}';

  final downloadUrl = await _uploadToStorage(
    filePath: file.path,
    storagePath: storagePath,
    contentType: file.mimeType,
  );

  await FirebaseFirestore.instance
      .collection('albums')
      .doc(albumId)
      .collection('tracks')
      .doc(mediaId)
      .set({
    'mediaId': mediaId,
    'userId': userId,
    'albumId': albumId,
    'trackName': trackName,
    'fileName': file.name,
    'downloadUrl': downloadUrl,
    'storagePath': storagePath,
    'mimeType': file.mimeType,
    'size': await File(file.path).length(),
    'type': 'audio',
    'createdAt': Timestamp.now(),
  });
}
```

### 4. PDF — Custom Path & Collection

```dart
Future<void> uploadDocument({
  required String projectId,
  required String userId,
  required String documentTitle,
}) async {
  final files = await _uploadService.pickMedia(
    type: CloudMediaType.file,
    maxCount: 1,
  );
  if (files.isEmpty) return;
  final file = files.first;
  final mediaId = const Uuid().v4();

  final storagePath = 'projects/$projectId/documents/$mediaId/${file.name}';

  final downloadUrl = await _uploadToStorage(
    filePath: file.path,
    storagePath: storagePath,
    contentType: 'application/pdf',
  );

  await FirebaseFirestore.instance
      .collection('projects')
      .doc(projectId)
      .collection('documents')
      .doc(mediaId)
      .set({
    'mediaId': mediaId,
    'userId': userId,
    'projectId': projectId,
    'title': documentTitle,
    'fileName': file.name,
    'downloadUrl': downloadUrl,
    'storagePath': storagePath,
    'mimeType': 'application/pdf',
    'size': await File(file.path).length(),
    'type': 'file',
    'createdAt': Timestamp.now(),
  });
}
```

### 5. Multiple Files — Batch Upload

```dart
Future<void> uploadMultipleImages({
  required String galleryId,
  required String userId,
}) async {
  final files = await _uploadService.pickMedia(
    type: CloudMediaType.image,
    maxCount: 10,
  );
  if (files.isEmpty) return;

  final futures = files.map((file) async {
    final mediaId = const Uuid().v4();
    final compressed = await _compressionService.compressImage(file.path);
    final thumbPath = await _thumbnailService.generateThumbnail(compressed, CloudMediaType.image);

    final storagePath = 'galleries/$galleryId/images/$mediaId.webp';
    final thumbStoragePath = 'galleries/$galleryId/thumbnails/$mediaId.webp';

    final downloadUrl = await _uploadToStorage(
      filePath: compressed,
      storagePath: storagePath,
      contentType: 'image/webp',
    );

    String thumbUrl = '';
    if (thumbPath != null) {
      thumbUrl = await _uploadToStorage(
        filePath: thumbPath,
        storagePath: thumbStoragePath,
        contentType: 'image/webp',
      );
    }

    return {
      'mediaId': mediaId,
      'userId': userId,
      'galleryId': galleryId,
      'downloadUrl': downloadUrl,
      'thumbnailUrl': thumbUrl,
      'storagePath': storagePath,
      'fileName': file.name,
      'size': await File(compressed).length(),
      'type': 'image',
      'createdAt': Timestamp.now(),
    };
  });

  final results = await Future.wait(futures);

  final batch = FirebaseFirestore.instance.batch();
  for (final data in results) {
    final ref = FirebaseFirestore.instance
        .collection('galleries')
        .doc(galleryId)
        .collection('images')
        .doc(data['mediaId'] as String);
    batch.set(ref, data);
  }
  await batch.commit();
}
```

### 6. With Background Removal — Custom Path

```dart
Future<void> uploadProductImage({
  required String productId,
  required String userId,
  required BuildContext context,
}) async {
  final files = await _uploadService.pickMedia(
    type: CloudMediaType.image,
    maxCount: 1,
  );
  if (files.isEmpty) return;
  final file = files.first;

  String processedPath = file.path;
  final mediaItem = CloudMediaItem(
    id: const Uuid().v4(),
    userId: userId,
    type: CloudMediaType.image,
    fileName: file.name,
    mimeType: file.mimeType,
    size: await File(file.path).length(),
    storagePath: '',
    downloadUrl: '',
    thumbnailUrl: '',
    status: CloudMediaStatus.pending,
    createdAt: DateTime.now(),
    localPath: file.path,
  );

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BackgroundRemovalScreen(
        media: mediaItem,
        onComplete: (path) {
          processedPath = path;
          Navigator.pop(context);
        },
      ),
    ),
  );

  final mediaId = const Uuid().v4();
  final compressed = await _compressionService.compressImage(processedPath);

  final storagePath = 'products/$productId/images/$mediaId.webp';
  final thumbStoragePath = 'products/$productId/thumbnails/$mediaId.webp';

  final downloadUrl = await _uploadToStorage(
    filePath: compressed,
    storagePath: storagePath,
    contentType: 'image/webp',
  );

  final thumbPath = await _thumbnailService.generateThumbnail(compressed, CloudMediaType.image);
  String thumbUrl = '';
  if (thumbPath != null) {
    thumbUrl = await _uploadToStorage(
      filePath: thumbPath,
      storagePath: thumbStoragePath,
      contentType: 'image/webp',
    );
  }

  await FirebaseFirestore.instance
      .collection('products')
      .doc(productId)
      .collection('images')
      .doc(mediaId)
      .set({
    'mediaId': mediaId,
    'userId': userId,
    'productId': productId,
    'downloadUrl': downloadUrl,
    'thumbnailUrl': thumbUrl,
    'storagePath': storagePath,
    'backgroundRemoved': true,
    'type': 'image',
    'createdAt': Timestamp.now(),
  });
}
```

### 7. With Cropping — Custom Path

```dart
Future<void> uploadCroppedAvatar({
  required String userId,
  required BuildContext context,
}) async {
  final files = await _uploadService.pickMedia(
    type: CloudMediaType.image,
    maxCount: 1,
  );
  if (files.isEmpty) return;
  final file = files.first;

  final cropped = await CroppingDialog.showSquareCrop(
    context: context,
    imagePath: file.path,
  );
  if (cropped == null) return;

  final compressed = await _compressionService.compressImage(cropped.path);
  final mediaId = const Uuid().v4();
  final storagePath = 'users/$userId/avatar/$mediaId.webp';

  final downloadUrl = await _uploadToStorage(
    filePath: compressed,
    storagePath: storagePath,
    contentType: 'image/webp',
  );

  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .update({
    'avatarUrl': downloadUrl,
    'avatarPath': storagePath,
    'avatarUpdatedAt': Timestamp.now(),
  });
}
```

### 8. Offline Queue — Custom Collection

```dart
Future<void> uploadWithOfflineSupport({
  required String postId,
  required String userId,
  required String filePath,
  required String mimeType,
  required String fileName,
}) async {
  final mediaId = const Uuid().v4();
  final storagePath = 'posts/$postId/media/$mediaId/$fileName';

  OfflineSyncLayer.instance.registerOperationHandler(
    'custom_post_upload',
    (data) async {
      final ref = FirebaseStorage.instance.ref(data['storagePath'] as String);
      await ref.putFile(
        File(data['filePath'] as String),
        SettableMetadata(contentType: data['mimeType'] as String),
      );
      final downloadUrl = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(data['postId'] as String)
          .collection('media')
          .doc(data['mediaId'] as String)
          .set({
        'mediaId': data['mediaId'],
        'downloadUrl': downloadUrl,
        'storagePath': data['storagePath'],
        'fileName': data['fileName'],
        'createdAt': Timestamp.now(),
      });
    },
  );

  await OfflineSyncLayer.instance.submitOperation(
    category: 'custom_post_upload',
    priority: 1,
    idempotencyKey: 'post_upload_$mediaId',
    data: {
      'filePath': filePath,
      'storagePath': storagePath,
      'postId': postId,
      'userId': userId,
      'mediaId': mediaId,
      'fileName': fileName,
      'mimeType': mimeType,
    },
  );
}
```

### 9. Read Back from Custom Collection

```dart
Future<List<CloudMediaItem>> getPostMedia(String postId) async {
  final snap = await FirebaseFirestore.instance
      .collection('posts')
      .doc(postId)
      .collection('media')
      .orderBy('createdAt', descending: true)
      .get();

  return snap.docs.map(CloudMediaItem.fromFirestore).toList();
}

Stream<List<CloudMediaItem>> watchPostMedia(String postId) {
  return FirebaseFirestore.instance
      .collection('posts')
      .doc(postId)
      .collection('media')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(CloudMediaItem.fromFirestore).toList());
}
```

### 10. Core Upload Helper

```dart
Future<String> _uploadToStorage({
  required String filePath,
  required String storagePath,
  required String contentType,
  Map<String, String>? customMetadata,
}) async {
  final ref = FirebaseStorage.instance.ref(storagePath);
  await ref.putFile(
    File(filePath),
    SettableMetadata(
      contentType: contentType,
      customMetadata: {
        'uploadedAt': DateTime.now().toIso8601String(),
        ...?customMetadata,
      },
    ),
  );
  return ref.getDownloadURL();
}
```

### Custom Path Patterns Reference

```dart
// Social
'posts/{postId}/media/{mediaId}'
'stories/{userId}/frames/{frameId}'
'users/{userId}/avatar/{mediaId}'

// E-commerce
'products/{productId}/images/{mediaId}'
'shops/{shopId}/banners/{mediaId}'

// Education
'courses/{courseId}/lessons/{lessonId}/videos/{mediaId}'

// Chat
'chats/{chatId}/attachments/{mediaId}'
'groups/{groupId}/media/{mediaId}'

// Business
'projects/{projectId}/documents/{mediaId}'
'invoices/{invoiceId}/attachments/{mediaId}'

// Music
'artists/{artistId}/albums/{albumId}/tracks/{mediaId}'
```

---

## Dependencies

| Package | Version |
|---------|---------|
| firebase_core | ^4.10.0 |
| firebase_auth | ^6.5.2 |
| firebase_storage | ^13.4.2 |
| cloud_firestore | ^6.5.0 |
| image_picker | ^1.1.2 |
| file_picker | ^12.0.0-beta.5 |
| video_player | ^2.9.2 |
| audioplayers | ^6.1.0 |
| flutter_image_compress | ^2.3.0 |
| image | ^4.2.0 |
| image_background_remover | ^2.0.0 |
| flutter_video_thumbnail_plus | ^1.0.6 |
| image_cropper | ^11.0.0 |
| photo_view | ^0.15.0 |
| cached_network_image | ^3.4.1 |
| riverpod_offline_sync | ^1.0.5 |
| hive_flutter | ^1.1.0 |
| permission_handler_package | ^1.0.6 |
| share_plus | ^13.1.0 |
| intl | ^0.20.2 |
| flutter_screenutil | ^5.9.3 |

---

## License

MIT

---

**Made with ❤️ for Flutter community**
```

## Summary of Changes Made

1. **Permissions section** - Updated all `PermissionService` calls to include `ref` parameter:
   - `await PermissionService.requestMediaPermissions(context, ref);`
   - `await PermissionService.requestCameraPermission(context, ref);`
   - `await PermissionService.requestStoragePermission(context, ref);`
   - `await PermissionService.requestMicrophonePermission(context, ref);`
   - `await PermissionService.openSettings(ref);`

2. **Error Handling section** - Updated `openSettings` call:
   - `await PermissionService.openSettings(ref);`

3. **Complete `main.dart` example** - Changed `HomePage` from `StatefulWidget` to `ConsumerStatefulWidget`:
   - `class HomePage extends ConsumerStatefulWidget`
   - `class _HomePageState extends ConsumerState<HomePage>`
   - Added `ref` parameter to `PermissionService` calls (none were present in this section as they were already properly using `ref`)

All other content remains exactly as it was in the original README. Only the specific permission-related methods were updated to include the required `ref` parameter.