import 'package:PiliPlus/common/widgets/video_card/video_card_h.dart';
import 'package:PiliPlus/models/common/search/search_type.dart';
import 'package:PiliPlus/models/common/search/video_search_type.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/search_result/controls.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets(
      'compact search result keeps title, metadata and 48dp menu at $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(375, 812));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var opened = false;
        final item = SearchVideoItemModel.fromJson({
          'bvid': 'BV1td8R6EE2L',
          'aid': 1,
          'title': '一个很长的<em>搜索</em>视频标题，检查两行截断与触控',
          'duration': '02:00',
          'pubdate': 1,
          'author': '很长很长的创作者名字',
          'play': 12345,
          'is_union_video': 1,
        });
        await tester.pumpWidget(
          _app(
            scale,
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                VideoCardH(
                  videoItem: item,
                  compact: true,
                  onTap: () => opened = true,
                ),
              ],
            ),
          ),
        );
        await tester.pump();
        expect(find.text('合作'), findsOneWidget);
        final menu = tester.getRect(find.byTooltip('视频操作'));
        expect(menu.width, greaterThanOrEqualTo(48));
        expect(menu.height, greaterThanOrEqualTo(48));
        final card = tester.getRect(find.byType(VideoCardH));
        expect(menu.bottom, lessThanOrEqualTo(card.bottom));
        await tester.tapAt(Offset(card.left + 50, card.top + 40));
        expect(opened, true);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'bottom search controls preserve scope, sorting and filters at $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(375, 812));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        SearchType? scope;
        ArchiveFilterType? order;
        var filtered = false;
        await tester.pumpWidget(
          _app(
            scale,
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SearchResultControls(
                  scope: SearchType.video,
                  counts: List.filled(SearchType.values.length, 123),
                  order: ArchiveFilterType.totalrank,
                  onScope: (value) => scope = value,
                  onOrder: (value) => order = value,
                  onFilter: () => filtered = true,
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byTooltip('搜索类型'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('番剧 · 123'));
        await tester.pumpAndSettle();
        expect(scope, SearchType.media_bangumi);
        await tester.tap(find.byTooltip('搜索排序'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('新发布'));
        await tester.pumpAndSettle();
        expect(order, ArchiveFilterType.pubdate);
        final filter = find.byTooltip('时长、分区和发布时间筛选');
        expect(tester.getRect(filter).width, greaterThanOrEqualTo(48));
        await tester.tap(filter);
        expect(filtered, true);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _app(double scale, Widget child) => MaterialApp(
  theme: ThemeData(brightness: scale == 2 ? Brightness.dark : Brightness.light),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(body: child),
  ),
);
