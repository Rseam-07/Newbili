import 'dart:async';

import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';

class PlayOrPauseButton extends StatefulWidget {
  final PlPlayerController plPlayerController;

  const PlayOrPauseButton({
    super.key,
    required this.plPlayerController,
  });

  @override
  PlayOrPauseButtonState createState() => PlayOrPauseButtonState();
}

class PlayOrPauseButtonState extends State<PlayOrPauseButton>
    with SingleTickerProviderStateMixin {
  static const _stateAnimationDuration = Duration(milliseconds: 180);
  static const _pressAnimationDuration = Duration(milliseconds: 100);

  late final AnimationController controller;
  late final StreamSubscription<bool> subscription;
  late Player player;
  late bool _isPlaying;
  bool _isPressed = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    player = widget.plPlayerController.videoPlayerController!;
    _isPlaying = player.state.playing;
    controller = AnimationController(
      vsync: this,
      value: _isPlaying ? 1 : 0,
      duration: _stateAnimationDuration,
    );
    subscription = player.stream.playing.listen((playing) {
      if (mounted && playing != _isPlaying) {
        setState(() => _isPlaying = playing);
      }
      if (_reduceMotion) {
        controller.value = playing ? 1 : 0;
        return;
      }
      if (playing) {
        controller.forward();
      } else {
        controller.reverse();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion == _reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      controller.value = _isPlaying ? 1 : 0;
      if (_isPressed) {
        setState(() => _isPressed = false);
      }
    }
  }

  void _setPressed(bool value) {
    if (_reduceMotion || _isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  void dispose() {
    subscription.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.plPlayerController.onDoubleTapCenter,
        child: Center(
          child: AnimatedScale(
            scale: _isPressed ? 0.94 : 1,
            duration: _reduceMotion ? Duration.zero : _pressAnimationDuration,
            curve: Curves.easeOutCubic,
            child: AnimatedIcon(
              semanticLabel: _isPlaying ? '暂停' : '播放',
              progress: controller,
              icon: AnimatedIcons.play_pause,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
