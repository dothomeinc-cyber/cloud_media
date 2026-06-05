import '../api/cloud_media_api.dart';
import '../models/cloud_media_item.dart';
import '../models/cloud_media_type.dart';

class CloudMediaListOptions {
  const CloudMediaListOptions({
    this.type,
    this.limit = 50,
    this.offset = 0,
    this.startDate,
    this.endDate,
    this.searchQuery,
    this.orderBy = 'createdAt',
    this.descending = true,
  });

  final CloudMediaType? type;
  final int limit;
  final int offset;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? searchQuery;
  final String orderBy;
  final bool descending;
}

extension CloudMediaListExtension on CloudMedia {
  static Future<List<CloudMediaItem>> listWithOptions(
      CloudMediaListOptions options) async {
    return CloudMedia.list(
      type: options.type,
      limit: options.limit,
      offset: options.offset,
      startDate: options.startDate,
      endDate: options.endDate,
      searchQuery: options.searchQuery,
    );
  }

  static Future<List<CloudMediaItem>> listByType(
    CloudMediaType type, {
    int limit = 50,
    int offset = 0,
  }) async {
    return CloudMedia.list(type: type, limit: limit, offset: offset);
  }

  static Future<List<CloudMediaItem>> listRecent({int limit = 20}) async {
    return CloudMedia.list(limit: limit);
  }

  static Future<List<CloudMediaItem>> listByDateRange(
    DateTime startDate,
    DateTime endDate, {
    CloudMediaType? type,
  }) async {
    return CloudMedia.list(
        type: type, startDate: startDate, endDate: endDate);
  }
}
