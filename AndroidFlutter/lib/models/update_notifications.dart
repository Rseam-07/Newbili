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

class TrackedPage {
  const TrackedPage({
    required this.cid,
    required this.page,
    required this.title,
  });
  factory TrackedPage.fromJson(Map<String, dynamic> json) => TrackedPage(
    cid: json['cid'] as int,
    page: json['page'] as int,
    title: json['title'] as String,
  );
  final int cid, page;
  final String title;
  String get label => 'P$page${title.isEmpty ? '' : ' · $title'}';
  Map<String, Object> toJson() => {'cid': cid, 'page': page, 'title': title};
}

class TrackedSeries {
  const TrackedSeries({
    required this.bvid,
    required this.title,
    required this.cover,
    required this.owner,
    required this.pages,
    required this.checkedAt,
    this.markedAt = 0,
    this.known = const [],
  });
  factory TrackedSeries.fromJson(Map<String, dynamic> json) => TrackedSeries(
    bvid: json['bvid'] as String,
    title: json['title'] as String,
    cover: json['cover'] as String,
    owner: json['owner'] as String,
    pages: (json['pages'] as List)
        .map((page) => TrackedPage.fromJson(page as Map<String, dynamic>))
        .toList(growable: false),
    checkedAt: json['checkedAt'] as int,
    markedAt: json['markedAt'] as int? ?? 0,
    known: (json['known'] as List? ?? const []).cast<int>(),
  );
  final String bvid, title, cover, owner;
  final List<TrackedPage> pages;
  final List<int> known;
  final int checkedAt, markedAt;
  int get pageCount => pages.length;

  Map<String, Object> toJson() => {
    'bvid': bvid,
    'title': title,
    'cover': cover,
    'owner': owner,
    'pages': pages.map((page) => page.toJson()).toList(growable: false),
    'known': known,
    'checkedAt': checkedAt,
    'markedAt': markedAt,
  };
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
    '关闭系统通知后仍可手动检查，更新会保留在 App 内，不发送系统提醒。'
    '首次同步只建立基线，不补发历史通知。';
