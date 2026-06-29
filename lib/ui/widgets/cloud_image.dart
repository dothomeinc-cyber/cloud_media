import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:photo_view/photo_view.dart';
import '../../models/cloud_media_item.dart';

class CloudImage extends StatelessWidget {
  const CloudImage({
    super.key,
    required this.media,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.enableZoom = false,
    this.onTap,
  });

  final CloudMediaItem media;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool enableZoom;
  final VoidCallback? onTap;

  String get _url {
    if (media.thumbnailUrl.isNotEmpty) {
      return media.thumbnailUrl;
    }
    if (media.downloadUrl.isNotEmpty) {
      return media.downloadUrl;
    }
    return media.localPath ?? '';
  }

  bool get _isLocal =>
      _url.startsWith('/') || _url.startsWith('file://');

  @override
  Widget build(BuildContext context) {
    if (_url.isEmpty) return _placeholder(context);

    // Apply screenutil scaling using null-aware operator
    final finalWidth = width?.w;
    final finalHeight = height?.h;

    if (enableZoom) {
      return GestureDetector(
        onTap: onTap,
        child: Hero(
          tag: 'cloud_image_${media.id}',
          child: PhotoView(
            imageProvider: _isLocal
                ? FileImage(
                    File(_url.replaceFirst('file://', '')))
                : NetworkImage(_url) as ImageProvider,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: _isLocal
          ? _localImage(finalWidth, finalHeight)
          : _networkImage(finalWidth, finalHeight),
    );
  }

  Widget _localImage(double? w, double? h) => Image.file(
        File(_url.replaceFirst('file://', '')),
        width: w,
        height: h,
        fit: fit,
        errorBuilder: (context, _, __) => _error(context),
      );

  Widget _networkImage(double? w, double? h) =>
      CachedNetworkImage(
        imageUrl: _url,
        width: w,
        height: h,
        fit: fit,
        placeholder: (context, _) => _placeholder(context),
        errorWidget: (context, _, __) => _error(context),
      );

  Widget _placeholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
        width: width?.w,
        height: height?.h,
        color: cs.surfaceContainerLow,
        child: const Center(
            child: CircularProgressIndicator()),
      );
  }

  Widget _error(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
        width: width?.w,
        height: height?.h,
        color: cs.surfaceContainerHighest,
        child: Center(
          child: Icon(Icons.broken_image, color: cs.onSurfaceVariant),
        ),
      );
  }
}
