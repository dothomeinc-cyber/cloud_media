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
  bool _sourceSet = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant CloudAudio oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Same reasoning as CloudVideo.didUpdateWidget: a parent list/grid
    // can reuse this State at the same tree position for a different
    // media item without a distinguishing Key — re-source rather than
    // keep playing/showing the previous item's audio.
    final oldUrl = oldWidget.media.downloadUrl.isNotEmpty
        ? oldWidget.media.downloadUrl
        : oldWidget.media.localPath;
    final newUrl = widget.media.downloadUrl.isNotEmpty
        ? widget.media.downloadUrl
        : widget.media.localPath;
    if (oldUrl != newUrl) {
      _initGeneration++;
      _sourceSet = false;
      _player.stop();
      setState(() {
        _isPlaying = false;
        _duration = Duration.zero;
        _position = Duration.zero;
      });
      _init();
    }
  }

  // Bumped on every didUpdateWidget re-source; a stale _init() call that
  // resolves after a newer one has started can check this to tell it's
  // been superseded and back off, instead of applying setState for the
  // wrong media item once its await completes.
  int _initGeneration = 0;

  Future<void> _init() async {
    final generation = _initGeneration;
    final url = widget.media.downloadUrl.isNotEmpty
        ? widget.media.downloadUrl
        : widget.media.localPath;
    if (url == null || url.isEmpty) return;

    // audioplayers' setSourceUrl always constructs a UrlSource, which is
    // not guaranteed to correctly handle a bare local filesystem path
    // (as opposed to an http(s) URL) consistently across platforms —
    // setSourceDeviceFile is the API actually documented for local
    // files. Same local/remote split already used in CloudVideo/CloudImage.
    if (url.startsWith('/')) {
      await _player.setSourceDeviceFile(url);
    } else {
      await _player.setSourceUrl(url);
    }
    if (!mounted || generation != _initGeneration) return;
    _sourceSet = true;

    _player.onDurationChanged.listen((d) {
      if (mounted && generation == _initGeneration) {
        setState(() => _duration = d);
      }
    });
    _player.onPositionChanged.listen((p) {
      if (mounted && generation == _initGeneration) {
        setState(() => _position = p);
      }
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted && generation == _initGeneration) {
        setState(() => _isPlaying = false);
      }
    });

    if (widget.autoPlay) {
      await _player.resume();
      if (mounted && generation == _initGeneration) {
        setState(() => _isPlaying = true);
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (!_sourceSet) return;
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
