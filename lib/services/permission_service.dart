import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler_package/permission_handler_package.dart';
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
    if (!result.isGranted) {
      throw const CloudMediaPermissionDeniedException();
    }
  }

  static Future<void> requestMediaPermissions(BuildContext context, WidgetRef ref) async {
    final granted = await ref.read(permissionActionProvider.notifier).initializeRequiredPermissions(
      context: context,
      requiredPermissions: [PermissionType.camera, PermissionType.storage],
      title: 'Media Access Required',
      message: 'CloudMedia needs camera and storage access.',
    );
    if (!granted) {
      final cameraDenied = await ref.read(permissionManagerProvider).isPermissionPermanentlyDenied(PermissionType.camera);
      if (cameraDenied) throw const CloudMediaPermissionPermanentlyDeniedException();
      throw const CloudMediaPermissionDeniedException();
    }
  }

  static Future<void> requestCameraPermission(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(permissionActionProvider.notifier).requestSinglePermission(
        PermissionType.camera, context: context);
    await _throwIfDenied(result);
  }

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
