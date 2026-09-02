import 'package:cloud_media/cloud_media.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // CloudMedia.initialize() is the ONLY setup call a consuming app needs —
  // it initializes riverpod_offline_sync and permission_handler_package
  // internally (see CloudMediaProvider.initialize()). Calling
  // OfflineSyncLayer.instance.initialize() or PermissionHandler.initialize()
  // yourself before this is unnecessary and, if you pass a different
  // SyncConfig than cloud_media uses internally, silently ignored —
  // whichever initialize() call runs first wins, since both are
  // idempotent no-ops on a second call.
  await CloudMedia.initialize(
    config: const CloudMediaConfig(
      imageQuality: 85,
      maxSelection: 20,
      enableOfflineSync: true,
      enableBackgroundRemoval: true,
      enableReviewScreen: true,
      enableLogging: true,
    ),
  );

  runApp(const ProviderScope(child: ExampleApp()));
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'CloudMedia Example',
          theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
          home: child,
          debugShowCheckedModeBanner: false,
        );
      },
      child: const ExampleScreen(),
    );
  }
}

class ExampleScreen extends ConsumerStatefulWidget {
  const ExampleScreen({super.key});

  @override
  ConsumerState<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends ConsumerState<ExampleScreen> {
  List<CloudMediaItem> _items = [];
  bool _loading = false;

  // ── Pick flows — each demonstrates a different combination of options ──

  Future<void> _pickImageSimple() async {
    await _pick(() => CloudMedia.pick(
          context: context,
          type: CloudMediaType.image,
        ));
  }

  Future<void> _pickImageWithEditingAndCrop() async {
    await _pick(() => CloudMedia.pick(
          context: context,
          type: CloudMediaType.image,
          enableEditing: true, // crop/rotate via the built-in editor screen
          showPreview: true, // confirm before upload starts
        ));
  }

  Future<void> _pickImageWithBackgroundRemoval() async {
    await _pick(() => CloudMedia.pick(
          context: context,
          type: CloudMediaType.image,
          enableBackgroundRemoval: true,
          showPreview: true,
        ));
  }

  Future<void> _pickProductPhoto() async {
    await _pick(() => CloudMedia.pick(
          context: context,
          type: CloudMediaType.image,
          enableEditing: true,
          showPreview: true,
          folder: 'products',
          compressionProfile: CompressionProfile.product,
        ));
  }

  Future<void> _pickVideo() async {
    await _pick(() => CloudMedia.pick(
          context: context,
          type: CloudMediaType.video,
        ));
  }

  Future<void> _pickAudio() async {
    await _pick(() => CloudMedia.pick(
          context: context,
          type: CloudMediaType.audio,
        ));
  }

  Future<void> _pickDocument() async {
    await _pick(() => CloudMedia.pick(
          context: context,
          type: CloudMediaType.file,
        ));
  }

  Future<void> _pick(Future<List<CloudMediaItem>> Function() picker) async {
    try {
      final items = await picker();
      if (items.isEmpty) return; // user cancelled the OS picker or preview
      setState(() => _items = [..._items, ...items]);
      _snack('Picked ${items.length} item(s) — uploading in the background');
    } on CloudMediaPermissionPermanentlyDeniedException {
      // CloudMedia.pick() already shows PermissionManager's own
      // permanently-denied dialog with an "Open Settings" action before
      // this exception is even thrown (see
      // CloudMediaProvider._ensureReadPermission) — this catch clause
      // only needs to inform the rest of this screen's own UI.
      _snack('Permission permanently denied', error: true);
    } on CloudMediaPermissionDeniedException {
      _snack('Permission denied', error: true);
    } catch (e) {
      _snack('Error: ${ErrorHandler.getUserFriendlyMessage(e)}', error: true);
    }
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final items = await CloudMedia.list();
      setState(() => _items = items);
    } catch (e) {
      _snack('Error: ${ErrorHandler.getUserFriendlyMessage(e)}', error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CloudMedia Example'),
        actions: [
          const SyncStatusIndicator(showLabel: false),
          SizedBox(width: 8.w),
        ],
      ),
      body: CloudMediaUploadOverlay.wrap(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImageSimple,
                    icon: const Icon(Icons.image),
                    label: const Text('Pick Image'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _pickImageWithEditingAndCrop,
                    icon: const Icon(Icons.crop),
                    label: const Text('Pick + Edit/Crop'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _pickImageWithBackgroundRemoval,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Pick + Remove BG'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _pickProductPhoto,
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Product Photo'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _pickVideo,
                    icon: const Icon(Icons.videocam),
                    label: const Text('Pick Video'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _pickAudio,
                    icon: const Icon(Icons.audiotrack),
                    label: const Text('Pick Audio'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _pickDocument,
                    icon: const Icon(Icons.insert_drive_file),
                    label: const Text('Pick PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loadAll,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reload from Firestore'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(child: Text('No media yet'))
                      : MediaGrid(
                          mediaItems: _items,
                          showUploadControls: true,
                          onItemTap: (item) => CloudMedia.share(item.id),
                          onItemLongPress: (item) async {
                            try {
                              final deleted = await CloudMedia.showDeleteDialog(
                                  context, item);
                              if (deleted) {
                                setState(() =>
                                    _items.removeWhere((i) => i.id == item.id));
                              }
                            } catch (e) {
                              // User confirmed, but the delete itself failed
                              // (network error, permission issue, etc.) —
                              // showDeleteDialog rethrows in this case rather
                              // than returning false, so it isn't confused
                              // with the user simply cancelling.
                              _snack(
                                  'Delete failed: ${ErrorHandler.getUserFriendlyMessage(e)}',
                                  error: true);
                            }
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
