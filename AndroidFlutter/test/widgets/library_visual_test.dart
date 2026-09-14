import 'dart:convert' show jsonDecode;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:PiliPlus/common/widgets/newbili_form.dart';
import 'package:PiliPlus/common/widgets/newbili_library.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const fontPath = String.fromEnvironment('NEWBILI_VISUAL_FONT');
  const outputDirectory = String.fromEnvironment('NEWBILI_VISUAL_OUTPUT');
  setUpAll(() async {
    if (fontPath.isEmpty) return;
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in fonts) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in entry['fonts'] as List) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
    await ui.loadFontFromList(
      await File(fontPath).readAsBytes(),
      fontFamily: 'NewbiliPreview',
    );
  });

  for (final (name, brightness, width, scale) in [
    ('library-light', Brightness.light, 375.0, 1.0),
    ('library-dark', Brightness.dark, 375.0, 1.0),
    ('library-large-text', Brightness.light, 320.0, 2.0),
  ]) {
    testWidgets(name, (tester) async {
      final size = Size(width, 812);
      final boundaryKey = GlobalKey();
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFFEE719E),
        brightness: brightness,
      ).copyWith(primary: const Color(0xFFEE719E));

      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(colorScheme: scheme, fontFamily: 'NewbiliPreview'),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: Builder(
                builder: (context) => Scaffold(
                  backgroundColor: NewbiliFormStyle.background(context),
                  appBar: AppBar(title: const Text('观看记录'), centerTitle: true),
                  body: ListView(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('今天', style: TextStyle(fontSize: 14)),
                      ),
                      NewbiliLibraryTile(
                        title: '沿着海岸线，去看一个不一样的日落',
                        cover: null,
                        subtitle: '城市漫游',
                        metadata: '今天 12:30',
                        progressLabel: '看到 12:34 / 24:00',
                        progress: .52,
                        trailing: IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.more_horiz_rounded),
                        ),
                      ),
                      NewbiliLibraryTile(
                        title: '把生活过成喜欢的样子',
                        cover: null,
                        subtitle: '日常记录',
                        metadata: '今天 10:24',
                        badge: '已收藏',
                        trailing: IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.more_horiz_rounded),
                        ),
                      ),
                      const NewbiliLibraryTile(
                        title: '喜欢的视频',
                        cover: null,
                        metadata: '24 个内容 · 公开',
                      ),
                      const NewbiliLibraryTile(
                        title: '稍后再看：周末电影清单',
                        cover: null,
                        subtitle: '电影放映室',
                        metadata: '昨天 19:00',
                        selecting: true,
                        selected: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      if (outputDirectory.isNotEmpty) {
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File('$outputDirectory/$name.png');
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
