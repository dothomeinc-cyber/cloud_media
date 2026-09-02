import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/cloud_media_item.dart';
import '../../models/cloud_media_status.dart';
import '../../models/cloud_media_type.dart';
import 'cloud_image.dart';
import 'cloud_video.dart';
import 'upload_progress_indicator.dart';

class MediaGrid extends StatelessWidget {
  const MediaGrid({
    super.key,
    required this.mediaItems,
    this.crossAxisCount = 3,
    this.crossAxisSpacing = 4,
    this.mainAxisSpacing = 4,
    this.onItemTap,
    this.onItemLongPress,
    this.showUploadControls = false,
  });

  final List<CloudMediaItem> mediaItems;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final void Function(CloudMediaItem)? onItemTap;
  final void Function(CloudMediaItem)? onItemLongPress;

  /// Whether syncing tiles show pause/resume/cancel buttons alongside
  /// their progress bar. Off by default since a dense grid usually
  /// wants the compact bar only — turn this on for a library view
  /// where the user is actively managing in-flight uploads.
  final bool showUploadControls;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
              _tile(context, media),
              if (media.type == CloudMediaType.video)
                Positioned(
                  bottom: 8.h,
                  right: 8.w,
                  child: Icon(
                    Icons.play_circle_filled,
                    color: cs.onPrimary,
                    size: 28.r,
                  ),
                ),
              if (media.status == CloudMediaStatus.syncing)
                Container(
                  color: Colors.black.withAlpha(115),
                  padding: EdgeInsets.all(6.r),
                  alignment: Alignment.bottomCenter,
                  child: UploadProgressIndicator(
                    mediaId: media.id,
                    showControls: showUploadControls,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, CloudMediaItem media) {
    final cs = Theme.of(context).colorScheme;
    if (media.type == CloudMediaType.image) {
      return CloudImage(media: media, fit: BoxFit.cover);
    }
    if (media.type == CloudMediaType.video) {
      return CloudVideo(media: media, showControls: false);
    }
    return Container(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(
          media.type.icon,
          size: 32.r,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
