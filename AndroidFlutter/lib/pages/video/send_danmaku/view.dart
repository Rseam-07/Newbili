import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/setting/slide_color_picker.dart';
import 'package:material_ui/material_ui.dart';

typedef DanmakuDraft = ({String text, int mode, int fontSize, Color color});
typedef DanmakuStyle = ({int mode, int fontSize, Color color});

/// The route owns a fixed video/time; the editor owns only the draft. Keeping
/// player/account lookups out of this widget also makes failure paths testable.
class SendDanmakuPanel extends StatefulWidget {
  const SendDanmakuPanel({
    super.key,
    this.initialValue,
    required this.progress,
    required this.onSend,
    this.onSave,
    this.onSent,
    this.dmConfig,
    this.onSaveDmConfig,
    this.isVip = false,
  });

  final String? initialValue;
  final int progress;
  final Future<LoadingState<void>> Function(DanmakuDraft draft) onSend;
  final ValueChanged<String>? onSave;
  final VoidCallback? onSent;
  final DanmakuStyle? dmConfig;
  final ValueChanged<DanmakuStyle>? onSaveDmConfig;
  final bool isVip;

  @override
  State<SendDanmakuPanel> createState() => _SendDanmakuPanelState();
}

class _SendDanmakuPanelState extends State<SendDanmakuPanel> {
  late final TextEditingController _text;
  late int _mode;
  late int _fontSize;
  late Color _color;
  bool _stylesVisible = false;
  bool _sending = false;
  bool _sent = false;
  String? _error;

