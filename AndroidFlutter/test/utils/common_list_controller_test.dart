import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a thrown request does not permanently lock list refresh', () async {
    final controller = _TestListController();
    addTearDown(controller.onClose);
    await expectLater(controller.queryData(), throwsStateError);
    expect(controller.isLoading, isFalse);
    await controller.queryData();
    expect(controller.loadingState.value.data, [1, 2]);
    expect(controller.page, 2);
  });

  test(
    'a response handling error also releases the shared loading state',
    () async {
      final controller = _TestListController()
        ..attempts = 1
        ..failParsing = true;
      addTearDown(controller.onClose);
      await expectLater(controller.queryData(), throwsFormatException);
      expect(controller.isLoading, isFalse);
      controller.failParsing = false;
      await controller.queryData();
      expect(controller.loadingState.value.data, [1, 2]);
    },
  );
}

class _TestListController extends CommonListController<List<int>, int> {
  int attempts = 0;
  bool failParsing = false;

  @override
  Future<LoadingState<List<int>>> customGetData() async {
    if (attempts++ == 0) throw StateError('transport interrupted');
    return const Success([1, 2]);
  }

  @override
  List<int>? getDataList(List<int> response) {
    if (failParsing) throw const FormatException('invalid payload');
    return response;
  }
}
