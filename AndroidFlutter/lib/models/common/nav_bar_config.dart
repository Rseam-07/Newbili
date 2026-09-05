import 'package:PiliPlus/models/common/enum_with_label.dart';
import 'package:PiliPlus/pages/dynamics/view.dart';
import 'package:PiliPlus/pages/home/view.dart';
import 'package:PiliPlus/pages/mine/view.dart';
import 'package:PiliPlus/pages/live/view.dart';
import 'package:PiliPlus/pages/search/view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

enum NavigationBarType implements EnumWithLabel {
  home(
    '首页',
    Icon(CupertinoIcons.house_fill),
    Icon(CupertinoIcons.house_fill),
    HomePage(),
  ),
  dynamics(
    '动态',
    Icon(CupertinoIcons.sparkles),
    Icon(CupertinoIcons.sparkles),
    DynamicsPage(),
  ),
  mine(
    '我的',
    Icon(CupertinoIcons.person_crop_circle_fill),
    Icon(CupertinoIcons.person_crop_circle_fill),
    MinePage(),
  ),
  // Append persisted enum values; never shift existing users' stored indices.
  live(
    '直播',
    Icon(CupertinoIcons.play_rectangle_fill),
    Icon(CupertinoIcons.play_rectangle_fill),
    LivePage(controllerTag: 'root-live'),
  ),
  search(
    '搜索',
    Icon(CupertinoIcons.search),
    Icon(CupertinoIcons.search),
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
