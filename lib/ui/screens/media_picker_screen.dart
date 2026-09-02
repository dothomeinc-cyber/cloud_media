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
    this.onError,
    this.config = const CloudMediaConfig(),
  });

  final CloudMediaType mediaType;
  final int maxCount;
  final Function(List<PickedFile>) onMediaSelected;

  /// Called just before this screen pops itself due to a permission
  /// denial, permanent denial, or any other error during permission
  /// request / picking — with the exception that caused it. Optional:
  /// if omitted, the screen still pops the same way it always did, just
  /// without telling the caller why. [onMediaSelected] is never called
  /// in these cases.
  final void Function(Object error)? onError;

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
          // This screen only ever picks from the gallery (see
          // _uploadService.pickMedia below) — it never opens the camera —
          // so only the read-access permission for the media type is
          // needed, not camera.
          await PermissionService.requestMediaReadPermission(
              widget.mediaType, context, ref);
          break;
        case CloudMediaType.audio:
          // FilePicker.pickFile/pickFiles below selects existing audio
          // files — it doesn't record — so this needs the audio-library
          // *read* permission (Permission.audio / READ_MEDIA_AUDIO on
          // Android 13+), not microphone. Request microphone separately,
          // only for a flow that actually records.
          await PermissionService.requestMediaReadPermission(
              CloudMediaType.audio, context, ref);
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
    } on CloudMediaPermissionPermanentlyDeniedException catch (e) {
      widget.onError?.call(e);
      if (mounted) {
        Navigator.pop(context);
        await PermissionService.openSettings(ref);
      }
    } on CloudMediaPermissionDeniedException catch (e) {
      widget.onError?.call(e);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      widget.onError?.call(e);
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
