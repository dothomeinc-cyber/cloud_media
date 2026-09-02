import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/file_constants.dart';
import '../models/cache_entry.dart';
import '../models/cloud_media_config.dart';
import '../utils/file_utils.dart';
import '../utils/logger.dart';

class CacheService {
  /// [box] and [cacheDir] are injectable seams for tests (an in-memory
  /// or real-temp-dir Hive box, and a real `Directory` under
  /// `Directory.systemTemp`) — real app code should leave them null
  /// and get the real Hive box + app documents directory via
  /// [initialize], exactly as before this became injectable.
  CacheService({required this.config, Box<Map>? box, Directory? cacheDir})
      : _injectedBox = box,
        _injectedDir = cacheDir;

  final CloudMediaConfig config;
  final Box<Map>? _injectedBox;
  final Directory? _injectedDir;
  late Box<Map> _box;
  late Directory _dir;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    if (_injectedBox != null) {
      _box = _injectedBox;
    } else {
      await Hive.initFlutter();
      _box = await Hive.openBox<Map>(FileConstants.cacheBoxName);
    }

    if (_injectedDir != null) {
      _dir = _injectedDir;
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      _dir = Directory('${appDir.path}/${FileConstants.cacheDirectory}');
    }
    if (!await _dir.exists()) await _dir.create(recursive: true);

    await _cleanExpired();
    await _enforceLimit();
    _initialized = true;
    CloudLogger.info('CacheService ready: ${_dir.path}');
  }

  Future<void> set(String key, String filePath, int size) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return;

      final dest = '${_dir.path}/${key}_${DateTime.now().millisecondsSinceEpoch}';
      await file.copy(dest);

      final entry = CacheEntry(
        key: key,
        localPath: dest,
        size: size,
        cachedAt: DateTime.now(),
        lastAccessedAt: DateTime.now(),
      );
      await _box.put(key, entry.toJson());
      await _enforceLimit();
    } catch (e) {
      CloudLogger.error('Cache set failed key=$key', error: e);
    }
  }

  Future<String?> get(String key) async {
    try {
      final raw = _box.get(key);
      if (raw == null) return null;

      final entry = CacheEntry.fromJson(Map<String, dynamic>.from(raw));
      if (!await File(entry.localPath).exists()) {
        await _box.delete(key);
        return null;
      }

      // Update LRU timestamp
      await _box.put(
          key,
          CacheEntry(
            key: entry.key,
            localPath: entry.localPath,
            size: entry.size,
            cachedAt: entry.cachedAt,
            lastAccessedAt: DateTime.now(),
          ).toJson());

      return entry.localPath;
    } catch (e) {
      CloudLogger.error('Cache get failed key=$key', error: e);
      return null;
    }
  }

  Future<void> remove(String key) async {
    try {
      final raw = _box.get(key);
      if (raw != null) {
        final entry = CacheEntry.fromJson(Map<String, dynamic>.from(raw));
        await FileUtils.deleteFile(entry.localPath);
        await _box.delete(key);
      }
    } catch (e) {
      CloudLogger.error('Cache remove failed key=$key', error: e);
    }
  }

  Future<void> clearAll() async {
    for (final key in List.from(_box.keys)) {
      await remove(key.toString());
    }
    await _box.clear();
    CloudLogger.info('Cache cleared');
  }

  /// Alias used by provider dispose
  Future<void> clear() => clearAll();

  Future<void> dispose() async {
    if (_box.isOpen) await _box.close();
  }

  Future<int> getCacheSize() async {
    int total = 0;
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw != null) {
        total += CacheEntry.fromJson(Map<String, dynamic>.from(raw)).size;
      }
    }
    return total;
  }

  Future<void> _cleanExpired() async {
    final now = DateTime.now();
    final expired = <String>[];
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw != null) {
        final e = CacheEntry.fromJson(Map<String, dynamic>.from(raw));
        if (now.difference(e.cachedAt).inDays > FileConstants.maxCacheAgeDays) {
          expired.add(key.toString());
        }
      }
    }
    for (final k in expired) {
      await remove(k);
    }
  }

  Future<void> _enforceLimit() async {
    final max = config.maxCacheSizeMb * 1024 * 1024;
    final entries = <CacheEntry>[];
    int total = 0;

    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw != null) {
        final e = CacheEntry.fromJson(Map<String, dynamic>.from(raw));
        entries.add(e);
        total += e.size;
      }
    }

    if (total <= max) return;
    entries.sort((a, b) => a.lastAccessedAt.compareTo(b.lastAccessedAt));
    for (final e in entries) {
      if (total <= max) break;
      total -= e.size;
      await remove(e.key);
    }
  }
}
