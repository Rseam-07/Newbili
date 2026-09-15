import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/newbili_navigation_bar.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/newbili_form.dart';
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/login/controller.dart';
import 'package:PiliPlus/pages/login/view.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/setting/view.dart';
import 'package:PiliPlus/pages/updates/view.dart';
import 'package:PiliPlus/pages/setting/widgets/newbili_settings_links.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key, this.showBackBtn = false});
  final bool showBackBtn;
  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends CommonPageState<MinePage>
    with AutomaticKeepAliveClientMixin {
  final controller = Get.putOrFind(MineController.new);
  final _mainController = Get.find<MainController>();
  @override
  bool get wantKeepAlive => true;

  void _login([int tab = 1]) => Get.to(() => LoginPage(initialTab: tab));

  void _accountPage(String route) {
    if (controller.isLogin) {
      Get.toNamed(route);
    } else {
      _login();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ColoredBox(
      color: NewbiliFormStyle.background(context),
      child: refreshIndicator(
        onRefresh: controller.onRefresh,
        child: onBuild(
          ListView(
            padding: EdgeInsets.only(
              top: 4,
              bottom: NewbiliNavigationBar.bottomContentInsetOf(context),
            ),
            children: [
              NewbiliPageTitle(
                '我的',
                trailing: widget.showBackBtn ? const BackButton() : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Obx(
                      () => _mainController.accountService.isLogin.value
                          ? _accountProfile()
                          : NewbiliFormSection(
                              dividers: false,
                              children: [
                                NewbiliLoginPanel(onLogin: _login),
                              ],
                            ),
                    ),
                    Obx(
                      () => NewbiliFormSection(
                        title: '账号内容',
                        children: [
                          if (_mainController.accountService.isLogin.value)
                            NewbiliSettingsRow(
                              title: '账号消息',
                              icon: Icons.notifications_outlined,
                              onTap: () => _accountPage('/whisper'),
                            ),
                          NewbiliSettingsRow(
                            title: '观看记录',
                            icon: Icons.history_rounded,
                            onTap: () => _accountPage('/history'),
                          ),
                          NewbiliSettingsRow(
                            title: '账号收藏',
                            icon: Icons.star_border_rounded,
                            onTap: () => _accountPage('/fav'),
                          ),
                          NewbiliSettingsRow(
                            title: '稍后再看',
                            icon: Icons.bookmark_border_rounded,
                            onTap: () => _accountPage('/later'),
                          ),
                          NewbiliSettingsRow(
                            title: '我的订阅',
                            icon: Icons.subscriptions_outlined,
                            onTap: () => _accountPage('/subscription'),
                          ),
                          NewbiliSettingsRow(
                            title: '我的追更',
                            icon: Icons.bookmark_border_rounded,
                            onTap: () =>
                                Get.to(() => const TrackedSeriesPage()),
                          ),
                          NewbiliSettingsRow(
                            title: '离线缓存',
                            icon: Icons.download_outlined,
                            onTap: () => Get.toNamed('/download'),
                          ),
                        ],
                      ),
                    ),
                    NewbiliSettingsLinks(
                      onOpen: SettingPage.open,
                      onSearch: () => Get.toNamed('/settingsSearch'),
                    ),
                    NewbiliFormSection(
                      title: '账号与快捷操作',
                      children: [
                        NewbiliSettingsRow(
                          title: '切换账号',
                          icon: Icons.people_outline_rounded,
                          onTap: () =>
                              LoginPageController.switchAccountDialog(context),
                        ),
                        if (GStorage.reply != null)
                          NewbiliSettingsRow(
                            title: '评论记录',
                            icon: Icons.chat_bubble_outline_rounded,
                            onTap: () => Get.toNamed('/myReply'),
                          ),
                        Obx(
                          () => NewbiliSettingsRow(
                            title: '无痕模式',
                            icon: Icons.visibility_off_outlined,
                            value: MineController.anonymity.value
                                ? '已开启'
                                : '已关闭',
                            onTap: MineController.onChangeAnonymity,
                          ),
                        ),
                        Obx(
                          () => NewbiliSettingsRow(
                            title: '外观模式',
                            icon: Icons.dark_mode_outlined,
                            value: controller.themeType.value.label,
                            onTap: controller.onChangeTheme,
                          ),
                        ),
                        NewbiliSettingsRow(
                          title: '账号管理',
                          subtitle: '退出登录与完整设置',
                          icon: Icons.account_circle_outlined,
                          onTap: () => Get.toNamed('/setting'),
                        ),
                      ],
                    ),
                    NewbiliFormSection(
                      title: '关于',
                      children: [
                        NewbiliSettingsRow(
                          title: '关于 Newbili',
                          icon: Icons.info_outline_rounded,
                          onTap: () => Get.toNamed('/about'),
                        ),
                        NewbiliSettingsRow(
                          title: '项目地址',
                          icon: Icons.open_in_new_rounded,
                          value: 'Rseam-07/Newbili',
                          onTap: () => PageUtils.launchURL(
                            'https://github.com/Rseam-07/Newbili',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountProfile() {
    final scheme = Theme.of(context).colorScheme;
    final user = controller.userInfo.value;
    final level = user.levelInfo;
    final current = level?.currentExp;
    final total = level?.nextExp;
    return NewbiliFormSection(
      children: [
        InkWell(
          onTap: controller.onLogin,
          onLongPress: () => controller.onLogin(true),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              spacing: 12,
              children: [
                NetworkImgLayer(
                  src: user.face,
                  type: .avatar,
                  width: 56,
                  height: 56,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Row(
                        spacing: 8,
                        children: [
                          Flexible(
                            child: Text(
                              user.uname ?? '我的账号',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (level != null)
                            Text(
                              'LV${level.currentLevel}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        '硬币 ${user.money ?? '-'}  ·  经验 ${current ?? '-'} / ${total ?? '-'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (current != null && total != null && total > 0)
                        LinearProgressIndicator(
                          value: (current / total).clamp(0, 1),
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(2),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            for (final (title, count, route) in [
              ('动态', controller.userStat.value.dynamicCount, 'memberDynamics'),
              ('关注', controller.userStat.value.following, 'follow'),
              ('粉丝', controller.userStat.value.follower, 'fan'),
            ])
              Expanded(
                child: InkWell(
                  onTap: () => controller.push(route),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      spacing: 3,
                      children: [
                        Text(
                          '${count ?? '-'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The same login hierarchy as iOS, backed by the existing login controller.
class NewbiliLoginPanel extends StatelessWidget {
  const NewbiliLoginPanel({super.key, required this.onLogin});
  final ValueChanged<int> onLogin;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Column(
        spacing: 16,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 46,
            color: scheme.primary,
          ),
          Text(
            '想让 App 端首页推荐更接近官方，优先用短信验证码；想稳定登录可用扫码。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
          Column(
            spacing: 8,
            children: [
              for (final (tab, title, subtitle, badge, icon, tint) in [
                (
                  1,
                  'App 短信验证码登录',
                  '更适合 App 端推荐，可能触发风控',
                  '推荐',
                  Icons.chat_bubble_outline_rounded,
                  scheme.primary,
                ),
                (
                  2,
                  'App 扫码登录',
                  '更稳定；可配合网页端推荐',
                  '稳定',
                  Icons.qr_code_rounded,
                  const Color(0xFF008AFF),
                ),
                (
                  3,
                  '其他登录方式',
                  '密码与 Cookie 登录，保留原有方式',
                  '备用',
                  Icons.language_rounded,
                  scheme.onSurfaceVariant,
                ),
              ])
                Material(
                  color: tab == 1
                      ? tint.withValues(alpha: .08)
                      : NewbiliFormStyle.card(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: tab == 1
                          ? tint.withValues(alpha: .4)
                          : scheme.outlineVariant.withValues(alpha: .45),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onLogin(tab),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        spacing: 12,
                        children: [
                          Icon(icon, color: tint, size: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 3,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 3,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: tab == 1
                                            ? tint
                                            : tint.withValues(alpha: .12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        badge,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: tab == 1 ? Colors.white : tint,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: scheme.outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
