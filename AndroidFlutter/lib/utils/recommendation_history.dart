import 'dart:async';

import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/watched_video_index.dart';

abstract final class RecommendationHistory {
  static final index = WatchedVideoIndex(
    read: (account) {
      try {
        return (GStorage.localCache.get('watchedRcmd:$account') as List?)
                ?.whereType<String>() ??
            const [];
      } catch (_) {
        return const [];
      }
    },
    write: (account, keys) {
      try {
        unawaited(
          GStorage.localCache
              .put('watchedRcmd:$account', keys)
              .catchError((Object _) {}),
        );
      } catch (_) {
        /* A cache failure must not interrupt playback. */
      }
    },
  );
  static final _syncedAt = <int, DateTime>{};
  static final _pending = <int, Future<void>>{};

  static bool shouldRecord({
    required Duration position,
    required bool playing,
    required bool pausedHistory,
  }) => playing && !pausedHistory && position.inSeconds >= 5;

  static void record({
    required String bvid,
    required int aid,
    required Duration position,
    required bool playing,
  }) {
    if (shouldRecord(
      position: position,
      playing: playing,
      pausedHistory: Pref.historyPause,
    )) {
      index.mark(Accounts.history.mid, bvid: bvid, aid: aid);
    }
  }

  static Future<void> sync(Account account) {
    if (!account.isLogin || Pref.historyPause) return Future.value();
    final previous = _syncedAt[account.mid];
    if (previous != null && DateTime.now().difference(previous).inMinutes < 2) {
      return Future.value();
    }
    return _pending[account.mid] ??= _load(account).whenComplete(() {
      _pending.remove(account.mid);
    });
  }

  static Future<void> _load(Account account) async {
    try {
      int? max, viewAt;
      // Recent server history supplements videos played on this installation.
      for (var page = 0; page < 3; page++) {
        final result = await UserHttp.historyList(
          type: 'all',
          max: max,
          viewAt: viewAt,
          account: account,
        ).timeout(const Duration(seconds: 3));
        final items = result.dataOrNull?.list;
        if (items == null) return;
        for (final item in items) {
          if ((item.progress == -1 || (item.progress ?? 0) >= 5) &&
              (item.history.business == 'archive' ||
                  item.history.bvid?.isNotEmpty == true)) {
            index.mark(
              account.mid,
              bvid: item.history.bvid,
              aid: item.history.oid,
            );
          }
        }
        if (items.length < 20) break;
        final last = items.last;
        if (last.history.oid == max && last.viewAt == viewAt) break;
        max = last.history.oid;
        viewAt = last.viewAt;
      }
      _syncedAt[account.mid] = DateTime.now();
    } catch (_) {
      /* Use the local index if server history is unavailable. */
    }
  }
}
