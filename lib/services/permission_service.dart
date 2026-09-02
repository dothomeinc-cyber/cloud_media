import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler_package/permission_handler_package.dart';
import '../models/cloud_media_type.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';

class PermissionService {
  PermissionService._();

  static Future<void> initialize() async {
    await PermissionHandler.initialize();
    CloudLogger.info('PermissionService initialized');
  }

  static Future<void> _throwIfDenied(PermissionResult result) async {
    if (result.isPermanentlyDenied) {
      throw const CloudMediaPermissionPermanentlyDeniedException();
    }
    // isSufficient (isGranted || isLimited || isProvisional) — confirmed
    // present in the installed permission_handler_package via a real
    // flutter analyze run — so limited/provisional access (e.g. iOS's
    // "Select Photos..." partial library grant, or provisional
    // notification authorization) counts as usable rather than being
    // forced into a Settings-redirect loop the user never asked for.
    if (!result.isSufficient) {
      throw const CloudMediaPermissionDeniedException();
    }
  }

  /// The read-access permission actually enforced for picking [type] from
  /// the gallery/file system.
  ///
  /// Deliberately does NOT use the legacy [PermissionType.storage] —
  /// `Permission.storage` (from `permission_handler`) maps to Android's
  /// old blanket `READ_EXTERNAL_STORAGE`, which is a no-op on Android
  /// 13+ (API 33+): the OS enforces the granular `READ_MEDIA_IMAGES` /
  /// `READ_MEDIA_VIDEO` / `READ_MEDIA_AUDIO` permissions instead, which
  /// map to [PermissionType.photos] / [.videos] / [.audio] here. Asking
  /// only for `storage` would silently pass on modern Android without
  /// ever prompting for the permission the OS actually checks. `file`
  /// media (PDFs, arbitrary documents) has no dedicated media
  /// permission — that one genuinely does use [PermissionType.storage],
  /// on the same versions where storage permissions apply at all.
  ///
  /// Public (not private) because [CloudMediaProvider] — the engine
  /// behind `CloudMedia.pick()` — needs this exact same mapping for its
  /// own permission check, and it talks to [PermissionManager] directly
  /// rather than through this class (see that method's doc comment for
  /// why). Keeping one shared mapping means the two pick paths can never
  /// silently diverge on which permission gets requested for which type.
  static PermissionType readPermissionFor(CloudMediaType type) {
    switch (type) {
      case CloudMediaType.image:
        return PermissionType.photos;
      case CloudMediaType.video:
        return PermissionType.videos;
      case CloudMediaType.audio:
        return PermissionType.audio;
      case CloudMediaType.file:
        return PermissionType.storage;
    }
  }

  /// Requests whatever's needed to *pick* [type] from the gallery/file
  /// system — this is read access, not camera access. Use
  /// [requestCameraPermission] separately for camera-capture flows.
  static Future<void> requestMediaReadPermission(
    CloudMediaType type,
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await ref
        .read(permissionActionProvider.notifier)
        .requestSinglePermission(readPermissionFor(type), context: context);
    await _throwIfDenied(result);
  }

  /// Requests camera + the gallery-read permission for [type] together,
  /// via the package's canonical multi-permission flow — one combined
  /// explanation screen (or the settings-required screen, if either is
  /// permanently denied), with the shared permission cache/state updated
  /// as it goes. Use this when a flow may let the user either capture
  /// with the camera or pick an existing file of [type].
  static Future<void> requestMediaPermissions(
    CloudMediaType type,
    BuildContext context,
    WidgetRef ref,
  ) async {
    final readPermission = readPermissionFor(type);
    final allGranted = await ref
        .read(permissionActionProvider.notifier)
        .initializeRequiredPermissions(
      context: context,
      requiredPermissions: [PermissionType.camera, readPermission],
      title: 'Media Access Required',
      message: 'CloudMedia needs camera and ${readPermission.displayName.toLowerCase()} access.',
    );

    if (allGranted) return;

    final manager = ref.read(permissionManagerProvider);
    final cameraPermanentlyDenied =
        await manager.isPermissionPermanentlyDenied(PermissionType.camera);
    final readPermanentlyDenied =
        await manager.isPermissionPermanentlyDenied(readPermission);

    if (cameraPermanentlyDenied || readPermanentlyDenied) {
      throw const CloudMediaPermissionPermanentlyDeniedException();
    }

    throw const CloudMediaPermissionDeniedException();
  }

  static Future<void> requestCameraPermission(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(permissionActionProvider.notifier).requestSinglePermission(
        PermissionType.camera, context: context);
    await _throwIfDenied(result);
  }

  /// PDFs/arbitrary files — the one case that genuinely still uses the
  /// legacy blanket storage permission (see [readPermissionFor]).
  static Future<void> requestStoragePermission(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(permissionActionProvider.notifier).requestSinglePermission(
        PermissionType.storage, context: context);
    await _throwIfDenied(result);
  }

  static Future<void> requestMicrophonePermission(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(permissionActionProvider.notifier).requestSinglePermission(
        PermissionType.microphone, context: context);
    await _throwIfDenied(result);
  }

  static Future<bool> isGranted(PermissionType permission, WidgetRef ref) async =>
      ref.read(permissionManagerProvider).isPermissionGranted(permission);

  static Future<void> openSettings(WidgetRef ref) async =>
      ref.read(permissionManagerProvider).openAppSettings();
}
