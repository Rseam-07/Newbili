import 'dart:async';

import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/search/suggest.dart';
import 'package:PiliPlus/models_new/search/search_rcmd/data.dart';
import 'package:PiliPlus/models_new/search/search_trending/data.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stream_transform/stream_transform.dart';

mixin DebounceStreamMixin<T> {
  final Duration duration = const Duration(milliseconds: 200);
  StreamController<T>? ctr;
  StreamSubscription<T>? _sub;
  void onValueChanged(T value);

  void subInit() {
    _sub = (ctr = StreamController<T>()).stream
        .debounce(duration, trailing: true)
        .listen(onValueChanged);
  }

  void subDispose() {
    _sub?.cancel();
    ctr?.close();
    _sub = null;
    ctr = null;
  }
}

abstract class DebounceStreamState<T extends StatefulWidget, S> extends State<T>
    with DebounceStreamMixin<S> {
  @override
  void dispose() {
    subDispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    subInit();
  }
}

class BaseSearchController extends GetxController {
  final historyList = List<String>.from(
    GStorage.historyWord.get('cacheList') ?? const <String>[],
  ).obs;

  late final Rx<LoadingState<SearchTrendingData>> trendingState;

  final recordSearchHistory = Pref.recordSearchHistory.obs;
  final searchSuggestion = Pref.searchSuggestion;
  final enableTrending = Pref.enableTrending;
  final enableSearchRcmd = Pref.enableSearchRcmd;

  @override
  void onInit() {
    super.onInit();

    if (enableTrending) {
      trendingState = LoadingState<SearchTrendingData>.loading().obs;
      queryTrendingList();
    }
  }

  // 获取热搜关键词
  Future<void> queryTrendingList() async {
    try {
      final res = await SearchHttp.searchTrending(limit: 10);
      if (!isClosed) trendingState.value = res;
    } catch (_) {
      if (!isClosed) trendingState.value = const Error('热搜加载失败，请重试');
    }
  }
}

class SSearchController extends GetxController
    with DebounceStreamMixin<String> {
  SSearchController(
    this.tag, {
    Future<LoadingState<SearchSuggestModel>> Function(String term)?
    suggestLoader,
  }) : _suggestLoader =
           suggestLoader ?? ((term) => SearchHttp.searchSuggest(term: term));

  final Future<LoadingState<SearchSuggestModel>> Function(String term)
  _suggestLoader;
  int _suggestGeneration = 0;
  String? _suggestQuery;
  bool _closed = false;
  final String tag;

  final searchFocusNode = FocusNode();
  final controller = TextEditingController();
  final _baseCtr = Get.putOrFind(BaseSearchController.new);

  String? hintText;

  int initIndex = 0;

  // uid
  final RxBool showUidBtn = false.obs;

  // history
  RxBool get recordSearchHistory => _baseCtr.recordSearchHistory;
  RxList<String> get historyList => _baseCtr.historyList;

  // suggestion
  bool get searchSuggestion => _baseCtr.searchSuggestion;
  late final RxList<SearchSuggestItem> searchSuggestList;

  // trending
  bool get enableTrending => _baseCtr.enableTrending;
  Rx<LoadingState<SearchTrendingData>> get trendingState =>
      _baseCtr.trendingState;

  // rcmd
  bool get enableSearchRcmd => _baseCtr.enableSearchRcmd;
  late final Rx<LoadingState<SearchRcmdData>> recommendData;

  Future<void> Function() get queryTrendingList => _baseCtr.queryTrendingList;

  @override
  void onInit() {
    super.onInit();
    final params = Get.parameters;
    hintText = params['hintText'];
    final text = params['text'];
    if (text != null) {
      controller.text = text;
    }

    if (searchSuggestion) {
      subInit();
      searchSuggestList = <SearchSuggestItem>[].obs;
    }

    if (enableSearchRcmd) {
      recommendData = LoadingState<SearchRcmdData>.loading().obs;
      queryRecommendList();
    }
  }

  void validateUid() {
    showUidBtn.value = IdUtils.digitOnlyRegExp.hasMatch(controller.text);
  }

  void onChange(String value) {
    _suggestGeneration++;
    _suggestQuery = value;
    validateUid();
    if (searchSuggestion) {
      searchSuggestList.clear();
      if (value.trim().isNotEmpty) ctr?.add(value);
    }
  }

  void onClear() {
    _suggestGeneration++;
    _suggestQuery = null;
    if (controller.value.text != '') {
      controller.clear();
      if (searchSuggestion) searchSuggestList.clear();
      searchFocusNode.requestFocus();
      showUidBtn.value = false;
    } else {
      Get.back();
    }
  }

  // 搜索
  void submit() {
    _suggestGeneration++;
    _suggestQuery = null;
    if (searchSuggestion) searchSuggestList.clear();
    if (controller.text.isEmpty) {
      if (hintText.isNullOrEmpty) return;
      controller.text = hintText!;
      validateUid();
    }

    if (recordSearchHistory.value) {
      final index = historyList.indexOf(controller.text);
      if (index != 0) {
        if (index != -1) historyList.removeAt(index);
        historyList.insert(0, controller.text);
        GStorage.historyWord.put('cacheList', historyList);
      }
    }

    searchFocusNode.unfocus();
    Get.toNamed(
      '/searchResult',
      parameters: {
        'tag': tag,
        'keyword': controller.text,
      },
      arguments: {
        'initIndex': initIndex,
        'fromSearch': true,
      },
    )?.whenComplete(() {
      if (!_closed) searchFocusNode.requestFocus();
    });
  }

  Future<void> queryRecommendList() async {
    try {
      final res = await SearchHttp.searchRecommend();
      if (!_closed) recommendData.value = res;
    } catch (_) {
      if (!_closed) recommendData.value = const Error('推荐加载失败，请重试');
    }
  }

  void onClickKeyword(String keyword) {
    controller.text = keyword;
    validateUid();

    if (searchSuggestion) searchSuggestList.clear();
    submit();
  }

  @override
  Future<void> onValueChanged(String value) async {
    if (_closed ||
        value.trim().isEmpty ||
        value != controller.text ||
        value != _suggestQuery) {
      return;
    }
    final generation = _suggestGeneration;
    try {
      final res = await _suggestLoader(value);
      if (_closed ||
          generation != _suggestGeneration ||
          value != controller.text) {
        return;
      }
      searchSuggestList.value = switch (res) {
        Success(:final response) => response.tag ?? [],
        _ => [],
      };
    } catch (_) {
      if (!_closed && generation == _suggestGeneration) {
        searchSuggestList.clear();
      }
    }
  }

  void onLongSelect(String word) {
    historyList.remove(word);
    GStorage.historyWord.put('cacheList', historyList);
  }

  void onClearHistory() {
    showConfirmDialog(
      context: Get.context!,
      title: const Text('确定清空搜索历史？'),
      onConfirm: () {
        historyList.clear();
        GStorage.historyWord.delete('cacheList');
      },
    );
  }

  @override
  void onClose() {
    _closed = true;
    _suggestGeneration++;
    subDispose();
    searchFocusNode.dispose();
    controller.dispose();
    super.onClose();
  }
}
