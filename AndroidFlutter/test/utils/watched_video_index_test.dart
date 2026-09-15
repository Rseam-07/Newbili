import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/utils/recommendation_history.dart';
import 'package:PiliPlus/utils/watched_video_index.dart';
import 'package:flutter_test/flutter_test.dart';

class _Video extends BaseVideoItemModel {
  _Video(String? bv, int? av) {
    bvid = bv;
    aid = av;
  }
}

void main() {
  late Map<int, List<String>> saved;
  late WatchedVideoIndex index;
  setUp(() {
    saved = {};
    index = WatchedVideoIndex(
      read: (account) => saved[account] ?? [],
      write: (account, keys) => saved[account] = keys,
      limit: 6,
    );
  });
  test('matching either identity filters watches, without leaking between accounts', () {
    index.mark(1, bvid: 'BV1', aid: 1);
    final items = [_Video('BV1', null), _Video(null, 1), _Video('BV2', 2)];
    expect(index.filter(1, items), [items.last]);
    expect(index.filter(2, items), items);
    expect(index.filter(0, items), items);
  });
  test('cache and incoming pages deduplicate by either ID', () {
    final existing = [_Video('BV1', 1)];
    final next = [_Video(null, 1), _Video('BV2', 2), _Video('BV2', 2)];
    expect(index.filter(1, next, existing: existing), [next[1]]);
    index.mark(1, aid: 2);
    expect(index.filter(1, next, existing: existing), isEmpty);
  });
  test(
    'bounded identities survive reload and repeat marks do not write again',
    () {
      for (var i = 1; i < 6; i++) {
        index.mark(1, bvid: 'BV$i', aid: i);
      }
      expect(saved[1]!.length, 6);
      final reloaded = WatchedVideoIndex(
        read: (a) => saved[a] ?? [],
        write: (_, _) {},
      );
      expect(reloaded.contains(1, aid: 1), isFalse);
      expect(reloaded.contains(1, bvid: 'BV5'), isTrue);
      expect(index.mark(1, aid: 5), isFalse);
    },
  );
  test('opening, paused playback and paused history do not create a watch', () {
    bool record(int seconds, {bool playing = true, bool paused = false}) =>
        RecommendationHistory.shouldRecord(
          position: Duration(seconds: seconds),
          playing: playing,
          pausedHistory: paused,
        );
    expect(record(0), isFalse);
    expect(record(4), isFalse);
    expect(record(5), isTrue);
    expect(record(50, playing: false), isFalse);
    expect(record(50, paused: true), isFalse);
  });
}
