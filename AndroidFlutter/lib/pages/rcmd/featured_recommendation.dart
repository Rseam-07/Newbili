import 'dart:async';

import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:material_ui/material_ui.dart';

class FeaturedRecommendationCarousel extends StatefulWidget {
  const FeaturedRecommendationCarousel({
    super.key,
    required this.items,
  });

  final List<BaseRcmdVideoItemModel> items;

  @override
  State<FeaturedRecommendationCarousel> createState() =>
      _FeaturedRecommendationCarouselState();
}

class _FeaturedRecommendationCarouselState
    extends State<FeaturedRecommendationCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _index = 0;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion != reduceMotion) {
      _reduceMotion = reduceMotion;
      _restartTimer();
    }
  }

  @override
  void didUpdateWidget(FeaturedRecommendationCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      _index = 0;
      if (_pageController.hasClients) _pageController.jumpToPage(0);
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_reduceMotion == true || widget.items.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_pageController.hasClients) return;
      final next = (_index + 1) % widget.items.length;
      _pageController.animateToPage(
        next,
        duration: NewbiliMotion.container,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).width >= 720 ? 300.0 : 220.0;
    return Semantics(
      container: true,
      label: '为你推荐，共${widget.items.length}个视频',
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(NewbiliMetrics.cardRadius),
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.items.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) =>
                    _FeaturedRecommendation(item: widget.items[index]),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 14,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  widget.items.length,
                  (index) => AnimatedContainer(
                    duration: _reduceMotion == true
                        ? Duration.zero
                        : NewbiliMotion.feedback,
                    curve: Curves.easeOutCubic,
                    width: index == _index ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.only(left: 5),
                    decoration: BoxDecoration(
                      color: index == _index
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white.withValues(alpha: .62),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedRecommendation extends StatelessWidget {
  const _FeaturedRecommendation({required this.item});

  final BaseRcmdVideoItemModel item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => NetworkImgLayer(
            src: item.cover,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            borderRadius: BorderRadius.zero,
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x12000000), Color(0xE8000000)],
              stops: [0, 1],
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: VideoCardV(videoItem: item).onPushDetail,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: .86),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Text(
                        '为你推荐',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1.18,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.rcmdReason ?? 'UP · ${item.owner.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
