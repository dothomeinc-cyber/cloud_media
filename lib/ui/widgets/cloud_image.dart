import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
    if (media.thumbnailUrl.isNotEmpty) return media.thumbnailUrl;
    if (media.downloadUrl.isNotEmpty) return media.downloadUrl;
    return media.localPath ?? '';
  }

  bool get _isLocal =>
      _url.startsWith('/') || _url.startsWith('file://');

  @override
  Widget build(BuildContext context) {
    if (_url.isEmpty) return _placeholder();

    if (enableZoom) {
      return GestureDetector(
        onTap: onTap,
        child: Hero(
          tag: 'cloud_image_${media.id}',
          child: PhotoView(
            imageProvider: _isLocal
                ? FileImage(File(_url.replaceFirst('file://', '')))
                : NetworkImage(_url) as ImageProvider,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: _isLocal ? _localImage() : _networkImage(),
    );
  }

  Widget _localImage() => Image.file(
        File(_url.replaceFirst('file://', '')),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _error(),
      );

  Widget _networkImage() => CachedNetworkImage(
        imageUrl: _url,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _error(),
      );

  Widget _placeholder() => Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Center(child: CircularProgressIndicator()),
      );

  Widget _error() => Container(
        width: width,
        height: height,
        color: Colors.grey[300],
        child: const Center(
            child: Icon(Icons.broken_image, color: Colors.grey)),
      );
}
