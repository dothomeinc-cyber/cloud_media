import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart'
    as image_cropper;

/// Result of a crop operation.
class CroppedFile {
  /// Creates a [CroppedFile] with the given [path].
  const CroppedFile(this.path);

  /// The local file path of the cropped image.
  final String path;

  /// Returns the file size in bytes.
  Future<int> length() => File(path).length();
}

/// Style of the crop selection area.
enum CropStyle {
  /// Rectangular crop area (default).
  rectangle,

  /// Circular crop area.
  circle,
}

/// Full-featured image cropping dialog using [image_cropper] ^11.0.0.
///
/// Wraps native cropping UI:
/// - Android: uCrop (Yalantis)
/// - iOS: TOCropViewController
/// - Web: Cropper.js
///
/// Usage:
/// ```dart
/// final cropped = await CroppingDialog.show(
///   context: context,
///   imagePath: '/path/to/image.jpg',
/// );
/// if (cropped != null) {
///   print(cropped.path);
/// }
/// ```
class CroppingDialog {
  CroppingDialog._();

  /// Show the cropping UI for the image at [imagePath].
  ///
  /// Returns a [CroppedFile] with the result path, or null if the user
  /// cancelled.
  ///
  /// Parameters:
  /// - [cropStyle] — rectangle (default) or circle
  /// - [aspectRatio] — locked aspect ratio, or null for free crop
  /// - [allowRotation] — whether to show rotation controls
  static Future<CroppedFile?> show({
    required BuildContext context,
    required String imagePath,
    CropStyle cropStyle = CropStyle.rectangle,
    double? aspectRatio,
    bool allowRotation = true,
  }) async {
    // Convert our CropStyle to image_cropper's CropStyle
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
              ? presets.sublist(
                  0, 2) // iOS supports max 2 presets
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

  /// Show a square (1:1) crop dialog — useful for profile pictures.
  static Future<CroppedFile?> showSquareCrop({
    required BuildContext context,
    required String imagePath,
  }) =>
      show(
        context: context,
        imagePath: imagePath,
        aspectRatio: 1.0,
      );

  /// Show a circular crop dialog — useful for avatars.
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

  /// Show a 16:9 crop dialog — useful for banners and thumbnails.
  static Future<CroppedFile?> showWideScreenCrop({
    required BuildContext context,
    required String imagePath,
  }) =>
      show(
        context: context,
        imagePath: imagePath,
        aspectRatio: 16 / 9,
      );
}
