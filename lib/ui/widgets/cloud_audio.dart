import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/cloud_media_item.dart';
import '../../utils/date_formatter.dart';

class CloudAudio extends StatefulWidget {
  const CloudAudio({
    super.key,
    required this.media,
    this.autoPlay = false,
  });

  final CloudMediaItem media;
  final bool autoPlay;

  @override
  State<CloudAudio> createState() => _CloudAudioState();
}

class _CloudAudioState extends State<CloudAudio> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

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

    await _player.setSourceUrl(url);
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });

    if (widget.autoPlay) {
      await _player.resume();
      if (mounted) setState(() => _isPlaying = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    _isPlaying
        ? await _player.pause()
        : await _player.resume();
    setState(() => _isPlaying = !_isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            IconButton(
              icon: Icon(_isPlaying
                  ? Icons.pause
                  : Icons.play_arrow),
              iconSize: 32.r,
              onPressed: _toggle,
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.media.fileName,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Slider(
                    value: _position.inSeconds
                        .toDouble()
                        .clamp(0,
                            _duration.inSeconds.toDouble()),
                    max: _duration.inSeconds.toDouble(),
                    onChanged: (v) => _player
                        .seek(Duration(seconds: v.toInt())),
                  ),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          DateFormatter.formatDuration(
                              _position),
                          style:
                              TextStyle(fontSize: 12.sp)),
                      Text(
                          DateFormatter.formatDuration(
                              _duration),
                          style:
                              TextStyle(fontSize: 12.sp)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
