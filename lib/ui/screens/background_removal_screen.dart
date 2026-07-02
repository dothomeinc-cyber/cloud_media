import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/background_removal_service.dart';

/// Background removal screen using native_cutout.
///
/// This screen is optional. CloudMedia.pick() can also run the same service
/// directly when no UI context is available.
class BackgroundRemovalScreen extends StatefulWidget {
  const BackgroundRemovalScreen({
    super.key,
    required this.imagePath,
    this.cropToSubject = true,
    this.service = const BackgroundRemovalService(),
  });

  final String imagePath;
  final bool cropToSubject;
  final BackgroundRemovalService service;

  @override
  State<BackgroundRemovalScreen> createState() =>
      _BackgroundRemovalScreenState();
}

class _BackgroundRemovalScreenState extends State<BackgroundRemovalScreen> {
  _Status _status = _Status.processing;
  String? _errorMessage;
  Timer? _timeout;
  double _progress = 0.0;

  static const _timeoutDuration = Duration(seconds: 60);

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
          _errorMessage = 'Background removal timed out.';
        });
      }
    });

    _tickProgress();

    try {
      if (!File(widget.imagePath).existsSync()) {
        throw Exception('No local file path available.');
      }

      final result = await widget.service.removeBackground(
        widget.imagePath,
        cropToSubject: widget.cropToSubject,
      );

      _timeout?.cancel();
      if (!mounted) return;

      setState(() {
        _status = _Status.done;
        _progress = 1.0;
      });

      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.of(context).pop(result);
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
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _status == _Status.processing) {
        setState(() {
          if (_progress < 0.9) _progress += 0.04;
        });
        _tickProgress();
      }
    });
  }

  void _useOriginal() {
    _timeout?.cancel();
    Navigator.of(context).pop(widget.imagePath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Remove Background', style: TextStyle(fontSize: 18.sp)),
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
            SizedBox(
              width: 80.r,
              height: 80.r,
              child: Theme.of(context).platform == TargetPlatform.iOS ||
                      Theme.of(context).platform == TargetPlatform.macOS
                  ? const CupertinoActivityIndicator(radius: 20)
                  : CircularProgressIndicator(value: _progress),
            ),
            SizedBox(height: 24.h),
            Text('Removing background…', style: TextStyle(fontSize: 18.sp)),
            SizedBox(height: 8.h),
            Text('First Android run may download the ML Kit model.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13.sp)),
            SizedBox(height: 24.h),
            TextButton(onPressed: _useOriginal, child: const Text('Use original')),
          ],
        );
      case _Status.done:
        return Icon(Icons.check_circle,
            color: Theme.of(context).colorScheme.primary, size: 80.r);
      case _Status.timedOut:
      case _Status.failed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                color: Theme.of(context).colorScheme.error, size: 64.r),
            SizedBox(height: 16.h),
            Text(_errorMessage ?? 'Something went wrong.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 14.sp)),
            SizedBox(height: 16.h),
            ElevatedButton(onPressed: _startRemoval, child: const Text('Retry')),
            TextButton(onPressed: _useOriginal, child: const Text('Use original')),
          ],
        );
    }
  }
}

enum _Status { processing, done, timedOut, failed }
