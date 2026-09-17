import 'package:PiliPlus/common/widgets/scaffold/mini_scaffold.dart';
import 'package:PiliPlus/pages/video/widgets/tablet_player_stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('tablet reply details stay in the card and unwind before playback', (
    tester,
  ) async {
    const size = Size(1280, 800);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(Get.reset);
    final sheetKey = GlobalKey<MiniScaffoldState>();
    final playerKey = GlobalKey();
    var position = 36;

    Widget replyList(BuildContext context) => Center(
      child: TextButton(
        onPressed: () => MiniScaffold.of(context).showBottomSheet(
          constraints: const BoxConstraints(),
          (context) => SizedBox.expand(
            key: const ValueKey('reply-details'),
            child: Material(
              child: Column(
                children: [
                  const Text('评论详情'),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('关闭详情'),
                  ),
                ],
              ),
            ),
          ),
        ),
        child: const Text('共4条回复'),
      ),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: TextButton(
            onPressed: () => Get.to<void>(
              () => Scaffold(
                body: TabletPlayerStage(
                  sheetKey: sheetKey,
                  playerBuilder: (_, _) => StatefulBuilder(
                    key: playerKey,
                    builder: (context, setState) => Center(
                      child: TextButton(
                        onPressed: () => setState(() => position++),
                        child: Text('播放位置 $position'),
                      ),
                    ),
                  ),
                  details: const Center(child: Text('视频简介')),
                  secondary: Builder(builder: replyList),
                  onSendDanmaku: () {},
                ),
              ),
            ),
            child: const Text('打开视频'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开视频'));
    await tester.pumpAndSettle();
    final playerState = playerKey.currentState;
    expect(tester.getRect(find.byKey(playerKey)), Offset.zero & size);
    expect(find.text('Newbili'), findsNothing);

    await tester.tap(find.byTooltip('打开简介、评论与动态'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('评论'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('共4条回复'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('评论详情').hitTestable(), findsOneWidget);
    final card = tester.getRect(
      find.byKey(const ValueKey('tablet-content-surface')),
    );
    expect(tester.getRect(find.byKey(const ValueKey('reply-details'))), card);
    expect(tester.getRect(find.byKey(playerKey)).right, size.width * .7);
    expect(playerKey.currentState, same(playerState));
    expect(sheetKey.currentState, isNotNull);

    // Reply details must not capture touches on the video.
    await tester.tap(find.text('播放位置 36'));
    await tester.pump();
    expect(find.text('播放位置 37'), findsOneWidget);
    await tester.tap(find.text('关闭详情'));
    await tester.pumpAndSettle();
    expect(find.text('评论详情'), findsNothing);
    expect(find.text('共4条回复').hitTestable(), findsOneWidget);

    await tester.tap(find.text('共4条回复'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('评论详情'), findsNothing);
    expect(find.text('共4条回复').hitTestable(), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byTooltip('打开简介、评论与动态').hitTestable(), findsOneWidget);
    expect(tester.getRect(find.byKey(playerKey)), Offset.zero & size);
    expect(playerKey.currentState, same(playerState));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('打开视频'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
