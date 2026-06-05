class CacheEntry {
  final String key;
  final String localPath;
  final int size;
  final DateTime cachedAt;
  final DateTime lastAccessedAt;

  const CacheEntry({
    required this.key,
    required this.localPath,
    required this.size,
    required this.cachedAt,
    required this.lastAccessedAt,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'localPath': localPath,
        'size': size,
        'cachedAt': cachedAt.toIso8601String(),
        'lastAccessedAt': lastAccessedAt.toIso8601String(),
      };

  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      key: json['key'] as String,
      localPath: json['localPath'] as String,
      size: json['size'] as int,
      cachedAt: DateTime.parse(json['cachedAt'] as String),
      lastAccessedAt: DateTime.parse(json['lastAccessedAt'] as String),
    );
  }
}
