import 'package:PiliPlus/common/widgets/newbili_form.dart';
import 'package:PiliPlus/models/update_notifications.dart';
import 'package:PiliPlus/pages/updates/library.dart';
import 'package:PiliPlus/services/update_notification_service.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/permission_handler.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

export 'package:PiliPlus/pages/updates/library.dart' show TrackedSeriesPage;

class UpdateNotificationPage extends StatelessWidget {
  const UpdateNotificationPage({super.key});
  @override
  Widget build(BuildContext context) {
    final service = UpdateNotificationService.instance;
    return Scaffold(
      backgroundColor: NewbiliFormStyle.background(context),
      appBar: AppBar(title: const Text('更新通知与追更')),
      body: Obx(
        () => UpdateNotificationContent(
          state: service.state.value,
          busy: service.busy.value,
          error: service.error.value,
          onSelectLevel: (level) async {
            await service.syncAccount(level);
            await service.refresh(manual: true);
          },
          onRequestPermission: service.requestPermission,
          onSystemSettings: openAppSettings,
          onRefresh: () => service.refresh(manual: true),
          onLibrary: () => Get.to(() => const TrackedSeriesPage()),
          onVideo: (bvid, page) => PiliScheme.routePush(
            Uri.parse('https://www.bilibili.com/video/$bvid?p=$page'),
          ),
        ),
      ),
    );
  }
}

class UpdateNotificationContent extends StatelessWidget {
  const UpdateNotificationContent({
    super.key,
    required this.state,
    required this.busy,
    this.error,
    required this.onSelectLevel,
    required this.onRequestPermission,
    required this.onSystemSettings,
    required this.onRefresh,
    required this.onLibrary,
    required this.onVideo,
  });
  final UpdateNotificationState state;
  final bool busy;
  final String? error;
  final ValueChanged<UploaderNotificationLevel> onSelectLevel;
  final VoidCallback onRequestPermission,
      onSystemSettings,
      onRefresh,
      onLibrary;
  final void Function(String bvid, int page) onVideo;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.fromLTRB(
      16,
      16,
      16,
      MediaQuery.viewPaddingOf(context).bottom + 24,
    ),
    children: [
      NewbiliFormSection(
        title: '关注 UP',
        children: [
          for (final level in UploaderNotificationLevel.values)
            NewbiliSettingsRow(
              title: level.label,
              subtitle: level.explanation,
              icon: level == UploaderNotificationLevel.specialOnly
                  ? CupertinoIcons.star
                  : CupertinoIcons.bell,
              trailing: state.level == level
                  ? Icon(
                      CupertinoIcons.checkmark,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : const SizedBox.square(dimension: 24),
              onTap: () => onSelectLevel(level),
            ),
        ],
      ),
      if (!state.loggedIn && state.level != UploaderNotificationLevel.off)
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text('登录后才能读取关注动态与特别关注列表。'),
        ),
      NewbiliFormSection(
        title: '系统通知权限',
        children: [
          NewbiliSettingsRow(
            title: state.permission ? '系统通知已开启' : '开启系统通知',
            subtitle:
                '追更 ${state.seriesPermission ? '开启' : '关闭'} · 关注 UP ${state.upPermission ? '开启' : '关闭'}',
            icon: CupertinoIcons.bell,
            onTap: state.permission ? onSystemSettings : onRequestPermission,
          ),
          if (!state.permission)
            NewbiliSettingsRow(
              title: '前往系统设置',
              subtitle: '如果之前拒绝过通知，请在系统设置中开启',
              icon: CupertinoIcons.gear,
              onTap: onSystemSettings,
            ),
          NewbiliSettingsRow(
            title: busy
                ? '正在检查更新'
                : !state.hasTargets
                ? '添加追更后可检查'
                : '立即检查更新',
            subtitle: !state.permission ? '仅更新 App 内记录，不发送系统通知' : null,
            icon: CupertinoIcons.arrow_clockwise,
            trailing: busy
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: !busy && state.hasTargets ? onRefresh : null,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              error ?? state.status,
              style: TextStyle(
                color: error == null
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
      NewbiliFormSection(
        children: [
          NewbiliSettingsRow(
            title: '我的追更',
            value: '${state.tracks.length} 项',
            subtitle: '自标记番剧与分 P 更新',
            icon: CupertinoIcons.tv,
            onTap: onLibrary,
          ),
        ],
      ),
      if (state.recent.isNotEmpty)
        NewbiliFormSection(
          title: '最近更新',
          children: [
            for (final item in state.recent.take(10))
              NewbiliSettingsRow(
                title: item['title'] as String,
                subtitle: item['body'] as String,
                icon: CupertinoIcons.play_rectangle,
                onTap: () =>
                    onVideo(item['bvid'] as String, item['page'] as int),
              ),
          ],
        ),
      Text(
        updateDeliveryNotice,
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}
