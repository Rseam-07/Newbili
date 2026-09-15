import 'dart:async';

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a thrown request does not permanently lock list refresh', () async {
    final controller = _TestListController();
    addTearDown(controller.onClose);
    await controller.queryData();
    expect(controller.loadingState.value, isA<Error>());
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
      await controller.queryData();
      expect(controller.loadingState.value, isA<Error>());
      expect(controller.isLoading, isFalse);
      controller.failParsing = false;
      await controller.queryData();
      expect(controller.loadingState.value.data, [1, 2]);
    },
  );
  test(
    'refresh supersedes an in-flight page and coalesces repeat gestures',
    () async {
      final controller = _DeferredListController();
      addTearDown(controller.onClose);
      final initial = controller.queryData();
      controller.pending.removeAt(0).complete(const Success([1, 2]));
      await initial;
      final more = controller.onLoadMore();
      expect(controller.requestedPages, [1, 2]);
      final refresh = controller.onRefresh();
      final repeat = controller.onRefresh();
      controller.pending.removeAt(0).complete(const Success([3, 4]));
      await more;
      expect(controller.loadingState.value.data, [1, 2]);
      expect(controller.requestedPages, [1, 2, 1]);
      controller.pending.removeAt(0).complete(const Success([9, 10]));
      await Future.wait([refresh, repeat]);
      expect(controller.loadingState.value.data, [9, 10]);
      expect(controller.page, 2);
      final next = controller.onLoadMore();
      expect(controller.requestedPages, [1, 2, 1, 2]);
      controller.pending.removeAt(0).complete(const Success([11]));
      await next;
      expect(controller.loadingState.value.data, [9, 10, 11]);
    },
  );

  test(
    'closing during a request prevents late state changes and queued refresh',
    () async {
      final controller = _DeferredListController();
      final initial = controller.queryData();
      final refresh = controller.onRefresh();
      controller.onClose();
      controller.pending.single.complete(const Success([1]));
      await Future.wait([initial, refresh]);
      expect(controller.loadingState.value, isA<Loading>());
      expect(controller.requestedPages, [1]);
    },
  );

  test('failed pagination retains content and retries the same page', () async {
    final controller = _DeferredListController();
    addTearDown(controller.onClose);
    final initial = controller.queryData();
    controller.pending.removeAt(0).complete(const Success([1]));
    await initial;
    final failed = controller.onLoadMore();
    controller.pending.removeAt(0).completeError(StateError('offline'));
    await failed;
    expect(controller.loadingState.value.data, [1]);
    expect(controller.page, 2);
    expect(controller.requestError.value, isNotNull);
    final retry = controller.retryFailedRequest();
    controller.pending.removeAt(0).complete(const Success([2]));
    await retry;
    expect(controller.loadingState.value.data, [1, 2]);
    expect(controller.requestError.value, isNull);
    expect(controller.requestedPages, [1, 2, 2]);
  });
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

class _DeferredListController extends CommonListController<List<int>, int> {
  final requestedPages = <int>[];
  final pending = <Completer<LoadingState<List<int>>>>[];

  @override
  Future<LoadingState<List<int>>> customGetData() {
    requestedPages.add(page);
    final result = Completer<LoadingState<List<int>>>();
    pending.add(result);
    return result.future;
  }

  @override
  List<int> getDataList(List<int> response) => List.of(response);
}
