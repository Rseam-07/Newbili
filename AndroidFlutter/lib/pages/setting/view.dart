import 'package:PiliPlus/common/widgets/newbili_form.dart';
import 'package:PiliPlus/pages/setting/widgets/newbili_settings_links.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/view_safe_area.dart';
import 'package:PiliPlus/http/login.dart';
import 'package:PiliPlus/models/common/setting_type.dart';
import 'package:PiliPlus/pages/about/view.dart';
import 'package:PiliPlus/pages/login/controller.dart';
import 'package:PiliPlus/pages/setting/common_setting.dart';
import 'package:PiliPlus/pages/setting/widgets/multi_select_dialog.dart';
import 'package:PiliPlus/pages/webdav/view.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/extension/size_ext.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  static Widget destination(SettingType type, {bool showAppBar = true}) =>
      switch (type) {
        SettingType.webdavSetting => WebDavSettingPage(showAppBar: showAppBar),
        SettingType.about => AboutPage(showAppBar: showAppBar),
        _ => CommonSetting(settingType: type, showAppBar: showAppBar),
      };

  static void open(SettingType type) => Get.to(() => destination(type));

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  SettingType _type = SettingType.styleSetting;
  final RxBool _noAccount = Accounts.account.isEmpty.obs;
  late bool _isPortrait;
  late ThemeData theme;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    theme = Theme.of(context);
    _isPortrait = MediaQuery.sizeOf(context).isPortrait;
  }

  @override
  Widget build(BuildContext context) => SimpleScaffold(
    appBar: AppBar(title: Text(_isPortrait ? '设置' : _type.title)),
    body: ColoredBox(
      color: NewbiliFormStyle.background(context),
      child: ViewSafeArea(
        child: _isPortrait
            ? _buildList()
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: _buildList()),
                  VerticalDivider(
                    width: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  Expanded(
                    flex: 6,
                    child: SettingPage.destination(_type, showAppBar: false),
                  ),
                ],
              ),
      ),
    ),
  );

  @override
  void dispose() {
    _noAccount.close();
    super.dispose();
  }

  void _toPage(SettingType type) {
    if (_isPortrait) {
      SettingPage.open(type);
    } else {
      setState(() => _type = type);
    }
  }

  Widget _buildList() => ListView(
    padding: EdgeInsets.fromLTRB(
      16,
      16,
      16,
      MediaQuery.viewPaddingOf(context).bottom + 24,
    ),
    children: [
      NewbiliSettingsLinks(
        onOpen: _toPage,
        onSearch: () => Get.toNamed('/settingsSearch'),
      ),
      Obx(
        () => NewbiliFormSection(
          title: '账号',
          children: [
            NewbiliSettingsRow(
              title: '切换账号',
              icon: CupertinoIcons.person_2,
              onTap: () => LoginPageController.switchAccountDialog(context),
            ),
            if (!_noAccount.value)
              NewbiliSettingsRow(
                title: '退出登录',
                icon: CupertinoIcons.square_arrow_right,
                onTap: () => _logoutDialog(context),
              ),
          ],
        ),
      ),
      NewbiliFormSection(
        children: [
          NewbiliSettingsRow(
            title: '关于 Newbili',
            icon: CupertinoIcons.info_circle,
            onTap: () => _toPage(SettingType.about),
          ),
        ],
      ),
    ],
  );

  Future<void> _removeAccounts(Set<LoginAccount> accounts) async {
    await Accounts.deleteAll(accounts);
    if (mounted) _noAccount.value = Accounts.account.isEmpty;
  }

  static Future<LoginAccount?> _logoutWrapper(LoginAccount account) async {
    try {
      final res = await LoginHttp.logout(account);
      return res.isSuccess ? account : null;
    } catch (e, s) {
      Utils.reportError(e, s);
      return null;
    }
  }

  Future<void> _logoutDialog(BuildContext context) async {
    final result = await showDialog<Set<LoginAccount>>(
      context: context,
      builder: (context) => MultiSelectDialog<LoginAccount>(
        title: '选择要登出的账号uid',
        initValues: const Iterable.empty(),
        values: {
          for (final i in Accounts.account.values) i: i.mid.toString(),
        },
      ),
    );
    if (!context.mounted || result == null || result.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('提示'),
          content: Text(
            "确认要退出以下账号登录吗\n\n${result.map((i) => i.mid).join('\n')}",
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: Text(
                '点错了',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () {
                _removeAccounts(result);
                Get.back();
              },
              child: Text(
                '仅登出',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
            TextButton(
              onPressed: () async {
                SmartDialog.showLoading();
                final res = await Future.wait(result.map(_logoutWrapper));
                SmartDialog.dismiss();
                final logoutAccounts = res.nonNulls.toSet();
                if (logoutAccounts.isEmpty) {
                  SmartDialog.showToast('所选账号均退出登录失败');
                } else {
                  _removeAccounts(logoutAccounts);
                  Get.back();
                  if (logoutAccounts.length != result.length) {
                    result.removeWhere(logoutAccounts.contains);
                    SmartDialog.showToast(
                      '账号 ${result.map((i) => i.mid).join(",")} 退出登录失败',
                    );
                  }
                }
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }
}
