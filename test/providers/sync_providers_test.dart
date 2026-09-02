import 'package:cloud_media/providers/sync_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_offline_sync/riverpod_offline_sync.dart';

void main() {
  group('mapSyncStateType', () {
    test('syncing maps to SyncState.syncing', () {
      expect(mapSyncStateType(SyncStateType.syncing), SyncState.syncing);
    });

    test('failed maps to SyncState.error', () {
      expect(mapSyncStateType(SyncStateType.failed), SyncState.error);
    });

    test('idle maps to SyncState.idle', () {
      expect(mapSyncStateType(SyncStateType.idle), SyncState.idle);
    });

    test('completed also maps to SyncState.idle', () {
      // CloudMedia's own SyncState only distinguishes idle/syncing/error —
      // "completed" isn't a separate state a consumer needs to react to
      // differently from "idle" (nothing is happening right now either way).
      expect(mapSyncStateType(SyncStateType.completed), SyncState.idle);
    });

    test('every SyncStateType value maps to something without throwing', () {
      for (final type in SyncStateType.values) {
        expect(() => mapSyncStateType(type), returnsNormally);
      }
    });
  });

  group('countOperationsByCategory', () {
    test('counts operations grouped by category', () {
      final ops = [
        {'category': 'media_upload'},
        {'category': 'media_upload'},
        {'category': 'thumbnail_upload'},
        {'category': 'media_delete'},
      ];

      final result = countOperationsByCategory(ops);

      expect(result, {
        'media_upload': 2,
        'thumbnail_upload': 1,
        'media_delete': 1,
      });
    });

    test('returns an empty map for an empty list', () {
      expect(countOperationsByCategory([]), isEmpty);
    });

    test('groups a missing category key under "unknown"', () {
      final ops = [
        <String, dynamic>{'mediaId': 'no_category_here'},
      ];

      expect(countOperationsByCategory(ops), {'unknown': 1});
    });

    test('groups a non-string category value under "unknown"', () {
      final ops = [
        <String, dynamic>{'category': 42},
      ];

      expect(countOperationsByCategory(ops), {'unknown': 1});
    });

    test('mixes known categories and unknowns correctly', () {
      final ops = [
        {'category': 'media_upload'},
        <String, dynamic>{},
        {'category': 'media_upload'},
      ];

      expect(countOperationsByCategory(ops), {
        'media_upload': 2,
        'unknown': 1,
      });
    });
  });
}
