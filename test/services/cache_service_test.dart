import 'dart:io';
import 'package:cloud_media/models/cloud_media_config.dart';
import 'package:cloud_media/services/cache_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late Directory hiveDir;
  late Box<Map> box;
  late CacheService service;

  // Real files backing "cached" entries — CacheService.set() copies a
  // real file into its cache dir, so tests need real files to point at,
  // not just fabricated paths.
  Future<File> makeSourceFile(String name, int sizeBytes) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsBytes(List.filled(sizeBytes, 0));
    return file;
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cloud_media_cache_test_');
    hiveDir = Directory('${tempDir.path}/hive');
    await hiveDir.create();
    // Hive.init() re-pointing the storage path on every setUp() is the
    // standard pattern for isolating Hive state between tests — this
    // is widely documented Hive testing practice, though it hasn't
    // been run against a real SDK in this environment to confirm.
    Hive.init(hiveDir.path);
    // Fresh box name per test run to avoid cross-test leakage if Hive's
    // process-wide box registry isn't fully torn down between tests.
    box = await Hive.openBox<Map>(
        'test_cache_${DateTime.now().microsecondsSinceEpoch}');
  });

  tearDown(() async {
    if (box.isOpen) await box.close();
    await tempDir.delete(recursive: true);
  });

  CacheService buildService({int maxCacheSizeMb = 500}) {
    final cacheDir = Directory('${tempDir.path}/cache_dest');
    return CacheService(
      config: CloudMediaConfig(maxCacheSizeMb: maxCacheSizeMb),
      box: box,
      cacheDir: cacheDir,
    );
  }

  group('CacheService.set / get', () {
    test('stores and retrieves a cached file by key', () async {
      service = buildService();
      await service.initialize();
      final source = await makeSourceFile('photo.jpg', 1000);

      await service.set('media_1', source.path, 1000);
      final cachedPath = await service.get('media_1');

      expect(cachedPath, isNotNull);
      expect(await File(cachedPath!).exists(), isTrue);
      expect(await File(cachedPath).length(), 1000);
    });

    test('get returns null for a key that was never cached', () async {
      service = buildService();
      await service.initialize();

      expect(await service.get('never_cached'), isNull);
    });

    test('get returns null and evicts the entry if the cached file was deleted externally',
        () async {
      service = buildService();
      await service.initialize();
      final source = await makeSourceFile('photo.jpg', 500);
      await service.set('media_1', source.path, 500);

      final cachedPath = await service.get('media_1');
      await File(cachedPath!).delete();

      expect(await service.get('media_1'), isNull);
    });

    test('set is a no-op (does not throw) if the source file does not exist',
        () async {
      service = buildService();
      await service.initialize();

      await service.set(
          'missing', '${tempDir.path}/does_not_exist.jpg', 100);

      expect(await service.get('missing'), isNull);
    });
  });

  group('CacheService.remove', () {
    test('deletes both the cache entry and the underlying file', () async {
      service = buildService();
      await service.initialize();
      final source = await makeSourceFile('photo.jpg', 100);
      await service.set('media_1', source.path, 100);
      final cachedPath = (await service.get('media_1'))!;

      await service.remove('media_1');

      expect(await service.get('media_1'), isNull);
      expect(await File(cachedPath).exists(), isFalse);
    });

    test('is a no-op for a key that was never cached', () async {
      service = buildService();
      await service.initialize();
      await service.remove('never_cached'); // should not throw
    });
  });

  group('CacheService.getCacheSize', () {
    test('sums the size of all cached entries', () async {
      service = buildService();
      await service.initialize();
      final a = await makeSourceFile('a.jpg', 300);
      final b = await makeSourceFile('b.jpg', 700);
      await service.set('a', a.path, 300);
      await service.set('b', b.path, 700);

      expect(await service.getCacheSize(), 1000);
    });

    test('is zero for an empty cache', () async {
      service = buildService();
      await service.initialize();
      expect(await service.getCacheSize(), 0);
    });
  });

  group('CacheService.clearAll', () {
    test('removes every entry and its backing file', () async {
      service = buildService();
      await service.initialize();
      final a = await makeSourceFile('a.jpg', 100);
      await service.set('a', a.path, 100);
      final cachedPath = (await service.get('a'))!;

      await service.clearAll();

      expect(await service.getCacheSize(), 0);
      expect(await File(cachedPath).exists(), isFalse);
    });

    test('clear() is an alias for clearAll()', () async {
      service = buildService();
      await service.initialize();
      final a = await makeSourceFile('a.jpg', 100);
      await service.set('a', a.path, 100);

      await service.clear();

      expect(await service.getCacheSize(), 0);
    });
  });

  // Regression-style coverage for the LRU eviction logic
  // (_enforceLimit): the least-recently-accessed entries should be
  // evicted first once the configured size limit is exceeded.
  group('CacheService LRU eviction', () {
    test('evicts the least-recently-accessed entry when over the size limit',
        () async {
      // 1 MB limit; three ~400KB entries will exceed it once the third
      // is added, forcing an eviction.
      service = buildService(maxCacheSizeMb: 1);
      await service.initialize();

      final sizeEach = 400 * 1024;
      final a = await makeSourceFile('a.jpg', sizeEach);
      final b = await makeSourceFile('b.jpg', sizeEach);
      final c = await makeSourceFile('c.jpg', sizeEach);

      await service.set('a', a.path, sizeEach);
      // Touch 'a' via get() so its lastAccessedAt is newer than 'b's,
      // making 'b' the least-recently-accessed once 'c' pushes the
      // total over the limit.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await service.set('b', b.path, sizeEach);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await service.get('a'); // refresh 'a's LRU timestamp
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await service.set('c', c.path, sizeEach); // triggers _enforceLimit

      // 'b' should have been evicted (least recently accessed);
      // 'a' and 'c' should remain.
      expect(await service.get('b'), isNull);
      expect(await service.get('a'), isNotNull);
      expect(await service.get('c'), isNotNull);
    });

    test('does not evict anything while under the size limit', () async {
      service = buildService(maxCacheSizeMb: 500);
      await service.initialize();
      final a = await makeSourceFile('a.jpg', 100);
      await service.set('a', a.path, 100);

      expect(await service.get('a'), isNotNull);
    });
  });
}
