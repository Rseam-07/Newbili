import 'dart:io';

import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory settings;
  var appMode = true;
  var batch = <int>[];
  var failure = '';
  final indices = <int>[];
  setUpAll(() async {
    settings = await Directory.systemTemp.createTemp('newbili-refresh-test-');
    Hive.init(settings.path);
    GStorage.setting = await Hive.openBox('setting');
    GStorage.video = await Hive.openBox('video');
    GStorage.localCache = await Hive.openBox('localCache');
    await GStorage.localCache.putAll({
      LocalCacheKey.timeStamp: DateTime.now().millisecondsSinceEpoch,
      LocalCacheKey.mixinKey: 'test-wbi-key',
    });
    Request();
    Request.dio.interceptors.clear();
    Request.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          indices.add(
            options.queryParameters[appMode ? 'idx' : 'fresh_idx'] as int,
          );
          if (failure == 'transport') {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
            return;
          }
          handler.resolve(
            Response(
              requestOptions: options,
              data: failure == 'api'
                  ? {'code': -503, 'message': '测试服务暂不可用'}
                  : {
                      'code': 0,
                      'data': {
                        appMode ? 'items' : 'item': [
                          for (final id in batch)
                            appMode ? appVideo(id) : webVideo(id),
                        ],
                      },
                    },
            ),
          );
        },
      ),
    );
  });
  setUp(() {
    batch = [1, 2];
    failure = '';
    indices.clear();
  });
  tearDownAll(() async {
    Request.dio.close(force: true);
    await Hive.close();
    await settings.delete(recursive: true);
  });

  for (final useApp in [true, false]) {
    final source = useApp ? 'app' : 'web';
    Future<RcmdController> controller({bool retain = true}) async {
      appMode = useApp;
      await GStorage.setting.put(SettingBoxKey.appRcmd, useApp);
      final result = RcmdController()
        ..enableSaveLastData = retain
        ..savedRcmdTip = true;
      addTearDown(result.onClose);
      return result;
    }

    test(
      '$source repeated refresh retains older cards without duplicates',
      () async {
        final c = await controller();
        await c.onRefresh();
        expect(c.loadingState.value, isA<Success>());
        for (var id = 3; id <= 5; id++) {
          batch = [id, 2];
          await c.onRefresh();
          expect(c.requestError.value, isNull);
          expect(c.loadingState.value.data!.map((item) => item.aid), [
            id,
            2,
            for (var old = id - 1; old >= 3; old--) old,
            1,
          ]);
          expect(c.lastRefreshAt, 2);
        }
        batch = [6, 2];
        await c.onLoadMore();
        expect(c.requestError.value, isNull);
        expect(c.loadingState.value.data!.map((item) => item.aid), [
          5,
          2,
          4,
          3,
          1,
          6,
        ]);
        batch = [7];
        await c.onRefresh();
        expect(c.requestError.value, isNull);
        expect(c.loadingState.value.data!.map((item) => item.aid), [
          7,
          5,
          2,
          4,
          3,
          1,
          6,
        ]);
        expect(indices, [0, 1, 2, 3, 4, 5]);
      },
    );

    test('$source refresh replaces cards when retention is disabled', () async {
      final c = await controller(retain: false);
      await c.onRefresh();
      batch = [3];
      await c.onRefresh();
      expect(c.requestError.value, isNull);
      expect(c.loadingState.value.data!.single.aid, 3);
      expect(c.lastRefreshAt, isNull);
    });

    test('$source failed refresh preserves cards and retry recovers', () async {
      final c = await controller();
      await c.onRefresh();
      for (final error in ['transport', 'api']) {
        final previous = c.loadingState.value.data;
        failure = error;
        await c.onRefresh();
        expect(c.requestError.value, isNotEmpty);
        expect(c.isLoading, isFalse);
        expect(c.loadingState.value.data, same(previous));
        failure = '';
        batch = [error == 'transport' ? 3 : 4];
        await c.retryFailedRequest();
        expect(c.requestError.value, isNull);
        expect(c.loadingState.value.data!.first.aid, batch.single);
      }
    });
  }
}

Map<String, dynamic> appVideo(int id) => {
  'card_goto': 'av',
  'goto': 'av',
  'can_play': 1,
  'param': '$id',
  'bvid': 'BVtest$id',
  'title': 'Recommendation $id',
  'cover': '',
  'cover_left_text_1': '1000',
  'cover_left_text_2': '10',
  'args': {'up_id': 1, 'up_name': 'Test'},
  'player_args': {'aid': id, 'cid': id, 'duration': 60},
};

Map<String, dynamic> webVideo(int id) => {
  'id': id,
  'cid': id,
  'bvid': 'BVtest$id',
  'goto': 'av',
  'title': 'Recommendation $id',
  'pic': '',
  'duration': 60,
  'owner': {'name': 'Test', 'mid': 1},
  'stat': {'view': 1000, 'danmaku': 10},
};
