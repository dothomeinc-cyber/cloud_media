import 'package:flutter/material.dart';
import '../../models/cloud_media_config.dart';
import '../../models/cloud_media_type.dart';
import '../../services/permission_service.dart';
import '../../services/upload_service.dart';
import '../../utils/error_handler.dart';

class MediaPickerScreen extends StatefulWidget {
  const MediaPickerScreen({
    super.key,
    required this.mediaType,
    required this.maxCount,
    required this.onMediaSelected,
    this.config = const CloudMediaConfig(),
  });

  final CloudMediaType mediaType;
  final int maxCount;
  final Function(List<PickedFile>) onMediaSelected;
  final CloudMediaConfig config;

  @override
  State<MediaPickerScreen> createState() => _MediaPickerScreenState();
}

class _MediaPickerScreenState extends State<MediaPickerScreen> {
  late final UploadService _uploadService;
  String _statusText = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _uploadService = UploadService(config: widget.config);
    _checkPermissionsAndPick();
  }

  Future<void> _checkPermissionsAndPick() async {
    setState(() => _statusText = 'Requesting permissions...');

    try {
      switch (widget.mediaType) {
        case CloudMediaType.image:
        case CloudMediaType.video:
          await PermissionService.requestMediaPermissions(context);
          break;
        case CloudMediaType.audio:
          await PermissionService.requestMicrophonePermission(context);
          break;
        case CloudMediaType.file:
          await PermissionService.requestStoragePermission(context);
          break;
      }

      setState(() => _statusText = 'Opening media picker...');

      final picked = await _uploadService.pickMedia(
        type: widget.mediaType,
        maxCount: widget.maxCount,
      );

      if (mounted) {
        widget.onMediaSelected(picked);
        Navigator.pop(context);
      }
    } on CloudMediaPermissionPermanentlyDeniedException {
      if (mounted) {
        Navigator.pop(context);
        await PermissionService.openSettings();
      }
    } on CloudMediaPermissionDeniedException {
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_statusText),
          ],
        ),
      ),
    );
  }
}
