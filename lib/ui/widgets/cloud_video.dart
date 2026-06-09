import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';
import '../../models/cloud_media_item.dart';

class CloudVideo extends StatefulWidget {
  const CloudVideo({
    super.key,
    required this.media,
    this.width,
    this.height,
    this.autoPlay = false,
    this.showControls = true,
  });

  final CloudMediaItem media;
  final double? width;
  final double? height;
  final bool autoPlay;
  final bool showControls;

  @override
  State<CloudVideo> createState() => _CloudVideoState();
}

class _CloudVideoState extends State<CloudVideo> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final url = widget.media.downloadUrl.isNotEmpty
        ? widget.media.downloadUrl
        : widget.media.localPath;
    if (url == null || url.isEmpty) return;

    _controller = url.startsWith('/')
        ? VideoPlayerController.file(File(url))
        : VideoPlayerController.networkUrl(Uri.parse(url));

    await _controller!.initialize();
    if (widget.autoPlay) {
      await _controller!.play();
      _isPlaying = true;
    }
    if (mounted) setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isPlaying
          ? _controller!.pause()
          : _controller!.play();
      _isPlaying = !_isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Apply screenutil scaling using null-aware operator
    final finalWidth = widget.width?.w;
    final finalHeight = widget.height?.h;

    if (!_initialized || _controller == null) {
      return Container(
        width: finalWidth,
        height: finalHeight,
        color: Colors.black,
        child: const Center(
            child: CircularProgressIndicator()),
      );
    }

    return Container(
      width: finalWidth,
      height: finalHeight,
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
          if (widget.showControls)
            Positioned(
              bottom: 16.h,
              right: 16.w,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                radius: 20.r,
                child: IconButton(
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                    size: 20.r,
                  ),
                  onPressed: _toggle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
