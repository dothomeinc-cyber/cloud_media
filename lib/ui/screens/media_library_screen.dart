import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../api/cloud_media_api.dart';
import '../../models/cloud_media_item.dart';
import '../../models/cloud_media_type.dart';
import '../widgets/media_grid.dart';

class MediaLibraryScreen extends ConsumerStatefulWidget {
  const MediaLibraryScreen(
      {super.key, this.type, this.onMediaTap, this.showUploadControls = false});
  final CloudMediaType? type;
  final void Function(CloudMediaItem)? onMediaTap;

  /// Passed through to [MediaGrid.showUploadControls] — set this to
  /// `true` for a screen dedicated to managing in-flight uploads.
  final bool showUploadControls;

  @override
  ConsumerState<MediaLibraryScreen> createState() =>
      _MediaLibraryScreenState();
}

class _MediaLibraryScreenState
    extends ConsumerState<MediaLibraryScreen> {
  List<CloudMediaItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items =
          await CloudMedia.list(type: widget.type);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.type?.displayName ?? 'Media Library',
          style: TextStyle(fontSize: 18.sp),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: 20.r),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Theme.of(context).platform == TargetPlatform.iOS ||
                      Theme.of(context).platform == TargetPlatform.macOS
                  ? const CupertinoActivityIndicator()
                  : const CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: TextStyle(
                        fontSize: 14.sp, color: Theme.of(context).colorScheme.error),
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Text(
                        'No media yet',
                        style: TextStyle(
                            fontSize: 16.sp,
                            color: Theme.of(context).colorScheme.outline),
                      ),
                    )
                  : MediaGrid(
                      mediaItems: _items,
                      onItemTap: widget.onMediaTap,
                      showUploadControls: widget.showUploadControls,
                    ),
    );
  }
}
