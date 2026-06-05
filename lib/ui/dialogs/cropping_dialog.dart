import 'dart:io';
import 'package:flutter/material.dart';

class CroppedFile {
  const CroppedFile(this.path);
  final String path;
  Future<int> length() => File(path).length();
}

enum CropStyle { rectangle, circle }

class CroppingDialog {
  CroppingDialog._();

  static Future<CroppedFile?> show({
    required BuildContext context,
    required String imagePath,
    CropStyle cropStyle = CropStyle.rectangle,
    double aspectRatio = 1.0,
    bool allowRotation = true,
  }) async {
    debugPrint('[CloudMedia] CroppingDialog: returning original (stub)');
    return CroppedFile(imagePath);
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
          aspectRatio: 1.0);
}
