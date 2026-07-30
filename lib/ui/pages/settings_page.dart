import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_messenger.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/app_settings.dart';
import '../../models/app_models.dart';
import '../../providers/app_state.dart';
import '../widgets/app_surfaces.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _updatingRuleSets = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = AppSettings();
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
                          ],
                        ),
                        const _SectionHeader('订阅'),
                        _SettingsGroup(
                          children: [
                            SwitchListTile.adaptive(
                              title: const Text('自动更新订阅'),
                              subtitle: Text(
                                '打开应用时刷新超过 ${settings.subscriptionStaleHours} 小时未更新的订阅',
                                style: const TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 13,
                                ),
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
                                style: const TextStyle(
                                  color: AppColors.secondary,
                                ),
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
                                style: const TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 13,
                                ),
                              ),
                              trailing: _updatingRuleSets
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh),
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
                            _PlaceholderTile(title: '自定义测速地址'),
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
                        const _SettingsGroup(
                          children: [
                            _InfoTile(label: '应用', value: 'FLsing'),
                            _InfoTile(label: '版本', value: '1.0.0'),
                            _InfoTile(label: '许可', value: 'MIT'),
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
        style: const TextStyle(color: AppColors.secondary, fontSize: 13),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
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
    final active = mode == current;
    return ListTile(
      title: Text(label),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.secondary, fontSize: 13),
      ),
      trailing: active
          ? const Icon(Icons.check, color: AppColors.success)
          : null,
      onTap: active
          ? null
          : () => context.read<AppState>().selectMode(mode),
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
    final active = AppSettings().latencyTestMethod == method;
    return ListTile(
      title: Text(label),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.secondary, fontSize: 13),
      ),
      trailing: active
          ? const Icon(Icons.check, color: AppColors.success)
          : null,
      onTap: active
          ? null
          : () {
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
      trailing: const Text(
        '开发中',
        style: TextStyle(color: AppColors.secondary, fontSize: 12),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, this.value, this.future});
  final String label;
  final String? value;
  final Future<String>? future;

  @override
  Widget build(BuildContext context) {
    final style = const TextStyle(color: AppColors.secondary);
    return ListTile(
      title: Text(label),
      trailing: future != null
          ? FutureBuilder<String>(
              future: future,
              builder: (_, snapshot) =>
                  Text(snapshot.data ?? '…', style: style),
            )
          : Text(value ?? '', style: style),
    );
  }
}
