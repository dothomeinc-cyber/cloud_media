import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/cloud_media_item.dart';
import '../../utils/file_utils.dart';

class CloudFile extends StatelessWidget {
  const CloudFile({
    super.key,
    required this.media,
    this.onDownload,
    this.onShare,
  });

  final CloudMediaItem media;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;

  String get _icon {
    switch (FileUtils.getFileExtension(media.fileName)) {
      case 'pdf':
        return '📄';
      case 'doc':
      case 'docx':
        return '📝';
      case 'xls':
      case 'xlsx':
        return '📊';
      case 'ppt':
      case 'pptx':
        return '📽️';
      case 'zip':
      case 'rar':
        return '🗜️';
      default:
        return '📁';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading:
            Text(_icon, style: TextStyle(fontSize: 32.sp)),
        title: Text(
          media.fileName,
          style: TextStyle(fontSize: 14.sp),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          FileUtils.formatFileSize(media.size),
          style: TextStyle(fontSize: 12.sp),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.download, size: 20.r),
              onPressed: onDownload,
              tooltip: 'Download',
            ),
            IconButton(
              icon: Icon(Icons.share, size: 20.r),
              onPressed: onShare,
              tooltip: 'Share',
            ),
          ],
        ),
      ),
    );
  }
}
