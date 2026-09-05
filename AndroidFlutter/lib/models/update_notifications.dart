import 'package:PiliPlus/models/common/enum_with_label.dart';

enum UploaderNotificationLevel with EnumWithLabel {
  off('关闭', '不检查关注 UP 的新投稿。'),
  specialOnly('仅特别关注', '只提醒已加入特别关注的 UP 新投稿。'),
  allFollowing('全部关注', '提醒动态流中全部已关注 UP 的新投稿。');

  @override
  final String label;
  final String explanation;
  const UploaderNotificationLevel(this.label, this.explanation);
}

class TrackedSeries {
  const TrackedSeries({
    required this.bvid,
    required this.title,
    required this.cover,
    required this.owner,
    required this.pageCount,
    required this.checkedAt,
  });
  factory TrackedSeries.fromJson(Map<String, dynamic> json) => TrackedSeries(
    bvid: json['bvid'] as String,
    title: json['title'] as String,
    cover: json['cover'] as String,
    owner: json['owner'] as String,
    pageCount: (json['pages'] as List).length,
    checkedAt: json['checkedAt'] as int,
  );
  final String bvid, title, cover, owner;
  final int pageCount, checkedAt;
}

class UpdateNotificationState {
  const UpdateNotificationState({
    this.level = UploaderNotificationLevel.off,
    this.tracks = const [],
    this.permission = false,
    this.seriesPermission = false,
    this.upPermission = false,
    this.loggedIn = false,
    this.checking = false,
    this.lastChecked = 0,
    this.status = '尚未检查更新',
    this.recent = const [],
  });
  factory UpdateNotificationState.fromJson(Map<String, dynamic> json) =>
      UpdateNotificationState(
        level: UploaderNotificationLevel.values.byName(json['level'] as String),
        tracks: (json['tracks'] as List)
            .map((item) => TrackedSeries.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        permission: json['permission'] as bool,
        seriesPermission: json['seriesPermission'] as bool,
        upPermission: json['upPermission'] as bool,
        loggedIn: json['loggedIn'] as bool,
        checking: json['checking'] as bool,
        lastChecked: json['lastChecked'] as int,
        status: json['status'] as String,
        recent: (json['recent'] as List).cast<Map<String, dynamic>>(),
      );
  final UploaderNotificationLevel level;
  final List<TrackedSeries> tracks;
  final bool permission, seriesPermission, upPermission, loggedIn, checking;
  final int lastChecked;
  final String status;
  final List<Map<String, dynamic>> recent;
  bool contains(String? bvid) => tracks.any((item) => item.bvid == bvid);
  bool get hasTargets =>
      tracks.isNotEmpty || level != UploaderNotificationLevel.off;
}

const updateDeliveryNotice =
    'Newbili 会在启动、回到前台和系统允许的后台任务中检查更新。'
    '后台检查间隔至少 15 分钟，可能因省电、网络或系统限制延后，不能保证实时送达。'
    '首次同步只建立基线，不补发历史通知。';
