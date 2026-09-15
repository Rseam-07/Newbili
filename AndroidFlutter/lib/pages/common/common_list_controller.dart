import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/common/common_controller.dart';
import 'package:get/get.dart';

abstract class CommonListController<R, T> extends CommonController<R, T> {
  int page = 1;
  bool isEnd = false;
  bool? hasFooter;
  int _requestGeneration = 0;
  bool _closed = false;
  Future<void>? _activeRequest;
  Future<void>? _pendingRefresh;
  final requestError = RxnString();
  bool _failedRefresh = true;

  Future<void> retryFailedRequest() =>
      _failedRefresh ? onRefresh() : onLoadMore();

  @override
  Rx<LoadingState<List<T>?>> loadingState =
      LoadingState<List<T>?>.loading().obs;

  void handleListResponse(List<T> dataList) {}

  List<T>? getDataList(R response) {
    return response as List<T>?;
  }

  void checkIsEnd(int length) {}

  @override
  Future<void> queryData([bool isRefresh = true]) {
    if (_closed || (!isRefresh && isEnd)) return Future.value();
    if (isLoading) {
      if (!isRefresh) return _activeRequest!;
      // Refresh may reset subclass cursors. Ignore the older response and
      // coalesce repeated gestures into one fresh request after it settles.
      _requestGeneration++;
      return _pendingRefresh ??= _activeRequest!.then((_) {
        _pendingRefresh = null;
        return queryData();
      });
    }
    isLoading = true;
    requestError.value = null;
    return _activeRequest = _queryData(isRefresh, ++_requestGeneration);
  }

  Future<void> _queryData(bool isRefresh, int generation) async {
    bool current() => !_closed && generation == _requestGeneration;
    void fail(Error error) {
      if (!current()) return;
      _failedRefresh = isRefresh;
      requestError.value = error.errMsg ?? '暂时无法加载，请重试';
      if (isRefresh && !handleError(error.errMsg)) {
        loadingState.value = error;
      }
    }

    try {
      final LoadingState<R> res = await customGetData();
      if (!current()) return;
      if (res case Success(:final response)) {
        if (!customHandleResponse(isRefresh, res)) {
          final dataList = getDataList(response);
          if (dataList == null || dataList.isEmpty) {
            isEnd = true;
            if (isRefresh) {
              loadingState.value = Success(dataList);
            } else if (hasFooter == true) {
              loadingState.refresh();
            }
            return;
          }
          handleListResponse(dataList);
          if (isRefresh) {
            checkIsEnd(dataList.length);
            loadingState.value = Success(dataList);
          } else if (loadingState.value case Success(:final response)) {
            response!.addAll(dataList);
            checkIsEnd(response.length);
            loadingState.refresh();
          }
        }
        page++;
      } else {
        fail(res is Error ? res : const Error('暂时无法加载，请重试'));
      }
    } catch (_) {
      fail(const Error('加载失败，请检查网络后重试'));
    } finally {
      // Parsing/transport exceptions must not leave every subsequent refresh
      // permanently blocked. Expected API errors remain LoadingState.Error.
      isLoading = false;
    }
  }

  @override
  void onClose() {
    _closed = true;
    _requestGeneration++;
    super.onClose();
  }

  @override
  Future<void> onRefresh() {
    page = 1;
    isEnd = false;
    return super.onRefresh();
  }

  @override
  Future<void> onReload() {
    loadingState.value = LoadingState<List<T>?>.loading();
    return super.onReload();
  }
}
