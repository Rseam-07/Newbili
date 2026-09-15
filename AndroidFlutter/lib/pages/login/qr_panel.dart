import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

/// The QR stays in one surface while its network and expiry states change.
class QrLoginPanel extends StatelessWidget {
  const QrLoginPanel({
    super.key,
    required this.state,
    required this.secondsLeft,
    required this.status,
    required this.onRefresh,
    required this.onSave,
    required this.onCopy,
    this.onOpen,
    this.qrKey,
    this.saving = false,
  });

  final LoadingState<({String authCode, String url})> state;
  final int secondsLeft;
  final String status;
  final VoidCallback onRefresh;
  final VoidCallback onSave;
  final VoidCallback onCopy;
  final VoidCallback? onOpen;
  final GlobalKey? qrKey;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ready = state.isSuccess && secondsLeft > 0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('扫码登录', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '使用 bilibili 官方 App 扫一扫',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    switch (state) {
                      Loading() => const SizedBox(
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(
                            semanticsLabel: '正在生成二维码',
                          ),
                        ),
                      ),
                      Error(:final errMsg) => HttpError(
                        isSliver: false,
                        safeArea: false,
                        errMsg: errMsg,
                        onReload: onRefresh,
                      ),
                      Success(:final response) => Stack(
                        alignment: Alignment.center,
                        children: [
                          ExcludeSemantics(
                            child: RepaintBoundary(
                              key: qrKey,
                              child: Container(
                                width: 200,
                                height: 200,
                                color: Colors.white,
                                padding: const EdgeInsets.all(12),
                                child: PrettyQrView.data(
                                  data: response.url,
                                  decoration: const PrettyQrDecoration(
                                    shape: PrettyQrSquaresSymbol(
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (!ready)
                            Positioned.fill(
                              child: ColoredBox(
                                color: colors.surface.withValues(alpha: 0.96),
                                child: Center(
                                  child: Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 64,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    },
                    if (status.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          status,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ],
                    if (ready) ...[
                      const SizedBox(height: 6),
                      Text(
                        '有效期 ${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (state is! Error)
                FilledButton.tonalIcon(
                  onPressed: state is Loading ? null : onRefresh,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(144, 48),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('刷新二维码'),
                ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: ready && !saving ? onSave : null,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.download_outlined),
                    label: Text(saving ? '正在保存' : '保存二维码'),
                  ),
                  if (onOpen != null)
                    TextButton.icon(
                      onPressed: ready ? onOpen : null,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('打开 bilibili'),
                    ),
                ],
              ),
              TextButton(
                onPressed: ready ? onCopy : null,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: const Text('复制登录链接'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