  static final _colors = {
    Colors.white: '白色',
    const Color(0xFFFE0302): '红色',
    const Color(0xFFFF7204): '橙色',
    const Color(0xFFFFAA02): '浅橙色',
    const Color(0xFFFFD302): '金黄色',
    const Color(0xFFFFFF00): '黄色',
    const Color(0xFFA0EE00): '黄绿色',
    const Color(0xFF00CD00): '绿色',
    const Color(0xFF019899): '青色',
    const Color(0xFF4266BE): '蓝色',
    const Color(0xFF89D5FF): '浅蓝色',
    const Color(0xFFCC0273): '紫红色',
    const Color(0xFF222222): '黑色',
    const Color(0xFF9B9B9B): '灰色',
  };

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initialValue);
    _mode = widget.dmConfig?.mode ?? 1;
    _fontSize = widget.dmConfig?.fontSize ?? 25;
    _color = widget.dmConfig?.color ?? Colors.white;
    if (!widget.isVip && _color == Colors.transparent) _color = Colors.white;
  }

  @override
  void dispose() {
    widget.onSave?.call(_sent ? '' : _text.text);
    widget.onSaveDmConfig?.call((
      mode: _mode,
      fontSize: _fontSize,
      color: _color,
    ));
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || _sent || _text.text.trim().isEmpty) return;
    // Snapshot before the first await: the API and local echo must agree.
    final draft = (
      text: _text.text.trim(),
      mode: _mode,
      fontSize: _fontSize,
      color: _color,
    );
    setState(() {
      _sending = true;
      _error = null;
    });
    LoadingState<void> result;
    try {
      result = await widget.onSend(draft);
    } on Exception {
      result = const Error('无法确认发送结果。请先检查弹幕后再试，避免重复发送。');
    }
    if (!mounted) return;
    if (result is Success) {
      setState(() {
        _sending = false;
        _sent = true;
      });
      widget.onSave?.call('');
      widget.onSent?.call();
      if (ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    } else {
      setState(() {
        _sending = false;
        _error = result.toString().isEmpty ? '发送未成功，请稍后再试。' : result.toString();
      });
    }
  }

  String get _timestamp {
    final seconds = widget.progress ~/ 1000;
    final minutes = seconds ~/ 60;
    return '${minutes.toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PopScope(
      canPop: !_sending,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 560,
              child: Material(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '发弹幕',
                                    style: theme.textTheme.titleLarge,
                                  ),
                                ),
                                IconButton(
                                  tooltip: '关闭并保留草稿',
                                  constraints: const BoxConstraints.tightFor(
                                    width: 48,
                                    height: 48,
                                  ),
                                  onPressed: _sending
                                      ? null
                                      : () => Navigator.of(context).maybePop(),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                            Text(
                              '发送到 $_timestamp · 关闭后保留草稿',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _text,
                              autofocus: true,
                              readOnly: _sending || _sent,
                              minLines: 1,
                              maxLines: 3,
                              maxLength: 100,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: '弹幕内容',
                                floatingLabelStyle: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                                hintText: '和正在看的人聊聊这一刻',
                                border: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(16),
                                  ),
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  '$_error\n草稿已保留。',
                                  style: TextStyle(color: scheme.error),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (_stylesVisible) ...[
                              const Divider(height: 24),
                              Text('字号', style: theme.textTheme.titleSmall),
                              Wrap(
                                spacing: 8,
                                children: [
                                  _choice(
                                    '小',
                                    _fontSize == 18,
                                    () => _fontSize = 18,
                                  ),
                                  _choice(
                                    '标准',
                                    _fontSize == 25,
                                    () => _fontSize = 25,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('位置', style: theme.textTheme.titleSmall),
                              Wrap(
                                spacing: 8,
                                children: [
                                  _choice('滚动', _mode == 1, () => _mode = 1),
                                  _choice('顶部', _mode == 5, () => _mode = 5),
                                  _choice('底部', _mode == 4, () => _mode = 4),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('颜色', style: theme.textTheme.titleSmall),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final entry in _colors.entries)
                                    _colorButton(entry.key, entry.value),
                                  if (widget.isVip)
                                    _colorButton(Colors.transparent, '会员渐变色'),
                                  if (!_colors.containsKey(_color) &&
                                      _color != Colors.transparent)
                                    _colorButton(_color, '自定义颜色'),
                                  IconButton.filledTonal(
                                    tooltip: '自定义颜色',
                                    constraints: const BoxConstraints.tightFor(
                                      width: 48,
                                      height: 48,
                                    ),
                                    onPressed: _sending || _sent
                                        ? null
                                        : _showColorPicker,
                                    icon: const Icon(Icons.colorize_rounded),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: _buildActions(scheme),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(ColorScheme scheme) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 8,
    children: [
      TextButton.icon(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: scheme.onSurface,
        ),
        onPressed: _sending || _sent
            ? null
            : () {
                FocusScope.of(context).unfocus();
                setState(() => _stylesVisible = !_stylesVisible);
              },
        icon: Icon(
          _stylesVisible ? Icons.keyboard_arrow_up : Icons.text_format_rounded,
        ),
        label: Text(_stylesVisible ? '收起样式' : '弹幕样式'),
      ),
      ValueListenableBuilder(
        valueListenable: _text,
        builder: (context, value, _) => FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(104, 48),
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
          ),
          onPressed: _sending || _sent || value.text.trim().isEmpty
              ? null
              : _submit,
          icon: _sending
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              : Icon(
                  _sent ? Icons.check_rounded : Icons.send_rounded,
                  size: 20,
                ),
          label: Text(
            _sending
                ? '发送中'
                : _sent
                ? '已发送'
                : '发送',
          ),
        ),
      ),
    ],
  );

  Widget _choice(String label, bool selected, VoidCallback change) =>
      ChoiceChip(
        label: Text(label),
        selected: selected,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        onSelected: _sending || _sent ? null : (_) => setState(change),
      );

  Widget _colorButton(Color color, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: _color == color,
      label: label,
      enabled: !_sending && !_sent,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _sending || _sent
              ? null
              : () => setState(() => _color = color),
          child: Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _color == color ? scheme.primary : scheme.outlineVariant,
                width: 2,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                gradient: color == Colors.transparent
                    ? const LinearGradient(
                        colors: [Color(0xFFDD94DA), Color(0xFF72B2EA)],
                      )
                    : null,
              ),
              child: _color == color
                  ? Icon(
                      Icons.check_rounded,
                      size: 22,
                      color:
                          color.computeLuminance() > .4 ||
                              color == Colors.transparent
                          ? Colors.black
                          : Colors.white,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showColorPicker() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      clipBehavior: Clip.hardEdge,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      title: const Text('自定义弹幕颜色'),
      content: SlideColorPicker(
        color: _color,
        onChanged: (color) {
          if (mounted && color != null) setState(() => _color = color);
        },
      ),
    ),
  );
}
