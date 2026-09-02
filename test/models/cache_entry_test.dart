import 'package:cloud_media/models/cache_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CacheEntry.toJson / fromJson round-trip', () {
    test('preserves every field', () {
      final original = CacheEntry(
        key: 'media_1',
        localPath: '/cache/media_1.jpg',
        size: 4096,
        cachedAt: DateTime.utc(2026, 1, 10, 8),
        lastAccessedAt: DateTime.utc(2026, 1, 15, 9),
      );

      final restored = CacheEntry.fromJson(original.toJson());

      expect(restored.key, original.key);
      expect(restored.localPath, original.localPath);
      expect(restored.size, original.size);
      expect(restored.cachedAt, original.cachedAt);
      expect(restored.lastAccessedAt, original.lastAccessedAt);
    });
  });
}
