import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler_package/permission_handler_package.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';

class PermissionService {
  PermissionService._();

  static final _container = ProviderContainer();

  static Future<void> initialize() async {
    await PermissionHandler.initialize();
    CloudLogger.info('PermissionService initialized');
  }

  static PermissionActionNotifier get _notifier =>
      _container.read(permissionActionProvider.notifier);

  static PermissionManager get _manager =>
      _container.read(permissionManagerProvider);

  static Future<void> _throwIfDenied(PermissionResult result) async {
    if (result.isPermanentlyDenied) {
      throw const CloudMediaPermissionPermanentlyDeniedException();
    }
    if (!result.isGranted) {
      throw const CloudMediaPermissionDeniedException();
    }
  }

  static Future<void> requestMediaPermissions(BuildContext context) async {
    final granted = await _notifier.initializeRequiredPermissions(
      context: context,
      requiredPermissions: [PermissionType.camera, PermissionType.storage],
      title: 'Media Access Required',
      message: 'CloudMedia needs camera and storage access.',
    );
    if (!granted) {
      final cameraDenied = await _manager.isPermissionPermanentlyDenied(PermissionType.camera);
      if (cameraDenied) throw const CloudMediaPermissionPermanentlyDeniedException();
      throw const CloudMediaPermissionDeniedException();
    }
  }

  static Future<void> requestCameraPermission(BuildContext context) async {
    final result = await _notifier.requestSinglePermission(
        PermissionType.camera, context: context);
    await _throwIfDenied(result);
  }

  static Future<void> requestStoragePermission(BuildContext context) async {
    final result = await _notifier.requestSinglePermission(
        PermissionType.storage, context: context);
    await _throwIfDenied(result);
  }

  static Future<void> requestMicrophonePermission(BuildContext context) async {
    final result = await _notifier.requestSinglePermission(
        PermissionType.microphone, context: context);
    await _throwIfDenied(result);
  }

  static Future<bool> isGranted(PermissionType permission) async =>
      _manager.isPermissionGranted(permission);

  static Future<void> openSettings() async =>
      _manager.openAppSettings();
}
