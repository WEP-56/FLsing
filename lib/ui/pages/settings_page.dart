import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_messenger.dart';
import '../../core/theme/flsing_theme.dart';
import '../../data/services/app_settings.dart';
import '../../data/services/app_update_service.dart';
import '../../models/app_models.dart';
import '../../providers/app_state.dart';
import '../../providers/theme_provider.dart';
import '../widgets/app_surfaces.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _updatingRuleSets = false;
  final _updateService = AppUpdateService();
  late final Future<String> _appVersion = _updateService.currentVersion();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final themeProvider = context.watch<ThemeProvider>();
    final settings = AppSettings();
    final c = FlsingColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 660),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '设置',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const Spacer(),
                      CircleIconButton(
                        icon: Icons.close,
                        tooltip: '关闭',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: [
                        const _SectionHeader('外观'),
                        _SettingsGroup(
                          children: [
                            for (final option in const [
                              (ThemeMode.system, '跟随系统', '与系统深浅模式保持一致'),
                              (ThemeMode.light, '浅色', '暖调纸白'),
                              (ThemeMode.dark, '深色', '纯黑背景，OLED 友好'),
                            ])
                              _CheckTile(
                                label: option.$2,
                                subtitle: option.$3,
                                active: themeProvider.mode == option.$1,
                                onTap: () => themeProvider.setMode(option.$1),
                              ),
                          ],
                        ),
                        const _SectionHeader('代理方式'),
                        _SettingsGroup(
                          children: [
                            _ModeTile(
                              label: '规则',
                              subtitle: '国内直连，其余走代理',
                              mode: ProxyMode.rule,
                              current: state.mode,
                            ),
                            _ModeTile(
                              label: '全局',
                              subtitle: '全部流量走代理',
                              mode: ProxyMode.global,
                              current: state.mode,
                            ),
                            _ModeTile(
                              label: '直连',
                              subtitle: '全部流量不走代理',
                              mode: ProxyMode.direct,
                              current: state.mode,
                            ),
                          ],
                        ),
                        const _SectionHeader('测速'),
                        _SettingsGroup(
                          children: [
                            _LatencyMethodTile(
                              label: '智能',
                              subtitle: '未连接时直连测试，连接后由内核实测',
                              method: LatencyTestMethod.smart,
                              onChanged: () => setState(() {}),
                            ),
                            _LatencyMethodTile(
                              label: '直连',
                              subtitle: '设备直接握手节点端口，快速且无需连接',
                              method: LatencyTestMethod.direct,
                              onChanged: () => setState(() {}),
                            ),
                            _LatencyMethodTile(
                              label: '代理',
                              subtitle: '通过代理实测真实延迟，需要先连接',
                              method: LatencyTestMethod.proxy,
                              onChanged: () => setState(() {}),
                            ),
                            ListTile(
                              title: const Text('测试链接'),
                              subtitle: Text(
                                settings.testUrl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: c.text4, fontSize: 13),
                              ),
                              trailing: Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: c.text4,
                              ),
                              onTap: () => _editTestUrl(settings),
                            ),
                          ],
                        ),
                        const _SectionHeader('订阅'),
                        _SettingsGroup(
                          children: [
                            SwitchListTile.adaptive(
                              title: const Text('自动更新订阅'),
                              subtitle: Text(
                                '打开应用时刷新超过 ${settings.subscriptionStaleHours} 小时未更新的订阅',
                                style: TextStyle(color: c.text4, fontSize: 13),
                              ),
                              value: settings.autoUpdateSubscriptions,
                              onChanged: (value) => setState(
                                () => settings.autoUpdateSubscriptions = value,
                              ),
                            ),
                            ListTile(
                              enabled: settings.autoUpdateSubscriptions,
                              title: const Text('更新间隔'),
                              trailing: Text(
                                '${settings.subscriptionStaleHours} 小时',
                                style: TextStyle(color: c.text4),
                              ),
                              onTap: () => _pickStaleHours(settings),
                            ),
                          ],
                        ),
                        const _SectionHeader('规则库'),
                        _SettingsGroup(
                          children: [
                            ListTile(
                              title: const Text('更新规则库'),
                              subtitle: Text(
                                _ruleSetSubtitle(settings),
                                style: TextStyle(color: c.text4, fontSize: 13),
                              ),
                              trailing: _updatingRuleSets
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      Icons.refresh,
                                      size: 20,
                                      color: c.text3,
                                    ),
                              onTap: _updatingRuleSets
                                  ? null
                                  : () => _updateRuleSets(state),
                            ),
                          ],
                        ),
                        const _SectionHeader('连接'),
                        const _SettingsGroup(
                          children: [
                            _PlaceholderTile(title: '断线后自动重连'),
                            _PlaceholderTile(title: '开机自动连接'),
                          ],
                        ),
                        const _SectionHeader('高级'),
                        const _SettingsGroup(
                          children: [
                            _PlaceholderTile(title: '分应用代理'),
                            _PlaceholderTile(title: 'DNS 设置'),
                            _PlaceholderTile(title: '日志查看'),
                          ],
                        ),
                        const _SectionHeader('诊断'),
                        _SettingsGroup(
                          children: [
                            _InfoTile(
                              label: 'VPN 状态',
                              value: _phaseLabel(state.phase),
                            ),
                            _InfoTile(
                              label: 'sing-box 内核',
                              future: state.isInitialized
                                  ? state.singBoxVersion()
                                  : null,
                              value: state.isInitialized ? null : '未初始化',
                            ),
                          ],
                        ),
                        const _SectionHeader('关于'),
                        _SettingsGroup(
                          children: [
                            const _InfoTile(label: '应用', value: 'FLsing'),
                            _InfoTile(
                              label: '版本',
                              future: _appVersion,
                              onTap: _checkForUpdates,
                            ),
                            const _InfoTile(label: '许可', value: 'MIT'),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _ruleSetSubtitle(AppSettings settings) {
    final updatedAt = settings.ruleSetUpdatedAt;
    if (updatedAt == 0) return '当前为内置版本';
    final date = DateTime.fromMillisecondsSinceEpoch(updatedAt);
    return '上次更新：${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _updateRuleSets(AppState state) async {
    setState(() => _updatingRuleSets = true);
    await state.updateRuleSets();
    final message = state.takeFeedback();
    if (message != null) showAppMessage(message);
    if (mounted) setState(() => _updatingRuleSets = false);
  }

  Future<void> _checkForUpdates() => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(service: _updateService),
  );

  Future<void> _editTestUrl(AppSettings settings) async {
    final controller = TextEditingController(text: settings.testUrl);
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('测试链接'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: '延迟测试地址',
                  hintText: AppSettings.defaultTestUrl,
                ),
                validator: (value) {
                  final uri = Uri.tryParse(value?.trim() ?? '');
                  return uri != null &&
                          (uri.scheme == 'http' || uri.scheme == 'https')
                      ? null
                      : '请输入有效的 http(s) 链接';
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => controller.text = AppSettings.defaultTestUrl,
                  child: const Text('恢复默认'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved == true) {
      settings.testUrl = controller.text.trim();
      if (!mounted) return;
      await context.read<AppState>().applySettingsPatch();
      if (mounted) {
        setState(() {});
        showAppMessage('测试链接已保存，重新连接后生效');
      }
    }
  }

  Future<void> _pickStaleHours(AppSettings settings) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('订阅更新间隔'),
        children: [
          for (final hours in const [6, 12, 24, 48, 72])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, hours),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('$hours 小时'),
              ),
            ),
        ],
      ),
    );
    if (selected != null) {
      setState(() => settings.subscriptionStaleHours = selected);
    }
  }

  String _phaseLabel(ConnectionPhase phase) => switch (phase) {
    ConnectionPhase.connected => '已连接',
    ConnectionPhase.connecting => '连接中',
    ConnectionPhase.disconnecting => '断开中',
    ConnectionPhase.disconnected => '未连接',
  };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        title,
        style: TextStyle(color: FlsingColors.of(context).text4, fontSize: 13),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = FlsingColors.of(context);
    return Material(
      color: c.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.border1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({
    required this.label,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = FlsingColors.of(context);
    return ListTile(
      title: Text(label),
      subtitle: Text(subtitle, style: TextStyle(color: c.text4, fontSize: 13)),
      trailing: active ? Icon(Icons.check, color: c.accent) : null,
      onTap: active ? null : onTap,
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.label,
    required this.subtitle,
    required this.mode,
    required this.current,
  });

  final String label;
  final String subtitle;
  final ProxyMode mode;
  final ProxyMode current;

  @override
  Widget build(BuildContext context) {
    return _CheckTile(
      label: label,
      subtitle: subtitle,
      active: mode == current,
      onTap: () => context.read<AppState>().selectMode(mode),
    );
  }
}

class _LatencyMethodTile extends StatelessWidget {
  const _LatencyMethodTile({
    required this.label,
    required this.subtitle,
    required this.method,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final String method;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _CheckTile(
      label: label,
      subtitle: subtitle,
      active: AppSettings().latencyTestMethod == method,
      onTap: () {
        AppSettings().latencyTestMethod = method;
        onChanged();
      },
    );
  }
}

class _PlaceholderTile extends StatelessWidget {
  const _PlaceholderTile({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: false,
      title: Text(title),
      trailing: Text(
        '开发中',
        style: TextStyle(color: FlsingColors.of(context).text5, fontSize: 12),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, this.value, this.future, this.onTap});
  final String label;
  final String? value;
  final Future<String>? future;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(color: FlsingColors.of(context).text4);
    final valueWidget = future != null
        ? FutureBuilder<String>(
            future: future,
            builder: (_, snapshot) => Text(snapshot.data ?? '…', style: style),
          )
        : Text(value ?? '', style: style);
    return ListTile(
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          valueWidget,
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 18, color: style.color),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}

enum _UpdatePhase { checking, downloading, upToDate, installing, failed }

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.service});

  final AppUpdateService service;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  _UpdatePhase _phase = _UpdatePhase.checking;
  UpdateRelease? _release;
  String? _error;
  int _received = 0;
  int? _total;

  bool get _busy =>
      _phase == _UpdatePhase.checking || _phase == _UpdatePhase.downloading;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _phase = _UpdatePhase.checking;
      _error = null;
      _received = 0;
      _total = null;
    });
    try {
      final result = await widget.service.checkForUpdate();
      if (!mounted) return;
      _release = result.release;
      if (!result.hasUpdate) {
        setState(() => _phase = _UpdatePhase.upToDate);
        return;
      }

      setState(() => _phase = _UpdatePhase.downloading);
      final apk = await widget.service.downloadApk(
        result.release,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _received = received;
            _total = total;
          });
        },
      );
      if (!mounted) return;
      setState(() => _phase = _UpdatePhase.installing);
      await widget.service.installApk(apk);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _UpdatePhase.failed;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total != null && _total! > 0
        ? (_received / _total!).clamp(0.0, 1.0)
        : null;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(_title),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_message),
              if (_busy) ...[
                const SizedBox(height: 18),
                LinearProgressIndicator(
                  value: _phase == _UpdatePhase.downloading ? progress : null,
                ),
              ],
              if (_phase == _UpdatePhase.downloading) ...[
                const SizedBox(height: 8),
                Text(
                  _downloadProgress,
                  style: TextStyle(
                    color: FlsingColors.of(context).text4,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: _busy
            ? null
            : [
                if (_phase == _UpdatePhase.failed)
                  TextButton(onPressed: _run, child: const Text('重试')),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
              ],
      ),
    );
  }

  String get _title => switch (_phase) {
    _UpdatePhase.checking => '检查更新',
    _UpdatePhase.downloading => '正在下载更新',
    _UpdatePhase.upToDate => '已是最新版本',
    _UpdatePhase.installing => '准备安装',
    _UpdatePhase.failed => '更新失败',
  };

  String get _message => switch (_phase) {
    _UpdatePhase.checking => '正在从 GitHub 获取最新版本…',
    _UpdatePhase.downloading => '发现 v${_release?.version}，正在下载安装包。',
    _UpdatePhase.upToDate => '当前版本已经是 GitHub 上的最新版本。',
    _UpdatePhase.installing => '安装包已下载，已唤起系统安装器。',
    _UpdatePhase.failed => _error ?? '发生未知错误',
  };

  String get _downloadProgress {
    final received = (_received / 1024 / 1024).toStringAsFixed(1);
    if (_total == null || _total == 0) return '$received MB';
    final total = (_total! / 1024 / 1024).toStringAsFixed(1);
    return '$received / $total MB';
  }
}
