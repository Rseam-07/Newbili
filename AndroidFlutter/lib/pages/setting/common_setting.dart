import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/newbili_form.dart';
import 'package:PiliPlus/models/common/setting_type.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:material_ui/material_ui.dart';

class CommonSetting extends StatefulWidget {
  const CommonSetting({
    super.key,
    required this.settingType,
    this.showAppBar = true,
  });

  final bool showAppBar;
  final SettingType settingType;

  @override
  State<CommonSetting> createState() => _CommonSettingState();
}

class _CommonSettingState extends State<CommonSetting> {
  late EdgeInsets padding;
  late List<SettingsModel> settings;

  void _initSetting() {
    settings = widget.settingType.settings;
  }

  @override
  void initState() {
    super.initState();
    _initSetting();
  }

  @override
  void didUpdateWidget(CommonSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settingType != oldWidget.settingType) {
      _initSetting();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    padding = MediaQuery.viewPaddingOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final showAppBar = widget.showAppBar;
    return SimpleScaffold(
      backgroundColor: NewbiliFormStyle.background(context),
      appBar: showAppBar ? AppBar(title: Text(widget.settingType.title)) : null,
      body: ListView.builder(
        key: ValueKey(widget.settingType),
        padding: EdgeInsets.only(
          left: (showAppBar ? padding.left : 0) + 16,
          right: (showAppBar ? padding.right : 0) + 16,
          top: 16,
          bottom: padding.bottom + 24,
        ),
        itemCount: settings.length,
        itemBuilder: (context, index) => Material(
          color: NewbiliFormStyle.card(context),
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(index == 0 ? 24 : 0),
            bottom: Radius.circular(index == settings.length - 1 ? 24 : 0),
          ),
          child: Column(
            children: [
              settings[index].widget,
              if (index != settings.length - 1)
                Divider(
                  height: .5,
                  thickness: .5,
                  indent: 56,
                  endIndent: 16,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
