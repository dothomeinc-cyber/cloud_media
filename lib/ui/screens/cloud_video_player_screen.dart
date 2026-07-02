import 'package:flutter/material.dart';
import '../../models/cloud_media_item.dart';
import '../widgets/cloud_video.dart';

/// Ready-made full-screen video viewer for a CloudMediaItem.
class CloudVideoPlayerScreen extends StatelessWidget {
  const CloudVideoPlayerScreen({
    super.key,
    required this.media,
    this.autoPlay = true,
  });

  final CloudMediaItem media;
  final bool autoPlay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(media.fileName),
      ),
      body: Center(
        child: CloudVideo(
          media: media,
          autoPlay: autoPlay,
          showControls: true,
        ),
      ),
    );
  }
}
