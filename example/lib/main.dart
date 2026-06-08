// Hide SyncStatusIndicator from riverpod_offline_sync to avoid conflict
// with cloud_media's own SyncStatusIndicator widget.
import 'package:riverpod_offline_sync/riverpod_offline_sync.dart'
    hide SyncStatusIndicator;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler_package/permission_handler_package.dart';
import 'package:cloud_media/cloud_media.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await PermissionHandler.initialize();
  await OfflineSyncLayer.instance.initialize(
    config: const SyncConfig(
      autoSyncOnReconnect: true,
      syncImmediately: true,
      maxConcurrentOperations: 2,
      enableMetrics: true,
      syncOnWiFiOnly: false,
      maxRetries: 5,
      initialRetryDelay: Duration(seconds: 2),
      maxQueueSize: 500,
    ),
  );
  await CloudMedia.initialize(
    config: const CloudMediaConfig(
      imageQuality: 85,
      maxSelection: 20,
      enableOfflineSync: true,
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
          theme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true),
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
  ConsumerState<ExampleScreen> createState() =>
      _ExampleScreenState();
}

class _ExampleScreenState
    extends ConsumerState<ExampleScreen> {
  List<CloudMediaItem> _items = [];
  bool _loading = false;

  Future<void> _pickImage() async {
    try {
      final items =
          await CloudMedia.pick(type: CloudMediaType.image);
      setState(() => _items = [..._items, ...items]);
      _snack('Picked ${items.length} image(s)');
    } catch (e) {
      _snack('Error: $e', error: true);
    }
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final items = await CloudMedia.list();
      setState(() => _items = items);
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
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
        // SyncStatusIndicator from cloud_media (not riverpod_offline_sync)
        actions: [
          SyncStatusIndicator(showLabel: false),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Pick Image'),
                ),
                ElevatedButton.icon(
                  onPressed: _loadAll,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Load All'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(
                        child: Text('No media yet'))
                    : MediaGrid(
                        mediaItems: _items,
                        onItemTap: (item) =>
                            CloudMedia.share(item.id),
                        onItemLongPress: (item) async {
                          await CloudMedia.delete(item.id);
                          setState(() => _items.removeWhere(
                              (i) => i.id == item.id));
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: PermissionAwareMediaPicker(
        mediaType: CloudMediaType.image,
        maxCount: 5,
        onMediaSelected: (_) => _loadAll(),
        child: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.add_photo_alternate),
        ),
      ),
    );
  }
}
