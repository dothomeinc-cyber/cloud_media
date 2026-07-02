import 'package:flutter/material.dart';
import 'package:flutter_img_editor/image_editor.dart';
import '../screens/editor_screen.dart';

class CroppedFile {
  const CroppedFile(this.path);
  final String path;
}

enum CropStyle { rectangle, circle }

class CroppingDialog {
  CroppingDialog._();

  static Future<CroppedFile?> show({
    required BuildContext context,
    required String imagePath,
    CropStyle cropStyle = CropStyle.rectangle,
    double? aspectRatio,
    bool allowRotation = true,
  }) async {
    final config = ImageEditorConfig(
      enableText: false,
      cropOptions: CropOptionConfig(
        enableFree: aspectRatio == null,
        enable16By9: aspectRatio == null || aspectRatio == 16 / 9,
        enable5By4: aspectRatio == null || aspectRatio == 5 / 4,
        enable1By1: aspectRatio == null || aspectRatio == 1.0,
      ),
      rotateOptions: RotateOptionConfig(
        enableFree: allowRotation,
        enableFixed: allowRotation,
      ),
      topToolbar: const TopToolbarConfig(
        titleText: 'Edit Image',
        confirmText: 'Done',
      ),
      compression: const ImageCompressionConfig(
        enabled: true,
        scale: 1.0,
      ),
    );

    final path = await CloudMediaImageEditor.edit(
      context: context,
      imagePath: imagePath,
      config: config,
    );
    if (path == null || path.isEmpty) return null;
    return CroppedFile(path);
  }

  static Future<CroppedFile?> showSquareCrop({
    required BuildContext context,
    required String imagePath,
  }) =>
      show(context: context, imagePath: imagePath, aspectRatio: 1.0);

  static Future<CroppedFile?> showCircleCrop({
    required BuildContext context,
    required String imagePath,
  }) =>
      show(
        context: context,
        imagePath: imagePath,
        cropStyle: CropStyle.circle,
        aspectRatio: 1.0,
      );

  static Future<CroppedFile?> showWideScreenCrop({
    required BuildContext context,
    required String imagePath,
  }) =>
      show(context: context, imagePath: imagePath, aspectRatio: 16 / 9);
}
