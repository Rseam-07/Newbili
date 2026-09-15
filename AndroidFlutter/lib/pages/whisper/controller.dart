import 'package:PiliPlus/grpc/bilibili/app/im/v1.pb.dart'
    show Offset, Session, SessionMainReply, SessionPageType, ThreeDotItem;
import 'package:PiliPlus/grpc/im.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/msg/msgfeed_unread.dart';
import 'package:PiliPlus/pages/common/common_whisper_controller.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protobuf/protobuf.dart' show PbMap;

class WhisperController extends CommonWhisperController<SessionMainReply> {
  @override
  SessionPageType sessionPageType = SessionPageType.SESSION_PAGE_TYPE_HOME;

  late final List<({bool enabled, IconData icon, String name, String route})>
  msgFeedTopItems;
  late final RxList<int> unreadCounts;

  PbMap<int, Offset>? offset;

  Rx<List<ThreeDotItem>?> threeDotItems = Rx<List<ThreeDotItem>?>(null);
  Rx<List<ThreeDotItem>?> outsideItem = Rx<List<ThreeDotItem>?>(null);

  @override
  void onInit() {
    super.onInit();
    msgFeedTopItems = [
      const (
        name: "回复我的",
        icon: Icons.message_outlined,
        route: "/replyMe",
        enabled: true,
      ),
      const (
        name: "@我",
        icon: Icons.alternate_email_outlined,
        route: "/atMe",
        enabled: true,
      ),
      (
        name: "收到的赞",
        icon: Icons.favorite_border_outlined,
        route: "/likeMe",
        enabled: !Pref.disableLikeMsg,
      ),
      const (
        name: "系统通知",
        icon: Icons.notifications_none_outlined,
        route: "/sysMsg",
        enabled: true,
      ),
    ];
    unreadCounts = List.filled(msgFeedTopItems.length, 0).obs;
    queryMsgFeedUnread();
    queryData();
  }

  bool _queryingUnread = false;
  Future<void> queryMsgFeedUnread() async {
    if (isClosed || _queryingUnread) return;
    _queryingUnread = true;
    try {
      final res = await ImGrpc.getTotalUnread(unreadType: 2);
      if (isClosed) return;
      if (res case Success(:final response)) {
        final data = MsgFeedUnread.fromJson(response.msgFeedUnread.unread);
        final counts = [data.reply, data.at, data.like, data.sysMsg];
        if (!listEquals(unreadCounts, counts)) unreadCounts.value = counts;
      }
    } catch (_) {
      // Retain the last known counts and retry on the next foreground tick.
    } finally {
      _queryingUnread = false;
    }
  }

  Future<void> refreshInbox() async {
    if (scrollController.hasClients && scrollController.offset > 64) {
      await queryMsgFeedUnread();
    } else {
      await onRefresh();
    }
  }

  @override
  bool handleError(String? errMsg) =>
      loadingState.value.dataOrNull?.isNotEmpty == true;

  @override
  List<Session>? getDataList(SessionMainReply response) {
    offset = response.paginationParams.offsets;
    isEnd = !response.paginationParams.hasMore;
    return response.sessions;
  }

  @override
  bool customHandleResponse(
    bool isRefresh,
    Success<SessionMainReply> response,
  ) {
    if (isRefresh) {
      threeDotItems.value = response.response.threeDotItems;
      outsideItem.value = response.response.outsideItem;
    }
    return false;
  }

  @override
  Future<LoadingState<SessionMainReply>> customGetData() =>
      ImGrpc.sessionMain(offset: offset);

  @override
  Future<void> onRefresh() {
    offset = null;
    queryMsgFeedUnread();
    return super.onRefresh();
  }
}
