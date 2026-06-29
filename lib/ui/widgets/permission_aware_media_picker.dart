import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/cloud_media_type.dart';
import '../../services/permission_service.dart';
import '../../services/upload_service.dart';
import '../../utils/error_handler.dart';
import '../screens/media_picker_screen.dart';

class PermissionAwareMediaPicker
    extends ConsumerStatefulWidget {
  const PermissionAwareMediaPicker({
    super.key,
    required this.mediaType,
    required this.maxCount,
    required this.onMediaSelected,
    required this.child,
    this.permissionTitle,
    this.permissionMessage,
  });

  final CloudMediaType mediaType;
  final int maxCount;
  final Function(List<PickedFile>) onMediaSelected;
  final Widget child;
  final String? permissionTitle;
  final String? permissionMessage;

  @override
  ConsumerState<PermissionAwareMediaPicker> createState() =>
      _PermissionAwareMediaPickerState();
}

class _PermissionAwareMediaPickerState
    extends ConsumerState<PermissionAwareMediaPicker> {
  bool _isRequesting = false;

  Future<void> _handlePress() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);

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

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MediaPickerScreen(
            mediaType: widget.mediaType,
            maxCount: widget.maxCount,
            onMediaSelected: widget.onMediaSelected,
          ),
        ),
      );
    } on CloudMediaPermissionPermanentlyDeniedException {
      if (mounted) {
        _showSnack(
          widget.permissionMessage ??
              'Permission permanently denied. Please enable it in Settings.',
        );
        await PermissionService.openSettings(ref);
      }
    } on CloudMediaPermissionDeniedException {
      if (mounted) {
        _showSnack(
          widget.permissionMessage ??
              'Permission denied. Please grant access to continue.',
        );
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: TextStyle(fontSize: 14.sp)),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handlePress,
      child: AbsorbPointer(
        absorbing: _isRequesting,
        child: Stack(
          children: [
            widget.child,
            if (_isRequesting)
              Positioned.fill(
                child: Container(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(31),
                  child: Center(
                    child: Theme.of(context).platform == TargetPlatform.iOS ||
                            Theme.of(context).platform == TargetPlatform.macOS
                        ? const CupertinoActivityIndicator()
                        : const CircularProgressIndicator(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
