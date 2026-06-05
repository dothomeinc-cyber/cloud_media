import 'package:flutter/material.dart';
import '../../models/cloud_media_item.dart';
import '../../models/cloud_media_type.dart';
import '../widgets/cloud_image.dart';
import '../widgets/cloud_video.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.mediaItems,
    required this.onConfirm,
    required this.onCancel,
  });

  final List<CloudMediaItem> mediaItems;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.mediaItems.length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Review (${_currentIndex + 1}/$total)'),
        leading: IconButton(
            icon: const Icon(Icons.close), onPressed: widget.onCancel),
        actions: [
          IconButton(
              icon: const Icon(Icons.check),
              onPressed: widget.onConfirm,
              tooltip: 'Confirm'),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemCount: total,
              itemBuilder: (_, index) {
                final media = widget.mediaItems[index];
                return Center(
                  child: media.type == CloudMediaType.image
                      ? CloudImage(media: media, fit: BoxFit.contain, enableZoom: true)
                      : CloudVideo(media: media, autoPlay: true, showControls: true),
                );
              },
            ),
          ),
          if (total > 1)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentIndex == i ? Colors.blue : Colors.grey,
                  ),
                )),
              ),
            ),
        ],
      ),
    );
  }
}
