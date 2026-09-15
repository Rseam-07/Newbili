import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/recommendation_history.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

class RcmdController extends CommonListController {
  late bool enableSaveLastData = Pref.enableSaveLastData;
  final bool appRcmd = Pref.appRcmd;

  int? lastRefreshAt;
  late bool savedRcmdTip = Pref.savedRcmdTip;

  @override
  bool get isEnd => false;

  @override
  void onInit() {
    super.onInit();
    page = 0;
    queryData();
  }

  int _feedIndex = 0;
  @override
  Future<LoadingState> customGetData() async {
    final account = Accounts.history;
    final history = RecommendationHistory.sync(account);
    for (var attempt = 0; attempt < 3; attempt++) {
      final requestIndex = _feedIndex++;
      final res = await (appRcmd
          ? VideoHttp.rcmdVideoListApp(freshIdx: requestIndex)
          : VideoHttp.rcmdVideoList(freshIdx: requestIndex, ps: 20));
      if (attempt == 0) {
        await history.timeout(const Duration(seconds: 2), onTimeout: () {});
      }
      if (isClosed || Accounts.history != account) {
        return const Error('账号已切换，请刷新推荐');
      }
      if (res case Success(:final response)) {
        final fresh = RecommendationHistory.index.filter(
          account.mid,
          response,
          existing: page == 0
              ? const []
              : (loadingState.value.dataOrNull ?? [])
                    .whereType<BaseRcmdVideoItemModel>(),
        );
        if (fresh.isNotEmpty) return Success(fresh);
      } else {
        return res;
      }
    }
    return const Error('这一批都是看过的视频，点击换一批');
  }

  @override
  bool handleError(String? errMsg) {
    return enableSaveLastData &&
        loadingState.value.dataOrNull?.isNotEmpty == true;
  }

  @override
  void handleListResponse(List dataList) {
    if (enableSaveLastData && page == 0) {
      final previous = loadingState.value.dataOrNull;
      lastRefreshAt = null;
      if (previous != null && previous.isNotEmpty) {
        final retained = RecommendationHistory.index.filter(
          Accounts.history.mid,
          previous
              .take(previous.length > 200 ? 50 : 200)
              .whereType<BaseRcmdVideoItemModel>(),
          existing: dataList.cast<BaseRcmdVideoItemModel>(),
        );
        if (retained.isNotEmpty && savedRcmdTip) {
          lastRefreshAt = dataList.length;
        }
        dataList.addAll(retained);
      }
    }
  }

  @override
  Future<void> onRefresh() {
    page = 0;
    isEnd = false;
    return queryData();
  }
}
