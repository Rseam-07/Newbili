import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart' show tabBarView;
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/home/controller.dart';
import 'package:PiliPlus/pages/home/home_header.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends CommonPageState<HomePage>
    with AutomaticKeepAliveClientMixin {
  late ColorScheme _colorScheme;
  final _homeController = Get.putOrFind(HomeController.new);
  final _mainController = Get.find<MainController>();

  @override
  bool get needsCorrection => _homeController.hideTopBar;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _colorScheme = ColorScheme.of(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Widget tabBar;
    if (_homeController.tabs.length > 1) {
      tabBar = Padding(
        padding: const EdgeInsets.only(top: 8),
        child: HomeSectionTabs(
          controller: _homeController.tabController,
          labels: _homeController.tabs.map((e) => e.label).toList(),
          onTap: (_) {
            feedBack();
            if (!_homeController.tabController.indexIsChanging) {
              _homeController.animateToTop();
            }
          },
        ),
      );
      if (_homeController.hideTopBar &&
          _mainController.barHideType == .instant) {
        tabBar = Material(
          color: _colorScheme.surface,
          child: tabBar,
        );
      }
    } else {
      tabBar = const SizedBox(height: 6);
    }
    return Column(
      children: [
        if (MediaQuery.sizeOf(context).width < 840) ...[
          customAppBar(),
          tabBar,
        ],
        Expanded(
          child: onBuild(
            tabBarView(
              controller: _homeController.tabController,
              children: _homeController.tabs.map((e) => e.page).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget customAppBar() {
    const padding = EdgeInsets.zero;
    final child = NewbiliHomeToolbar(
      onSearch: () => Get.toNamed('/search'),
      trailing: Obx(
        () => _mainController.accountService.isLogin.value
            ? msgBadge(_mainController)
            : IconButton(
                tooltip: '账号消息',
                onPressed: _mainController.toMinePage,
                icon: const Icon(Icons.notifications_none_rounded, size: 22),
              ),
      ),
    );
    if (_homeController.hideTopBar) {
      if (_mainController.barOffset case final barOffset?) {
        return Obx(
          () {
            final offset = barOffset.value;
            return NewbiliCollapsingToolbar(
              offset: offset,
              child: child,
            );
          },
        );
      }
      if (_homeController.showTopBar case final showTopBar?) {
        return Obx(() {
          final showSearchBar = showTopBar.value;
          return TweenAnimationBuilder<double>(
            tween: Tween(end: showSearchBar ? 0 : Style.topBarHeight),
            curve: NewbiliMotion.emphasized,
            duration: NewbiliMotion.duration(context, NewbiliMotion.container),
            child: child,
            builder: (context, offset, child) => NewbiliCollapsingToolbar(
              offset: offset,
              child: child!,
            ),
          );
        });
      }
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: padding,
      child: child,
    );
  }
}

Widget userAvatar({
  required ColorScheme colorScheme,
  required MainController mainController,
}) {
  return Semantics(
    label: "我的",
    child: Obx(
      () {
        if (mainController.accountService.isLogin.value) {
          return SizedBox.square(
            dimension: 48,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: .none,
              children: [
                NetworkImgLayer(
                  type: .avatar,
                  width: 34,
                  height: 34,
                  src: mainController.accountService.face.value,
                ),
                Positioned.fill(
                  child: Material(
                    type: .transparency,
                    child: InkWell(
                      onTap: mainController.toMinePage,
                      splashColor: colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      customBorder: const CircleBorder(),
                    ),
                  ),
                ),
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Obx(
                    () => MineController.anonymity.value
                        ? IgnorePointer(
                            child: Container(
                              padding: const .all(2),
                              decoration: BoxDecoration(
                                shape: .circle,
                                color: colorScheme.secondaryContainer,
                              ),
                              child: Icon(
                                size: 14,
                                MdiIcons.incognito,
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          );
        }
        return SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            tooltip: '点击登录',
            style: IconButton.styleFrom(
              padding: .zero,
              backgroundColor: colorScheme.onInverseSurface,
            ),
            onPressed: mainController.toMinePage,
            icon: Icon(
              Icons.person_rounded,
              size: 22,
              color: colorScheme.primary,
            ),
          ),
        );
      },
    ),
  );
}

Widget msgBadge(MainController mainController) {
  return Obx(
    () {
      if (mainController.accountService.isLogin.value) {
        final count = mainController.msgUnReadCount.value;
        final isNumBadge = mainController.msgBadgeMode == .number;
        return IconButton(
          tooltip: '消息',
          onPressed: () {
            Get.toNamed('/whisper')
                ?.whenComplete(mainController.queryUnreadMsg);
          },
          icon: Badge(
            isLabelVisible:
                mainController.msgBadgeMode != .hidden && count.isNotEmpty,
            alignment: isNumBadge
                ? const Alignment(0.0, -0.85)
                : const Alignment(1.0, -0.85),
            label: isNumBadge && count.isNotEmpty ? Text(count) : null,
            child: Icon(
              Icons.notifications_rounded,
              size: 20,
              color: Theme.of(Get.context!).colorScheme.onSurface,
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    },
  );
}
