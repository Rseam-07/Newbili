import 'package:PiliPlus/plugin/pl_player/widgets/compact_player_bar.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/common/widgets/progress_bar/audio_video_progress_bar.dart';
import 'package:PiliPlus/common/widgets/progress_bar/segment_progress_bar.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/view/view.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class BottomControl extends StatelessWidget {
  const BottomControl({
    super.key,
    required this.maxWidth,
    required this.isFullScreen,
    required this.controller,
    required this.buildBottomControl,
    required this.buildMoreControls,
    required this.videoDetailController,
  });

  final double maxWidth;
  final bool isFullScreen;
  final PlPlayerController controller;
  final ValueGetter<Widget> buildBottomControl;
  final ValueGetter<Widget> buildMoreControls;
  final VideoDetailController videoDetailController;

  void onDragStart(ThumbDragDetails duration) {
    feedBack();
    controller
      ..position.value = duration.seconds
      ..isSeeking.value = true;
  }

  void onDragUpdate(ThumbDragDetails duration) {
    if (!controller.isFileSource && controller.showSeekPreview) {
      controller.updatePreviewIndex(duration.seconds);
    }
    controller.position.value = duration.seconds;
  }

  void onSeek(int milliseconds) {
    controller
      ..onSeekEnd()
      ..seekTo(Duration(milliseconds: milliseconds), isSeek: false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final primary = colorScheme.isLight
        ? colorScheme.inversePrimary
        : colorScheme.primary;
    final thumbGlowColor = primary.withAlpha(80);
    final bufferedBarColor = primary.withValues(alpha: 0.4);

    return Obx(
      () => CompactPlayerBar(
        playing: controller.playerStatus.isPlaying,
        time: DurationUtils.formatDuration(controller.position.value),
        total: DurationUtils.formatDuration(controller.duration.value),
        fullscreen: isFullScreen,
        onPlay: controller.onDoubleTapCenter,
        onFullscreen: () => controller.triggerFullScreen(status: !isFullScreen),
        onMore: () {
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: const Color(0xFF202126),
            showDragHandle: true,
            builder: (context) => SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: buildMoreControls(),
              ),
            ),
          );
        },
        timeline: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            ProgressBar(
              progress: controller.position.value,
              buffered: controller.buffered.value,
              total: controller.duration.value,
              progressBarColor: primary,
              baseBarColor: const Color(0x55FFFFFF),
              bufferedBarColor: bufferedBarColor,
              thumbColor: Colors.white,
              thumbGlowColor: thumbGlowColor,
              barHeight: 3,
              thumbRadius: 5,
              thumbGlowRadius: 16,
              onDragStart: onDragStart,
              onDragUpdate: onDragUpdate,
              onSeek: onSeek,
            ),
            if (controller.enableBlock &&
                videoDetailController.segmentProgressList.isNotEmpty)
              IgnorePointer(
                child: Center(
                  child: SizedBox(
                    height: 3,
                    width: double.infinity,
                    child: SegmentProgressBar(
                      segments: videoDetailController.segmentProgressList,
                    ),
                  ),
                ),
              ),
            if (controller.showViewPoints &&
                videoDetailController.viewPointList.isNotEmpty &&
                videoDetailController.showVP.value)
              IgnorePointer(
                child: Center(
                  child: SizedBox(
                    height: 3,
                    width: double.infinity,
                    child: ViewPointSegmentProgressBar(
                      segments: videoDetailController.viewPointList,
                    ),
                  ),
                ),
              ),
            if (videoDetailController.showDmTrendChart.value)
              if (videoDetailController.dmTrend.value?.dataOrNull
                  case final list?)
                IgnorePointer(
                  child: buildDmChart(
                    primary,
                    list,
                    videoDetailController,
                    4.5,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
