import 'package:cloud_media/utils/date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateFormatter.formatDuration', () {
    test('formats seconds and minutes under an hour as MM:SS', () {
      expect(DateFormatter.formatDuration(const Duration(seconds: 5)),
          '00:05');
      expect(
          DateFormatter.formatDuration(
              const Duration(minutes: 3, seconds: 45)),
          '03:45');
      expect(
          DateFormatter.formatDuration(
              const Duration(minutes: 59, seconds: 59)),
          '59:59');
    });

    // Regression test: formatDuration previously used
    // duration.inMinutes.remainder(60) with no hours component, so an
    // hour-plus duration silently wrapped around — 1h05m30s displayed
    // as "05:30", losing the hour entirely. Real videos/audio near or
    // over CloudMediaType's size limits can plausibly run this long.
    test('includes the hour component at or above one hour', () {
      expect(
          DateFormatter.formatDuration(
              const Duration(hours: 1, minutes: 5, seconds: 30)),
          '1:05:30');
      expect(
          DateFormatter.formatDuration(const Duration(hours: 1)),
          '1:00:00');
    });

    test('handles multi-hour durations', () {
      expect(
          DateFormatter.formatDuration(
              const Duration(hours: 2, minutes: 30, seconds: 15)),
          '2:30:15');
    });

    test('zero duration formats as 00:00', () {
      expect(DateFormatter.formatDuration(Duration.zero), '00:00');
    });
  });

  group('DateFormatter.formatTimeAgo', () {
    test('a moment ago reads as "Just now"', () {
      final now = DateTime.now();
      expect(DateFormatter.formatTimeAgo(now), 'Just now');
    });

    // Subtracting a couple of extra seconds of buffer against the small
    // amount of real wall-clock time that elapses between building the
    // input and formatTimeAgo's own internal DateTime.now() call, so
    // these don't flake by landing exactly on a boundary.
    test('minutes ago', () {
      final past =
          DateTime.now().subtract(const Duration(minutes: 5, seconds: 2));
      expect(DateFormatter.formatTimeAgo(past), '5 minutes ago');
    });

    test('hours ago', () {
      final past =
          DateTime.now().subtract(const Duration(hours: 3, seconds: 2));
      expect(DateFormatter.formatTimeAgo(past), '3 hours ago');
    });

    test('days ago', () {
      final past =
          DateTime.now().subtract(const Duration(days: 2, seconds: 2));
      expect(DateFormatter.formatTimeAgo(past), '2 days ago');
    });
  });
}
