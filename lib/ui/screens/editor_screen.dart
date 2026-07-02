import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_img_editor/image_editor.dart';

/// Full image editor screen powered by flutter_img_editor.
///
/// Supports crop, rotation, undo/reset, and optional text overlays depending on
/// [config]. It returns the edited image as a temporary file path.
class EditorScreen extends StatelessWidget {
  const EditorScreen({
    super.key,
    required this.image,
    this.config = const ImageEditorConfig(
      enableText: false,
      cropOptions: CropOptionConfig(
        enableFree: true,
        enable16By9: true,
        enable5By4: true,
        enable1By1: true,
      ),
      rotateOptions: RotateOptionConfig(
        enableFree: true,
        enableFixed: true,
      ),
      topToolbar: TopToolbarConfig(
        titleText: 'Edit Image',
        confirmText: 'Done',
      ),
      compression: ImageCompressionConfig(
        enabled: true,
        scale: 1.0,
      ),
    ),
  });

  final ui.Image image;
  final ImageEditorConfig config;

  @override
  Widget build(BuildContext context) {
    return ImageEditor(image: image, config: config);
  }
}

class CloudMediaImageEditor {
  const CloudMediaImageEditor._();

  static Future<String?> edit({
    required BuildContext context,
    required String imagePath,
    ImageEditorConfig config = const ImageEditorConfig(
      enableText: false,
      cropOptions: CropOptionConfig(
        enableFree: true,
        enable16By9: true,
        enable5By4: true,
        enable1By1: true,
      ),
      rotateOptions: RotateOptionConfig(
        enableFree: true,
        enableFixed: true,
      ),
      topToolbar: TopToolbarConfig(
        titleText: 'Edit Image',
        confirmText: 'Done',
      ),
      compression: ImageCompressionConfig(
        enabled: true,
        scale: 1.0,
      ),
    ),
  }) async {
    final original = await loadImageFromFile(imagePath);
    if (!context.mounted) return null;

    final result = await Navigator.of(context).push<ui.Image?>(
      MaterialPageRoute(
        builder: (_) => EditorScreen(image: original, config: config),
      ),
    );

    original.dispose();
    if (!context.mounted || result == null) return null;

    final path = await saveImageToTempFile(
      result,
      compression: config.compression,
    );
    result.dispose();
    return path;
  }
}
