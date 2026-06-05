import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../../models/cloud_media_item.dart';
import '../../utils/logger.dart';

// ─── Provider contract ────────────────────────────────────────────────────────

abstract class BackgroundRemovalProvider {
  Future<File> removeBackground(File image);
}

// ─── Default on-device provider ──────────────────────────────────────────────

class LocalBackgroundRemovalProvider implements BackgroundRemovalProvider {
  @override
  Future<File> removeBackground(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) return imageFile;

      final rgba = original.convert(numChannels: 4);
      final w = rgba.width;
      final h = rgba.height;

      final corners = [
        rgba.getPixel(0, 0),
        rgba.getPixel(w - 1, 0),
        rgba.getPixel(0, h - 1),
        rgba.getPixel(w - 1, h - 1),
      ];

      int bgR = 0, bgG = 0, bgB = 0;
      for (final p in corners) {
        bgR += p.r.toInt();
        bgG += p.g.toInt();
        bgB += p.b.toInt();
      }
      bgR ~/= 4;
      bgG ~/= 4;
      bgB ~/= 4;

      const int tolerance = 30;

      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final pixel = rgba.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();

          if ((r - bgR).abs() < tolerance &&
              (g - bgG).abs() < tolerance &&
              (b - bgB).abs() < tolerance) {
            rgba.setPixelRgba(x, y, r, g, b, 0);
          }
        }
      }

      final pngBytes = img.encodePng(rgba);
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/cm_bg_removed_${DateTime.now().millisecondsSinceEpoch}.png';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(pngBytes);

      CloudLogger.debug('Background removed: $outputPath');
      return outputFile;
    } catch (e, st) {
      CloudLogger.error('Background removal failed', error: e, stackTrace: st);
      return imageFile;
    }
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

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

class _BackgroundRemovalScreenState extends State<BackgroundRemovalScreen> {
  _Status _status = _Status.processing;
  String? _errorMessage;
  Timer? _timeout;
  double _progress = 0.0;

  static const _timeoutDuration = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _startRemoval();
  }

  @override
  void dispose() {
    _timeout?.cancel();
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
          _errorMessage = 'Background removal timed out after 30 seconds.';
        });
      }
    });

    _tickProgress();

    try {
      final localPath = widget.media.localPath ?? '';
      if (localPath.isEmpty) throw Exception('No local file path available.');

      final provider = widget.provider ?? LocalBackgroundRemovalProvider();
      final result = await provider.removeBackground(File(localPath));

      _timeout?.cancel();

      if (mounted) {
        setState(() {
          _status = _Status.done;
          _progress = 1.0;
        });
        await Future.delayed(const Duration(milliseconds: 800));
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
                    value: _progress,
                    strokeWidth: 6,
                  ),
                ),
                Text(
                  '${(_progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Removing background…',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
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
            Icon(Icons.check_circle, color: Colors.green, size: 80),
            SizedBox(height: 16),
            Text('Background removed!',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
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
              style: TextStyle(color: Colors.grey, fontSize: 13),
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
