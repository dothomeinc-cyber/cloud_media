import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/cloud_media_item.dart';

/// Future: crop, rotate, brightness, contrast.
class EditorScreen extends StatelessWidget {
  const EditorScreen({super.key, required this.media});
  final CloudMediaItem media;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text('Edit', style: TextStyle(fontSize: 18.sp)),
      ),
      body: Center(
        child: Text(
          'Editor coming soon',
          style: TextStyle(
              fontSize: 16.sp, color: Colors.grey),
        ),
      ),
    );
  }
}
