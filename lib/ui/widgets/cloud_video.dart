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

  @override
  void didUpdateWidget(covariant CloudVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent rebuilds this widget in place with a different
    // media item (e.g. a PageView or GridView recycling this State
    // object at the same tree position without a distinguishing Key),
    // the old controller is pointed at the wrong file/URL entirely —
    // re-initialize for the new item rather than silently continuing
    // to show the previous video.
    final oldUrl = oldWidget.media.downloadUrl.isNotEmpty
        ? oldWidget.media.downloadUrl
        : oldWidget.media.localPath;
    final newUrl = widget.media.downloadUrl.isNotEmpty
        ? widget.media.downloadUrl
        : widget.media.localPath;
    if (oldUrl != newUrl) {
      final oldController = _controller;
      _controller = null;
      _initialized = false;
      _isPlaying = false;
      oldController?.dispose();
      _init();
    }
  }

  Future<void> _init() async {
    final url = widget.media.downloadUrl.isNotEmpty
        ? widget.media.downloadUrl
        : widget.media.localPath;
    if (url == null || url.isEmpty) return;

    final controller = url.startsWith('/')
        ? VideoPlayerController.file(File(url))
        : VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;

    await controller.initialize();
    // This State may have moved on to a different media item (or been
    // disposed) while the above await was in flight — if _controller no
    // longer points at the controller this call created, a newer _init()
    // call (from didUpdateWidget) has already superseded it, so back off
    // instead of playing/setState-ing on behalf of the wrong item.
    if (!mounted || !identical(_controller, controller)) {
      if (!identical(_controller, controller)) controller.dispose();
      return;
    }
    if (widget.autoPlay) {
      await controller.play();
      _isPlaying = true;
    }
    setState(() => _initialized = true);
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
