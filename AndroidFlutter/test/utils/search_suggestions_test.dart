import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/search/suggest.dart';
import 'package:PiliPlus/pages/search/controller.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

Success<SearchSuggestModel> _result(String term) => Success(
  SearchSuggestModel(
    tag: [
      SearchSuggestItem.fromJson({'term': term, 'name': term}),
    ],
  ),
);

void main() {
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('newbili-search-test-');
    Hive.init(directory.path);
    GStorage.setting = await Hive.openBox('setting');
    GStorage.historyWord = await Hive.openBox('historyWord');
    await GStorage.setting.putAll({
      'enableHotKey': false,
      'enableSearchRcmd': false,
    });
  });
  tearDown(Get.reset);
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets('older suggestions cannot overwrite the latest query', (
    tester,
  ) async {
    final requests = <Completer<LoadingState<SearchSuggestModel>>>[];
    final controller = SSearchController(
      'test',
      suggestLoader: (_) {
        final request = Completer<LoadingState<SearchSuggestModel>>();
        requests.add(request);
        return request.future;
      },
    )..onInit();
    for (final text in ['old', 'new']) {
      controller.controller.text = text;
      controller.onChange(text);
      await tester.pump(const Duration(milliseconds: 220));
    }
    requests[1].complete(_result('new result'));
    await tester.pump();
    requests[0].complete(_result('old result'));
    await tester.pump();
    expect(controller.searchSuggestList.single.term, 'new result');
    controller.onClose();
  });

  for (final action in ['clear', 'close', 'replace with same query']) {
    testWidgets('pending suggestions are ignored after $action', (
      tester,
    ) async {
      final request = Completer<LoadingState<SearchSuggestModel>>();
      final controller = SSearchController(
        'test',
        suggestLoader: (_) => request.future,
      )..onInit();
      controller.controller.text = 'query';
      controller.onChange('query');
      await tester.pump(const Duration(milliseconds: 220));
      switch (action) {
        case 'clear':
          controller.onClear();
        case 'close':
          controller.onClose();
        case 'replace with same query':
          controller.controller.text = 'different';
          controller.onChange('different');
          controller.controller.text = 'query';
          controller.onChange('query');
      }
      request.complete(_result('stale'));
      await tester.pump();
      expect(controller.searchSuggestList, isEmpty);
      if (action != 'close') controller.onClose();
      await tester.pump(const Duration(milliseconds: 220));
    });
  }

  testWidgets('empty or failed suggestions clear old content and allow retry', (
    tester,
  ) async {
    var calls = 0;
    final controller = SSearchController(
      'test',
      suggestLoader: (_) async {
        calls++;
        if (calls == 2) return Success(SearchSuggestModel());
        if (calls == 3) throw StateError('offline');
        return _result('available');
      },
    )..onInit();
    for (var i = 0; i < 4; i++) {
      controller.controller.text = 'query$i';
      controller.onChange('query$i');
      await tester.pump(const Duration(milliseconds: 220));
      expect(controller.searchSuggestList.isNotEmpty, i == 0 || i == 3);
    }
    controller.onClose();
  });
}
