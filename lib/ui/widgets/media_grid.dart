import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/cloud_media_item.dart';
import '../../models/cloud_media_status.dart';
import '../../models/cloud_media_type.dart';
import 'cloud_image.dart';
import 'cloud_video.dart';

class MediaGrid extends StatelessWidget {
  const MediaGrid({
    super.key,
    required this.mediaItems,
    this.crossAxisCount = 3,
    this.crossAxisSpacing = 4,
    this.mainAxisSpacing = 4,
    this.onItemTap,
    this.onItemLongPress,
  });

  final List<CloudMediaItem> mediaItems;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final void Function(CloudMediaItem)? onItemTap;
  final void Function(CloudMediaItem)? onItemLongPress;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing.w,
        mainAxisSpacing: mainAxisSpacing.h,
      ),
      itemCount: mediaItems.length,
      itemBuilder: (_, index) {
        final media = mediaItems[index];
        return GestureDetector(
          onTap: () => onItemTap?.call(media),
          onLongPress: () => onItemLongPress?.call(media),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _tile(media),
              if (media.type == CloudMediaType.video)
                Positioned(
                  bottom: 8.h,
                  right: 8.w,
                  child: Icon(
                    Icons.play_circle_filled,
                    color: Colors.white,
                    size: 28.r,
                  ),
                ),
              if (media.status == CloudMediaStatus.syncing)
                Container(
                  color: Colors.black45,
                  child: const Center(
                      child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(CloudMediaItem media) {
    if (media.type == CloudMediaType.image) {
      return CloudImage(media: media, fit: BoxFit.cover);
    }
    if (media.type == CloudMediaType.video) {
      return CloudVideo(media: media, showControls: false);
    }
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          media.type.icon,
          size: 32.r,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
