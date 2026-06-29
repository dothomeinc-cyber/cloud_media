import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
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


  bool _isCupertino(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

  double get _sliderMax {
    final seconds = _duration.inSeconds.toDouble();
    return seconds <= 0 ? 1 : seconds;
  }

  double get _sliderValue => _position.inSeconds.toDouble().clamp(0, _sliderMax);

  void _seekTo(double value) {
    _player.seek(Duration(seconds: value.toInt()));
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
                  _isCupertino(context)
                      ? CupertinoSlider(
                          value: _sliderValue,
                          max: _sliderMax,
                          onChanged: _seekTo,
                        )
                      : Slider(
                          value: _sliderValue,
                          max: _sliderMax,
                          onChanged: _seekTo,
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
