import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_background_remover/image_background_remover.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/cloud_media_item.dart';
import '../../utils/logger.dart';

/// Abstract contract for background removal providers.
abstract class BackgroundRemovalProvider {
  /// Called once when the provider is first used.
  Future<void> initialize();

  /// Remove the background from [image] and return the processed [File].
  Future<File> removeBackground(File image);

  /// Release resources. Call when the provider is no longer needed.
  void dispose();
}

/// Default on-device provider using image_background_remover ONNX model.
///
/// Initializes the ONNX session once and reuses it across multiple calls.
/// Call [dispose] only when you are completely done with background removal
/// (e.g. when the feature screen is permanently closed).
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
    // Initialize once — reuse session for subsequent calls
    await initialize();

    try {
      final bytes = await imageFile.readAsBytes();

      // removeBg returns ui.Image with transparent background
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
      return imageFile; // graceful fallback
    }
    // NOTE: No dispose() here — session is reused across calls
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
///
/// Manages the provider lifecycle — initializes on first use and disposes
/// only when the screen is permanently closed.
class BackgroundRemovalScreen extends StatefulWidget {
  const BackgroundRemovalScreen({
    super.key,
    required this.media,
    required this.onComplete,
    this.provider,
  });

  final CloudMediaItem media;
  final void Function(String processedPath) onComplete;

  /// Optional custom provider. Defaults to [LocalBackgroundRemovalProvider].
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
    // Use provided provider or create default — owned by this screen
    _provider =
        widget.provider ?? LocalBackgroundRemovalProvider();
    _startRemoval();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    // Dispose ONNX session here — screen is permanently closing
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
        throw Exception('No local file path available.');

      // Session is initialized once inside provider and reused on retry
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
        title: const Text('Remove Background'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _useOriginal,
          tooltip: 'Use original',
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
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
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                      value: _progress, strokeWidth: 6),
                ),
                Text(
                  '${(_progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Removing background…',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('This may take up to 30 seconds.',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _useOriginal,
              child: const Text('Cancel — use original'),
            ),
          ],
        );

      case _Status.done:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle,
                color: Colors.green, size: 80),
            SizedBox(height: 16),
            Text('Background removed!',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
          ],
        );

      case _Status.timedOut:
      case _Status.failed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 80),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can retry or continue with the original image.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _useOriginal,
                  icon: const Icon(Icons.image),
                  label: const Text('Use Original'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  // Retry reuses the existing session — no re-init needed
                  onPressed: _startRemoval,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ],
        );
    }
  }
}

enum _Status { processing, done, timedOut, failed }
