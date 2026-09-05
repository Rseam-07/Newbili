import 'dart:async';

import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';

class FeaturedRecommendationCarousel extends StatefulWidget {
  const FeaturedRecommendationCarousel({
    super.key,
    required this.items,
    this.isVisible = true,
  });

  final List<BaseRcmdVideoItemModel> items;
  final bool isVisible;

  static double height(BuildContext context) =>
      (MediaQuery.sizeOf(context).width >= 720 ? 320.0 : 270.0) +
      (MediaQuery.textScalerOf(context).scale(32) - 32).clamp(
            0,
            double.infinity,
          ) *
          2;

  @override
  State<FeaturedRecommendationCarousel> createState() =>
      _FeaturedRecommendationCarouselState();
}

class _FeaturedRecommendationCarouselState
    extends State<FeaturedRecommendationCarousel>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  Timer? _timer;
  int _index = 0;
  bool? _reduceMotion;
  bool _isActive = true;
  bool _isCurrentRoute = true;
  bool _tickerEnabled = true;
  bool _isDragging = false;
  bool _pausedByUser = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _isCurrentRoute = ModalRoute.isCurrentOf(context) ?? true;
    _restartTimer();
  }

  @override
  void didUpdateWidget(FeaturedRecommendationCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
    }
    _restartTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isActive = state == AppLifecycleState.resumed;
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_reduceMotion == true ||
        widget.items.length < 2 ||
        !widget.isVisible ||
        !_isActive ||
        !_isCurrentRoute ||
        !_tickerEnabled ||
        _isDragging ||
        _pausedByUser) {
      return;
    }
    _timer = Timer(const Duration(seconds: 6), () {
      if (!_pageController.hasClients) return;
      _nextPage();
    });
  }

  void _nextPage() {
    if (!_pageController.hasClients || widget.items.length < 2) return;
    _timer?.cancel();
    _pageController
        .animateToPage(
          (_index + 1) % widget.items.length,
          duration: _reduceMotion == true
              ? Duration.zero
              : NewbiliMotion.container,
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (mounted) _restartTimer();
        });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = FeaturedRecommendationCarousel.height(context);
    return Semantics(
      container: true,
      label: '为你推荐，共${widget.items.length}个视频',
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.depth != 0) return false;
                  if (notification is ScrollStartNotification &&
                      notification.dragDetails != null) {
                    _isDragging = true;
                    _restartTimer();
                  } else if (notification is ScrollEndNotification) {
                    _isDragging = false;
                    _restartTimer();
                  }
                  return false;
                },
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.items.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) =>
                      _FeaturedRecommendation(item: widget.items[index]),
                ),
              ),
            ),
            if (widget.items.length > 1)
              Positioned(
                right: 8,
                top: 8,
                child: IconButton.filledTonal(
                  tooltip: _pausedByUser ? '继续轮播' : '暂停轮播',
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(48),
                    backgroundColor: Colors.black.withValues(alpha: .28),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setState(() => _pausedByUser = !_pausedByUser);
                    _restartTimer();
                  },
                  icon: Icon(
                    _pausedByUser
                        ? CupertinoIcons.play_fill
                        : CupertinoIcons.pause_fill,
                    size: 18,
                  ),
                ),
              ),
            if (widget.items.length > 1)
              Positioned(
                right: 18,
                top: MediaQuery.textScalerOf(context).scale(15) > 20
                    ? 66
                    : null,
                bottom: MediaQuery.textScalerOf(context).scale(15) > 20
                    ? null
                    : 13,
                child: Semantics(
                  label: '第${_index + 1}个，共${widget.items.length}个推荐，下一条',
                  button: true,
                  child: Material(
                    color: Colors.black.withValues(alpha: .32),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: .22),
                      ),
                    ),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: _nextPage,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: index == _index
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: .45),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
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
              colors: [
                Colors.transparent,
                Color(0x33000000),
                Color(0xE6000000),
                Color(0xF5000000),
              ],
              stops: [.2, .54, .94, 1],
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: VideoCardV(videoItem: item).onPushDetail,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  const Text(
                    '为你推荐',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xD1FFFFFF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1.18,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    [
                      item.owner.name,
                      if (item.stat.view != null)
                        '${NumUtils.numFormat(item.stat.view)}次观看',
                    ].nonNulls.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xBDFFFFFF),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // The entire cover is the same play action; this label is
                  // visual chrome rather than a nested competing tap target.
                  Container(
                    constraints: const BoxConstraints(minHeight: 38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: const ShapeDecoration(
                      color: Colors.white,
                      shape: StadiumBorder(),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.play_fill,
                          color: Colors.black,
                          size: 13,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '立即观看',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
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
