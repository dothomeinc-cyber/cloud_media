import 'package:flutter/material.dart';
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
        leading: Text(_icon, style: const TextStyle(fontSize: 32)),
        title: Text(media.fileName,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(FileUtils.formatFileSize(media.size)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(Icons.download),
                onPressed: onDownload,
                tooltip: 'Download'),
            IconButton(
                icon: const Icon(Icons.share),
                onPressed: onShare,
                tooltip: 'Share'),
          ],
        ),
      ),
    );
  }
}
