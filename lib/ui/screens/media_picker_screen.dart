import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/cloud_media_config.dart';
import '../../models/cloud_media_type.dart';
import '../../services/permission_service.dart';
import '../../services/upload_service.dart';
import '../../utils/error_handler.dart';

class MediaPickerScreen extends ConsumerStatefulWidget {
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
  ConsumerState<MediaPickerScreen> createState() =>
      _MediaPickerScreenState();
}

class _MediaPickerScreenState
    extends ConsumerState<MediaPickerScreen> {
  late final UploadService _uploadService;
  String _statusText = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _uploadService = UploadService(config: widget.config);
    _checkPermissionsAndPick();
  }

  Future<void> _checkPermissionsAndPick() async {
    setState(
        () => _statusText = 'Requesting permissions...');

    try {
      switch (widget.mediaType) {
        case CloudMediaType.image:
        case CloudMediaType.video:
          await PermissionService.requestMediaPermissions(
              context, ref);
          break;
        case CloudMediaType.audio:
          await PermissionService
              .requestMicrophonePermission(context, ref);
          break;
        case CloudMediaType.file:
          await PermissionService.requestStoragePermission(
              context, ref);
          break;
      }

      setState(
          () => _statusText = 'Opening media picker...');

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
        await PermissionService.openSettings(ref);
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
            Theme.of(context).platform == TargetPlatform.iOS ||
                    Theme.of(context).platform == TargetPlatform.macOS
                ? const CupertinoActivityIndicator()
                : const CircularProgressIndicator(),
            SizedBox(height: 16.h),
            Text(_statusText,
                style: TextStyle(fontSize: 14.sp)),
          ],
        ),
      ),
    );
  }
}
