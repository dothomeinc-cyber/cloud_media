import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart'
    as image_cropper;

/// Result of a crop operation.
class CroppedFile {
  const CroppedFile(this.path);
  final String path;
  Future<int> length() => File(path).length();
}

/// Style of the crop selection area.
enum CropStyle {
  rectangle,
  circle,
}

class CroppingDialog {
  CroppingDialog._();

  static Future<CroppedFile?> show({
    required BuildContext context,
    required String imagePath,
    CropStyle cropStyle = CropStyle.rectangle,
    double? aspectRatio,
    bool allowRotation = true,
  }) async {
    final imageCropperCropStyle =
        cropStyle == CropStyle.circle
            ? image_cropper.CropStyle.circle
            : image_cropper.CropStyle.rectangle;

    final List<image_cropper.CropAspectRatioPreset>
        presets = aspectRatio != null
            ? [image_cropper.CropAspectRatioPreset.original]
            : [
                image_cropper
                    .CropAspectRatioPreset.original,
                image_cropper.CropAspectRatioPreset.square,
                image_cropper
                    .CropAspectRatioPreset.ratio4x3,
                image_cropper
                    .CropAspectRatioPreset.ratio16x9,
              ];

    final result =
        await image_cropper.ImageCropper().cropImage(
      sourcePath: imagePath,
      uiSettings: [
        image_cropper.AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Theme.of(context).primaryColor,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor:
              Theme.of(context).primaryColor,
          cropStyle: imageCropperCropStyle,
          aspectRatioPresets: presets,
          lockAspectRatio: aspectRatio != null,
          showCropGrid: true,
          initAspectRatio:
              image_cropper.CropAspectRatioPreset.original,
        ),
        image_cropper.IOSUiSettings(
          title: 'Crop Image',
          cancelButtonTitle: 'Cancel',
          doneButtonTitle: 'Done',
          aspectRatioPresets: presets.length > 1
              ? presets.sublist(0, 2)
              : presets,
          resetAspectRatioEnabled: aspectRatio == null,
          aspectRatioLockEnabled: aspectRatio != null,
          rotateButtonsHidden: !allowRotation,
        ),
        image_cropper.WebUiSettings(
          context: context,
          presentStyle:
              image_cropper.WebPresentStyle.dialog,
          size: const image_cropper.CropperSize(
              width: 520, height: 520),
        ),
      ],
    );

    if (result == null) return null;
    return CroppedFile(result.path);
  }

  static Future<CroppedFile?> showSquareCrop({
    required BuildContext context,
    required String imagePath,
  }) =>
      show(
          context: context,
          imagePath: imagePath,
          aspectRatio: 1.0);

  static Future<CroppedFile?> showCircleCrop({
    required BuildContext context,
    required String imagePath,
  }) =>
      show(
          context: context,
          imagePath: imagePath,
          cropStyle: CropStyle.circle,
          aspectRatio: 1.0);

  static Future<CroppedFile?> showWideScreenCrop({
    required BuildContext context,
    required String imagePath,
  }) =>
      show(
          context: context,
          imagePath: imagePath,
          aspectRatio: 16 / 9);
}
