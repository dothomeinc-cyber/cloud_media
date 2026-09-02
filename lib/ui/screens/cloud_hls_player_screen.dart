import 'package:flutter/material.dart';
import 'package:flutter_hls_video_player/flutter_hls_video_player/controller/flutter_hls_video_player_controller.dart';
import 'package:flutter_hls_video_player/flutter_hls_video_player/controller/flutter_hls_video_controls.dart';
import 'package:flutter_hls_video_player/flutter_hls_video_player/controller/flutter_hls_video_player_state.dart';
import 'package:flutter_hls_video_player/flutter_hls_video_player/view/flutter_hls_video_player.dart';
import '../../models/cloud_media_item.dart';

/// Full-screen HLS (m3u8) video player screen.
///
/// Use this when your [CloudMediaItem.downloadUrl] is an `.m3u8` stream URL.
/// For regular mp4/mov uploads use [CloudVideoPlayerScreen] instead.
///
/// ```dart
/// // From a CloudMediaItem with an HLS stream URL
/// Navigator.of(context).push(MaterialPageRoute(
///   builder: (_) => CloudHlsPlayerScreen(media: item),
/// ));
///
/// // From a raw m3u8 URL
/// Navigator.of(context).push(MaterialPageRoute(
///   builder: (_) => CloudHlsPlayerScreen.fromUrl(
///     url: 'https://example.com/stream.m3u8',
///     title: 'Live Stream',
///   ),
/// ));
/// ```
class CloudHlsPlayerScreen extends StatefulWidget {
  const CloudHlsPlayerScreen({
    super.key,
    required this.hlsUrl,
    this.title = '',
    this.autoPlay = true,
  });

  final String hlsUrl;
  final String title;
  final bool autoPlay;

  /// Convenience constructor for a [CloudMediaItem] whose downloadUrl is m3u8.
  factory CloudHlsPlayerScreen.fromMedia(CloudMediaItem media) {
    return CloudHlsPlayerScreen(
      hlsUrl: media.downloadUrl,
      title: media.fileName,
    );
  }

  /// Convenience constructor for a raw m3u8 URL.
  factory CloudHlsPlayerScreen.fromUrl({
    required String url,
    String title = '',
  }) {
    return CloudHlsPlayerScreen(hlsUrl: url, title: title);
  }

  @override
  State<CloudHlsPlayerScreen> createState() => _CloudHlsPlayerScreenState();
}

class _CloudHlsPlayerScreenState extends State<CloudHlsPlayerScreen> {
  late final FlutterHLSVideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FlutterHLSVideoPlayerController();
    // Load unconditionally — autoPlay should only control whether
    // playback starts immediately, not whether the stream loads at all.
    // With the old `if (widget.autoPlay)` guard, autoPlay: false left
    // the controller permanently unloaded (a black screen with nothing
    // to play), since loadHlsVideo is the only call that loads the URL.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadHlsVideo(widget.hlsUrl);
      if (widget.autoPlay) _controller.play();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showQualityMenu(BuildContext context) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final state = _controller.initialState;
    final qualities = state.availableQualities ?? [];
    if (qualities.isEmpty) return;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(overlay.size.width - 60, 80, 10, 0),
      items: [
        PopupMenuItem(
          enabled: false,
          child: Text(
            'Quality',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              fontSize: 13,
            ),
          ),
        ),
        ...List.generate(qualities.length, (index) {
          final label = qualities[index]['height'] == 'Auto'
              ? 'Auto'
              : '${qualities[index]['height']}p';
          final isSelected = state.currentQuality == index;
          return PopupMenuItem(
            onTap: () => _controller.changeQuality(index == 0 ? -1 : index),
            child: Row(
              children: [
                if (isSelected)
                  const Icon(Icons.check, size: 16, color: Colors.black)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: StreamBuilder<FlutterHLSVideoPlayerState>(
          stream: _controller.stateStream,
          builder: (context, snapshot) {
            final isFullScreen =
                snapshot.data != null && snapshot.data!.fullScreen;

            return Stack(
              children: [
                if (!isFullScreen)
                  Column(
                    children: [
                      // 16:9 placeholder behind the player
                      const AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ColoredBox(color: Colors.black),
                      ),
                      // Title bar when not fullscreen
                      if (widget.title.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          color: Colors.black,
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                FlutterHLSVideoPlayer(
                  controller: _controller,
                  controls: FlutterHLSVideoPlayerControls(
                    hideBackArrowWidget: false,
                    onTapArrowBack: () => Navigator.of(context).pop(),
                    onTapSetting: () => _showQualityMenu(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Inline HLS player widget (not full-screen).
///
/// ```dart
/// CloudHlsPlayer(
///   url: 'https://example.com/stream.m3u8',
///   aspectRatio: 16 / 9,
/// )
/// ```
class CloudHlsPlayer extends StatefulWidget {
  const CloudHlsPlayer({
    super.key,
    required this.url,
    this.aspectRatio = 16 / 9,
    this.autoPlay = true,
  });

  final String url;
  final double aspectRatio;
  final bool autoPlay;

  @override
  State<CloudHlsPlayer> createState() => _CloudHlsPlayerState();
}

class _CloudHlsPlayerState extends State<CloudHlsPlayer> {
  late final FlutterHLSVideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FlutterHLSVideoPlayerController();
    // Same fix as CloudHlsPlayerScreen: load unconditionally, only gate
    // whether playback auto-starts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadHlsVideo(widget.url);
      if (widget.autoPlay) _controller.play();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: FlutterHLSVideoPlayer(
        controller: _controller,
        controls: FlutterHLSVideoPlayerControls(
          hideBackArrowWidget: true,
          onTapArrowBack: () {},
          onTapSetting: () {},
        ),
      ),
    );
  }
}
