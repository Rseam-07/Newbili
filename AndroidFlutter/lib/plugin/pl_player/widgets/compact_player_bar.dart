import 'package:material_ui/material_ui.dart';

/// A single 48dp transport row, with secondary controls opened on demand.
class CompactPlayerBar extends StatelessWidget {
  const CompactPlayerBar({
    super.key,
    required this.playing,
    required this.time,
    required this.timeline,
    required this.total,
    required this.onPlay,
    required this.onMore,
    required this.onFullscreen,
    required this.fullscreen,
  });
  final bool playing;
  final String time;
  final String total;
  final Widget timeline;
  final VoidCallback onPlay;
  final VoidCallback onMore;
  final VoidCallback onFullscreen;
  final bool fullscreen;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Material(
      type: MaterialType.transparency,
      child: Row(
        children: [
          _button(
            playing ? '暂停' : '播放',
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            onPlay,
          ),
          SizedBox(
            width: 52,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    total,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white70,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(height: 48, child: timeline),
            ),
          ),
          _button('更多播放控制', Icons.tune_rounded, onMore),
          _button(
            fullscreen ? '退出全屏' : '全屏',
            fullscreen
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            onFullscreen,
          ),
        ],
      ),
    ),
  );

  Widget _button(String label, IconData icon, VoidCallback action) =>
      SizedBox.square(
        dimension: 48,
        child: IconButton(
          tooltip: label,
          onPressed: action,
          icon: Icon(icon, size: 24, color: Colors.white),
        ),
      );
}
