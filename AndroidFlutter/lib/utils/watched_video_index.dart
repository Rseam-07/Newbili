import 'dart:collection';

import 'package:PiliPlus/models/model_video.dart';

/// Bounded per-account identities; no titles, thumbnails or viewing timestamps.
class WatchedVideoIndex {
  WatchedVideoIndex({
    required this.read,
    required this.write,
    this.limit = 2000,
  });
  final Iterable<String> Function(int account) read;
  final void Function(int account, List<String> keys) write;
  final int limit;
  final _accounts = <int, LinkedHashSet<String>>{};

  LinkedHashSet<String> _keys(int account) => _accounts.putIfAbsent(
    account,
    () => LinkedHashSet.of(read(account).take(limit)),
  );
  static List<String> identity({String? bvid, int? aid}) => [
    if (bvid != null && bvid.isNotEmpty) 'bv:$bvid',
    if (aid != null && aid > 0) 'av:$aid',
  ];
  bool contains(int account, {String? bvid, int? aid}) =>
      identity(bvid: bvid, aid: aid).any(_keys(account).contains);

  bool mark(int account, {String? bvid, int? aid}) {
    final keys = _keys(account);
    final ids = identity(bvid: bvid, aid: aid);
    if (ids.isEmpty || ids.every(keys.contains)) return false;
    keys.addAll(ids);
    while (keys.length > limit) {
      keys.remove(keys.first);
    }
    write(account, keys.toList(growable: false));
    return true;
  }

  List<T> filter<T extends BaseVideoItemModel>(
    int account,
    Iterable<T> items, {
    Iterable<BaseVideoItemModel> existing = const [],
  }) {
    final seen = <String>{
      for (final item in existing) ...identity(bvid: item.bvid, aid: item.aid),
    };
    return items.where((item) {
      final ids = identity(bvid: item.bvid, aid: item.aid);
      if (contains(account, bvid: item.bvid, aid: item.aid) ||
          ids.any(seen.contains)) {
        return false;
      }
      seen.addAll(ids);
      return true;
    }).toList();
  }
}
