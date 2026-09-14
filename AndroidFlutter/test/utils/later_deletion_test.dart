import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/later/data.dart';
import 'package:PiliPlus/models_new/later/list.dart';
import 'package:PiliPlus/pages/common/multi_select/multi_select_controller.dart';
import 'package:PiliPlus/pages/later/controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _LaterController controller;
  late int removedCount;

  setUp(() {
    removedCount = 0;
    controller = _LaterController()
      ..isEnd = true
      ..updateCount = (count) => removedCount += count;
  });
  tearDown(() => controller.onClose());

  test(
    'deletion follows video identity after a refresh reorders rows',
    () async {
      controller.loadingState.value = Success([
        LaterItemModel(aid: 3),
        LaterItemModel(aid: 2),
        LaterItemModel(aid: 1),
      ]);

      await controller.afterVideosRemoved({2});

      expect(controller.loadingState.value.data!.map((item) => item.aid), [
        3,
        1,
      ]);
      expect(removedCount, 1);
    },
  );

  test(
    'an already removed video cannot remove a different row or count twice',
    () async {
      controller.loadingState.value = Success([LaterItemModel(aid: 3)]);

      await controller.afterVideosRemoved({2});
      await controller.afterVideosRemoved({3});
      await controller.afterVideosRemoved({3});

      expect(controller.loadingState.value.data, isEmpty);
      expect(removedCount, 1);
    },
  );

  test(
    'batch removal preserves newly loaded videos and exits selection',
    () async {
      controller.loadingState.value = Success([
        LaterItemModel(aid: 2),
        LaterItemModel(aid: 3),
        LaterItemModel(aid: 4),
      ]);
      controller.enableMultiSelect.value = true;
      controller.rxCount.value = 3;

      await controller.afterVideosRemoved({1, 2, 3});

      expect(controller.loadingState.value.data!.single.aid, 4);
      expect(removedCount, 2);
      expect(controller.enableMultiSelect.value, isFalse);
      expect(controller.checkedCount, 0);
    },
  );

  test('a pending reload is left intact when deletion finishes', () async {
    await controller.afterVideosRemoved({1});

    expect(controller.loadingState.value, isA<Loading>());
    expect(removedCount, 0);
  });

  test(
    'a failed refresh is not masked by an earlier deletion response',
    () async {
      const state = Error('连接中断');
      controller.loadingState.value = state;

      await controller.afterVideosRemoved({1});

      expect(controller.loadingState.value, same(state));
      expect(removedCount, 0);
    },
  );
}

class _LaterController extends MultiSelectController<LaterData, LaterItemModel>
    with BaseLaterController {
  @override
  Future<LoadingState<LaterData>> customGetData() =>
      throw UnimplementedError('These tests do not perform network requests.');
}
