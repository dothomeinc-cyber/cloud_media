import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/cloud_media_api.dart';
import '../../models/cloud_media_item.dart';
import '../../models/cloud_media_type.dart';
import '../widgets/media_grid.dart';

class MediaLibraryScreen extends ConsumerStatefulWidget {
  const MediaLibraryScreen({super.key, this.type, this.onMediaTap});
  final CloudMediaType? type;
  final void Function(CloudMediaItem)? onMediaTap;

  @override
  ConsumerState<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends ConsumerState<MediaLibraryScreen> {
  List<CloudMediaItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await CloudMedia.list(type: widget.type);
      if (mounted) {
        setState(() { _items = items; _loading = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type?.displayName ?? 'Media Library'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _items.isEmpty
                  ? const Center(child: Text('No media yet'))
                  : MediaGrid(mediaItems: _items, onItemTap: widget.onMediaTap),
    );
  }
}
