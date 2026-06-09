import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_background_remover/image_background_remover.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/cloud_media_item.dart';
import '../../utils/logger.dart';

/// Abstract contract for background removal providers.
abstract class BackgroundRemovalProvider {
  Future<void> initialize();
  Future<File> removeBackground(File image);
  void dispose();
}

/// Default on-device provider using image_background_remover ONNX model.
class LocalBackgroundRemovalProvider
    implements BackgroundRemovalProvider {
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await BackgroundRemover.instance.initializeOrt();
    _initialized = true;
    CloudLogger.info(
        'BackgroundRemover ONNX session initialized');
  }

  @override
  Future<File> removeBackground(File imageFile) async {
    await initialize();

    try {
      final bytes = await imageFile.readAsBytes();
      final ui.Image resultImage =
          await BackgroundRemover.instance.removeBg(bytes);

      final byteData = await resultImage.toByteData(
          format: ui.ImageByteFormat.png);
      resultImage.dispose();

      if (byteData == null) {
        CloudLogger.warning(
            'BackgroundRemover: byteData null, using original');
        return imageFile;
      }

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/cm_bg_removed_${DateTime.now().millisecondsSinceEpoch}.png';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(pngBytes);

      CloudLogger.debug('Background removed: $outputPath');
      return outputFile;
    } catch (e, st) {
      CloudLogger.error('Background removal failed',
          error: e, stackTrace: st);
      return imageFile;
    }
  }

  @override
  void dispose() {
    if (!_initialized) return;
    BackgroundRemover.instance.dispose();
    _initialized = false;
    CloudLogger.info(
        'BackgroundRemover ONNX session disposed');
  }
}

/// Background removal screen with 30s timeout, retry, use-original fallback.
class BackgroundRemovalScreen extends StatefulWidget {
  const BackgroundRemovalScreen({
    super.key,
    required this.media,
    required this.onComplete,
    this.provider,
  });

  final CloudMediaItem media;
  final void Function(String processedPath) onComplete;
  final BackgroundRemovalProvider? provider;

  @override
  State<BackgroundRemovalScreen> createState() =>
      _BackgroundRemovalScreenState();
}

class _BackgroundRemovalScreenState
    extends State<BackgroundRemovalScreen> {
  late final BackgroundRemovalProvider _provider;
  _Status _status = _Status.processing;
  String? _errorMessage;
  Timer? _timeout;
  double _progress = 0.0;

  static const _timeoutDuration = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _provider =
        widget.provider ?? LocalBackgroundRemovalProvider();
    _startRemoval();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _provider.dispose();
    super.dispose();
  }

  Future<void> _startRemoval() async {
    setState(() {
      _status = _Status.processing;
      _errorMessage = null;
      _progress = 0.0;
    });

    _timeout = Timer(_timeoutDuration, () {
      if (mounted && _status == _Status.processing) {
        setState(() {
          _status = _Status.timedOut;
          _errorMessage =
              'Background removal timed out after 30 seconds.';
        });
      }
    });

    _tickProgress();

    try {
      final localPath = widget.media.localPath ?? '';
      if (localPath.isEmpty)
        // ignore: curly_braces_in_flow_control_structures
        throw Exception('No local file path available.');

      final result =
          await _provider.removeBackground(File(localPath));

      _timeout?.cancel();

      if (mounted) {
        setState(() {
          _status = _Status.done;
          _progress = 1.0;
        });
        await Future.delayed(
            const Duration(milliseconds: 800));
        if (mounted) widget.onComplete(result.path);
      }
    } catch (e) {
      _timeout?.cancel();
      if (mounted) {
        setState(() {
          _status = _Status.failed;
          _errorMessage = 'Background removal failed: $e';
        });
      }
    }
  }

  void _tickProgress() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _status == _Status.processing) {
        setState(() {
          if (_progress < 0.9) _progress += 0.05;
        });
        _tickProgress();
      }
    });
  }

  void _useOriginal() {
    _timeout?.cancel();
    final original = widget.media.localPath ?? '';
    if (original.isNotEmpty) widget.onComplete(original);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Remove Background',
            style: TextStyle(fontSize: 18.sp)),
        leading: IconButton(
          icon: Icon(Icons.close, size: 24.r),
          onPressed: _useOriginal,
          tooltip: 'Use original',
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _Status.processing:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80.r,
                  height: 80.r,
                  child: CircularProgressIndicator(
                      value: _progress, strokeWidth: 6.w),
                ),
                Text(
                  '${(_progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            Text(
              'Removing background…',
              style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8.h),
            Text(
              'This may take up to 30 seconds.',
              style: TextStyle(
                  color: Colors.grey, fontSize: 14.sp),
            ),
            SizedBox(height: 24.h),
            TextButton(
              onPressed: _useOriginal,
              child: Text('Cancel — use original',
                  style: TextStyle(fontSize: 14.sp)),
            ),
          ],
        );

      case _Status.done:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle,
                color: Colors.green, size: 80.r),
            SizedBox(height: 16.h),
            Text(
              'Background removed!',
              style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600),
            ),
          ],
        );

      case _Status.timedOut:
      case _Status.failed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 80.r),
            SizedBox(height: 16.h),
            Text(
              _errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              'You can retry or continue with the original image.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey, fontSize: 13.sp),
            ),
            SizedBox(height: 28.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _useOriginal,
                  icon: Icon(Icons.image, size: 18.r),
                  label: Text('Use Original',
                      style: TextStyle(fontSize: 14.sp)),
                ),
                SizedBox(width: 16.w),
                ElevatedButton.icon(
                  onPressed: _startRemoval,
                  icon: Icon(Icons.refresh, size: 18.r),
                  label: Text('Retry',
                      style: TextStyle(fontSize: 14.sp)),
                ),
              ],
            ),
          ],
        );
    }
  }
}

enum _Status { processing, done, timedOut, failed }
