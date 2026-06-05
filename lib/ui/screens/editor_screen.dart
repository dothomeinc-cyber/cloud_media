import 'package:flutter/material.dart';
import '../../models/cloud_media_item.dart';

/// Future: crop, rotate, brightness, contrast.
class EditorScreen extends StatelessWidget {
  const EditorScreen({super.key, required this.media});
  final CloudMediaItem media;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit')),
      body: const Center(child: Text('Editor coming soon')),
    );
  }
}
