import 'package:PiliPlus/common/widgets/newbili_form.dart';
import 'package:PiliPlus/models/common/setting_type.dart';
import 'package:PiliPlus/pages/updates/view.dart';
import 'package:get/get.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';

class NewbiliSettingsLinks extends StatelessWidget {
  const NewbiliSettingsLinks({
    super.key,
    required this.onOpen,
    required this.onSearch,
  });
  final ValueChanged<SettingType> onOpen;
  final VoidCallback onSearch;
  @override
  Widget build(BuildContext context) => NewbiliFormSection(
    title: '设置',
    children: [
      NewbiliSettingsRow(
        title: '搜索设置',
        subtitle: '按名称、用途或关键词查找设置与功能',
        icon: CupertinoIcons.search,
        onTap: onSearch,
      ),
      NewbiliSettingsRow(
        title: '更新通知与追更',
        subtitle: '特别关注 · UP 投稿 · 新增分 P 提醒',
        icon: CupertinoIcons.bell,
        onTap: () => Get.to(() => const UpdateNotificationPage()),
      ),
      for (final (type, title, subtitle, icon) in const [
        (
          SettingType.styleSetting,
          '样式设置',
          '外观 · 首页 · 导航 · 字体与显示',
          CupertinoIcons.paintbrush,
        ),
        (
          SettingType.recommendSetting,
          '推荐与搜索设置',
          '推荐来源 · 内容过滤 · 刷新行为',
          CupertinoIcons.sparkles,
        ),
        (
          SettingType.videoSetting,
          '视频与音频设置',
          '画质 · 编解码 · 缓冲 · 音频输出',
          CupertinoIcons.video_camera,
        ),
        (
          SettingType.playSetting,
          '播放与弹幕设置',
          '后台播放 · 手势 · 弹幕 · 字幕',
          CupertinoIcons.play_rectangle,
        ),
        (
          SettingType.privacySetting,
          '隐私设置',
          '账号权限 · 无痕模式 · 黑名单',
          CupertinoIcons.hand_raised,
        ),
        (
          SettingType.extraSetting,
          '搜索与其他设置',
          '搜索 · 互动 · AI 总结 · 更新检查',
          CupertinoIcons.slider_horizontal_3,
        ),
        (
          SettingType.webdavSetting,
          'WebDAV 同步',
          '备份与恢复应用设置',
          CupertinoIcons.cloud,
        ),
      ])
        NewbiliSettingsRow(
          title: title,
          subtitle: subtitle,
          icon: icon,
          onTap: () => onOpen(type),
        ),
    ],
  );
}
