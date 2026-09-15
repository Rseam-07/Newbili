import 'package:PiliPlus/models/common/enum_with_label.dart';
import 'package:PiliPlus/pages/dynamics/view.dart';
import 'package:PiliPlus/pages/home/view.dart';
import 'package:PiliPlus/pages/mine/view.dart';
import 'package:PiliPlus/pages/live/view.dart';
import 'package:PiliPlus/pages/search/view.dart';
import 'package:material_ui/material_ui.dart';

enum NavigationBarType implements EnumWithLabel {
  home(
    '首页',
    Icon(Icons.home_outlined),
    Icon(Icons.home_rounded),
    HomePage(),
  ),
  dynamics(
    '动态',
    Icon(Icons.dynamic_feed_outlined),
    Icon(Icons.dynamic_feed_rounded),
    DynamicsPage(),
  ),
  mine(
    '我的',
    Icon(Icons.account_circle_outlined),
    Icon(Icons.account_circle_rounded),
    MinePage(),
  ),
  // Append persisted enum values; never shift existing users' stored indices.
  live(
    '直播',
    Icon(Icons.live_tv_outlined),
    Icon(Icons.live_tv_rounded),
    LivePage(controllerTag: 'root-live'),
  ),
  search(
    '搜索',
    Icon(Icons.search_rounded),
    Icon(Icons.search_rounded),
    SearchPage(embedded: true),
  ),
  ;

  static const defaultTabs = [home, dynamics, live, mine, search];

  @override
  final String label;
  final Icon icon;
  final Icon selectIcon;
  final Widget page;

  const NavigationBarType(this.label, this.icon, this.selectIcon, this.page);
}
