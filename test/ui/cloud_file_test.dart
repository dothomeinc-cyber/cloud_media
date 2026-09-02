import 'package:cloud_media/models/cloud_media_item.dart';
import 'package:cloud_media/models/cloud_media_status.dart';
import 'package:cloud_media/models/cloud_media_type.dart';
import 'package:cloud_media/ui/widgets/cloud_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

// CloudFile is the one media-display widget in this package that's a
// plain StatelessWidget with no Firebase/async dependency at all (it
// just renders a CloudMediaItem's icon/name/size and two callback
// buttons) — unlike CloudImage/CloudVideo/CloudAudio, which all load a
// real network/local resource and genuinely do need Firebase or a real
// device to exercise meaningfully. This is fully unit-testable.

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
  );
}

CloudMediaItem _buildItem({required String fileName, int size = 12345}) {
  return CloudMediaItem(
    id: 'file_1',
    userId: 'user_1',
    type: CloudMediaType.file,
    fileName: fileName,
    mimeType: 'application/octet-stream',
    size: size,
    storagePath: 'users/user_1/media/$fileName',
    downloadUrl: 'https://example.com/$fileName',
    thumbnailUrl: '',
    status: CloudMediaStatus.synced,
    createdAt: DateTime.now(),
  );
}

void main() {
  group('CloudFile', () {
    testWidgets('renders the file name and formatted size', (tester) async {
      final item = _buildItem(fileName: 'report.pdf', size: 2048);

      await tester.pumpWidget(_wrap(CloudFile(media: item)));

      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('2.0 KB'), findsOneWidget);
    });

    testWidgets('shows the pdf icon for a .pdf file', (tester) async {
      final item = _buildItem(fileName: 'report.pdf');
      await tester.pumpWidget(_wrap(CloudFile(media: item)));
      expect(find.text('📄'), findsOneWidget);
    });

    testWidgets('shows the generic icon for an unrecognized extension',
        (tester) async {
      final item = _buildItem(fileName: 'data.xyz');
      await tester.pumpWidget(_wrap(CloudFile(media: item)));
      expect(find.text('📁'), findsOneWidget);
    });

    testWidgets('shows download and share buttons', (tester) async {
      final item = _buildItem(fileName: 'report.pdf');
      await tester.pumpWidget(_wrap(CloudFile(media: item)));

      expect(find.byIcon(Icons.download), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('tapping download invokes onDownload', (tester) async {
      var downloaded = false;
      final item = _buildItem(fileName: 'report.pdf');

      await tester.pumpWidget(_wrap(CloudFile(
        media: item,
        onDownload: () => downloaded = true,
      )));
      await tester.tap(find.byIcon(Icons.download));
      await tester.pump();

      expect(downloaded, isTrue);
    });

    testWidgets('tapping share invokes onShare', (tester) async {
      var shared = false;
      final item = _buildItem(fileName: 'report.pdf');

      await tester.pumpWidget(_wrap(CloudFile(
        media: item,
        onShare: () => shared = true,
      )));
      await tester.tap(find.byIcon(Icons.share));
      await tester.pump();

      expect(shared, isTrue);
    });

    testWidgets('download/share buttons are disabled (no-op, don\'t crash) when callbacks are null',
        (tester) async {
      final item = _buildItem(fileName: 'report.pdf');
      await tester.pumpWidget(_wrap(CloudFile(media: item)));

      // onPressed: null renders a disabled IconButton — tapping it does
      // nothing and must not throw.
      await tester.tap(find.byIcon(Icons.download), warnIfMissed: false);
      await tester.pump();
    });

    testWidgets('long file names are truncated, not overflowing', (tester) async {
      final item = _buildItem(
          fileName:
              'a_genuinely_very_long_file_name_that_would_overflow_a_normal_width_tile.pdf');
      await tester.pumpWidget(_wrap(CloudFile(media: item)));

      final textWidget = tester.widget<Text>(find.text(item.fileName));
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });
  });
}
