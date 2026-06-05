import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/cloud_media_item.dart';
import '../../utils/error_handler.dart';

/// Background removal screen with 30-second timeout per spec.
/// Pluggable via [BackgroundRemovalProvider].
/// User can always continue with the original image.
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
  _Status _status = _Status.processing;
  String? _errorMessage;
  Timer? _timeout;

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
    setState(() => _status = _Status.processing);

    _timeout = Timer(_timeoutDuration, () {
      if (mounted && _status == _Status.processing) {
        setState(() {
          _status = _Status.timedOut;
          _errorMessage = 'Background removal timed out after 30 seconds.';
        });
      }
    });

    try {
      final provider = widget.provider ?? LocalBackgroundRemovalProvider();
      final localPath = widget.media.localPath ?? '';
      if (localPath.isEmpty) throw Exception('No local file path available.');

      final result = await provider.removeBackground(File(localPath));

      _timeout?.cancel();
      if (mounted) {
        setState(() => _status = _Status.done);
        widget.onComplete(result.path);
      }
    } catch (e) {
      _timeout?.cancel();
      if (mounted) {
        setState(() {
          _status = _Status.failed;
          _errorMessage = e is CloudMediaBackgroundRemovalTimeoutException
              ? e.message
              : 'Background removal failed: $e';
        });
      }
    }
  }

  void _useOriginal() {
    final original = widget.media.localPath ?? '';
    if (original.isNotEmpty) widget.onComplete(original);
    Navigator.pop(context);
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
          child: switch (_status) {
            _Status.processing => const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 24),
                  Text('Removing background…',
                      style: TextStyle(fontSize: 16)),
                  SizedBox(height: 8),
                  Text('This may take up to 30 seconds.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            _Status.done => const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.green, size: 64),
                  SizedBox(height: 16),
                  Text('Background removed!'),
                ],
              ),
            _Status.timedOut || _Status.failed => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage ?? 'Something went wrong.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: _useOriginal,
                        child: const Text('Use Original'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _startRemoval,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ],
              ),
          },
        ),
      ),
    );
  }
}

enum _Status { processing, done, timedOut, failed }

// ── Provider contract ────────────────────────────────────────────────────────

abstract class BackgroundRemovalProvider {
  Future<File> removeBackground(File image);
}

/// Stub local implementation — swap for remove_bg or ML Kit.
class LocalBackgroundRemovalProvider implements BackgroundRemovalProvider {
  @override
  Future<File> removeBackground(File image) async {
    // TODO: integrate a real segmentation model (remove_bg, ML Kit, rembg)
    await Future.delayed(const Duration(seconds: 2)); // simulate work
    return image; // return original as placeholder
  }
}
