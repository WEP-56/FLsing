import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_messenger.dart';
import '../../core/theme/flsing_theme.dart';
import '../../data/services/app_settings.dart';
import '../../data/services/app_update_service.dart';
import '../../data/services/configuration_file_importer.dart';
import '../../data/services/device_service.dart';
import '../../data/services/per_app_proxy_service.dart';
import '../../data/services/platform_settings_service.dart';
import '../../data/services/settings_backup_service.dart';
import '../../models/app_models.dart';
import '../../providers/app_state.dart';
import '../../providers/theme_provider.dart';
import 'advanced_network_page.dart';
import '../widgets/app_surfaces.dart';
import '../widgets/flsing_sheets.dart' show confirmDestructive;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                  const SizedBox(height: 18),
                  const Expanded(child: _SettingsHome()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsHome extends StatelessWidget {
  const _SettingsHome();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = AppSettings();
    return ListView(
      children: [
        _CategoryTile(
          icon: Icons.link_rounded,
          title: '连接',
          subtitle: state.isConnected
              ? '已连接'
              : '自动重连 ${settings.autoReconnect ? '已开启' : '已关闭'}',
          section: _SettingsSection.connection,
        ),
        _CategoryTile(
          icon: Icons.route_outlined,
          title: '代理方式',
          subtitle: _modeName(state.mode),
          section: _SettingsSection.proxy,
        ),
        _CategoryTile(
          icon: Icons.layers_outlined,
          title: '订阅与节点',
          subtitle: settings.autoUpdateSubscriptions ? '自动更新已开启' : '自动更新已关闭',
          section: _SettingsSection.subscription,
        ),
        _CategoryTile(
          icon: Icons.palette_outlined,
          title: '外观',
          subtitle: _themeName(context.watch<ThemeProvider>().mode),
          section: _SettingsSection.appearance,
        ),
        const _CategoryTile(
          icon: Icons.battery_charging_full_outlined,
          title: '后台与启动',
          subtitle: '电池优化',
          section: _SettingsSection.background,
        ),
        const _CategoryTile(
          icon: Icons.privacy_tip_outlined,
          title: '隐私与数据',
          subtitle: '日志与本地数据',
          section: _SettingsSection.privacy,
        ),
        const _CategoryTile(
          icon: Icons.tune_rounded,
          title: '高级设置',
          subtitle: '测速与测试链接',
          section: _SettingsSection.advanced,
        ),
        _CategoryTile(
          icon: Icons.hub_outlined,
          title: '高级网络',
          subtitle: 'DNS 与 TUN 参数',
          pageBuilder: (_) => const AdvancedNetworkPage(),
        ),
        _CategoryTile(
          icon: Icons.monitor_heart_outlined,
          title: '诊断',
          subtitle: state.lastError == null ? '连接状态与日志' : '发现最近错误',
          section: _SettingsSection.diagnostics,
        ),
        const _CategoryTile(
          icon: Icons.info_outline_rounded,
          title: '关于',
          subtitle: '版本与开源许可',
          section: _SettingsSection.about,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.section,
    this.pageBuilder,
  }) : assert(section != null || pageBuilder != null);

  final IconData icon;
  final String title;
  final String subtitle;
  final _SettingsSection? section;
  final WidgetBuilder? pageBuilder;

  @override
  Widget build(BuildContext context) {
    final c = FlsingColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: c.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: c.border1),
        ),
        child: ListTile(
          minVerticalPadding: 12,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.surface3,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: c.text2),
          ),
          title: Text(title),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: c.text4, fontSize: 13),
          ),
          trailing: Icon(Icons.chevron_right, color: c.text4),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder:
                  pageBuilder ?? (_) => _SettingsDetailPage(section: section!),
            ),
          ),
        ),
      ),
    );
  }
}

enum _SettingsSection {
  connection,
  proxy,
  subscription,
  appearance,
  background,
  privacy,
  advanced,
  diagnostics,
  about,
}

class _SettingsDetailPage extends StatefulWidget {
  const _SettingsDetailPage({required this.section});

  final _SettingsSection section;

  @override
  State<_SettingsDetailPage> createState() => _SettingsDetailPageState();
}

class _SettingsDetailPageState extends State<_SettingsDetailPage> {
  final _deviceService = DeviceService();
  final _updateService = AppUpdateService();
  final _perAppProxyService = PerAppProxyService();
  final _platformSettings = PlatformSettingsService();
  final _settingsBackupService = SettingsBackupService();
  bool _updatingRuleSets = false;
  bool? _batteryOptimizationIgnored;

  @override
  void initState() {
    super.initState();
    if (widget.section == _SettingsSection.background) {
      _loadBatteryStatus();
    }
  }

  Future<void> _loadBatteryStatus() async {
    final value = await _deviceService.isIgnoringBatteryOptimizations();
    if (mounted) setState(() => _batteryOptimizationIgnored = value);
  }

  @override
  Widget build(BuildContext context) {
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
                      CircleIconButton(
                        icon: Icons.arrow_back,
                        tooltip: '返回',
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _content(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _title => switch (widget.section) {
    _SettingsSection.connection => '连接',
    _SettingsSection.proxy => '代理方式',
    _SettingsSection.subscription => '订阅与节点',
    _SettingsSection.appearance => '外观',
    _SettingsSection.background => '后台与启动',
    _SettingsSection.privacy => '隐私与数据',
    _SettingsSection.advanced => '高级设置',
    _SettingsSection.diagnostics => '诊断',
    _SettingsSection.about => '关于',
  };

  Widget _content(BuildContext context) => switch (widget.section) {
    _SettingsSection.connection => _connection(context),
    _SettingsSection.proxy => _proxy(context),
    _SettingsSection.subscription => _subscription(context),
    _SettingsSection.appearance => _appearance(context),
    _SettingsSection.background => _background(context),
    _SettingsSection.privacy => _privacy(context),
    _SettingsSection.advanced => _advanced(context),
    _SettingsSection.diagnostics => _diagnostics(context),
    _SettingsSection.about => _about(context),
  };

  Widget _connection(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = AppSettings();
    return ListView(
      children: [
        _SectionLabel('连接可靠性'),
        _SettingsGroup(
          children: [
            SwitchListTile.adaptive(
              title: const Text('断线后自动重连'),
              subtitle: Text('服务异常停止后自动恢复，手动断开不会重连', style: _subtle(context)),
              value: settings.autoReconnect,
              onChanged: state.setAutoReconnect,
            ),
            _InfoTile(label: '当前状态', value: _phaseName(state.phase)),
            if (state.reconnectPending)
              const _InfoTile(label: '重连任务', value: '等待下一次尝试'),
          ],
        ),
      ],
    );
  }

  Widget _proxy(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      children: [
        _SectionLabel('代理模式'),
        _SettingsGroup(
          children: [
            for (final item in const [
              (ProxyMode.rule, '规则', '国内直连，其余流量走代理'),
              (ProxyMode.global, '全局', '全部流量走代理'),
              (ProxyMode.direct, '直连', '全部流量不走代理'),
            ])
              _ChoiceTile(
                label: item.$2,
                subtitle: item.$3,
                active: state.mode == item.$1,
                onTap: () => context.read<AppState>().selectMode(item.$1),
              ),
          ],
        ),
        _SectionLabel('Android VPN'),
        _SettingsGroup(
          children: [
            SwitchListTile.adaptive(
              title: const Text('系统 HTTP 代理'),
              subtitle: Text(
                '让支持系统代理的应用发现本地 HTTP 代理，变更会重载 VPN',
                style: _subtle(context),
              ),
              value: _platformSettings.systemHttpProxyEnabled,
              onChanged: _setSystemHttpProxy,
            ),
            ListTile(
              title: const Text('分应用代理'),
              subtitle: Text(_perAppProxySummary(), style: _subtle(context)),
              trailing: Icon(
                Icons.chevron_right,
                color: FlsingColors.of(context).text4,
              ),
              onTap: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const _PerAppProxyPage(),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _subscription(BuildContext context) {
    final settings = AppSettings();
    return ListView(
      children: [
        _SectionLabel('更新策略'),
        _SettingsGroup(
          children: [
            SwitchListTile.adaptive(
              title: const Text('自动更新订阅'),
              subtitle: Text(
                '打开应用时更新超过 ${settings.subscriptionStaleHours} 小时未刷新的订阅',
                style: _subtle(context),
              ),
              value: settings.autoUpdateSubscriptions,
              onChanged: (value) =>
                  setState(() => settings.autoUpdateSubscriptions = value),
            ),
            ListTile(
              enabled: settings.autoUpdateSubscriptions,
              title: const Text('更新间隔'),
              trailing: _TrailingValue('${settings.subscriptionStaleHours} 小时'),
              onTap: () => _pickStaleHours(settings),
            ),
            SwitchListTile.adaptive(
              title: const Text('仅在 Wi-Fi 下更新'),
              subtitle: Text('仅影响打开应用时的自动更新，手动更新不受限制', style: _subtle(context)),
              value: settings.subscriptionUpdatesOnWifiOnly,
              onChanged: settings.autoUpdateSubscriptions
                  ? (value) => setState(
                      () => settings.subscriptionUpdatesOnWifiOnly = value,
                    )
                  : null,
            ),
            ListTile(
              enabled: settings.autoUpdateSubscriptions,
              title: const Text('失败重试'),
              subtitle: Text('自动更新失败后的额外尝试次数', style: _subtle(context)),
              trailing: _TrailingValue(
                '${settings.subscriptionUpdateRetryCount} 次',
              ),
              onTap: () => _pickRetryCount(settings),
            ),
            if (settings.lastSubscriptionUpdateError != null)
              _InfoTile(
                label: '最近自动更新',
                value: settings.lastSubscriptionUpdateError!,
              ),
          ],
        ),
        _SectionLabel('规则库'),
        _SettingsGroup(
          children: [
            ListTile(
              title: const Text('更新规则库'),
              subtitle: Text(
                _ruleSetSubtitle(settings),
                style: _subtle(context),
              ),
              trailing: _updatingRuleSets
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.refresh, color: FlsingColors.of(context).text3),
              onTap: _updatingRuleSets ? null : _updateRuleSets,
            ),
          ],
        ),
      ],
    );
  }

  Widget _appearance(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return ListView(
      children: [
        _SectionLabel('主题'),
        _SettingsGroup(
          children: [
            for (final item in const [
              (ThemeMode.system, '跟随系统', '与系统深浅模式保持一致'),
              (ThemeMode.light, '浅色', '暖调纸白'),
              (ThemeMode.dark, '深色', '纯黑背景，OLED 友好'),
            ])
              _ChoiceTile(
                label: item.$2,
                subtitle: item.$3,
                active: theme.mode == item.$1,
                onTap: () => theme.setMode(item.$1),
              ),
          ],
        ),
      ],
    );
  }

  Widget _background(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = AppSettings();
    return ListView(
      children: [
        _SectionLabel('启动'),
        _SettingsGroup(
          children: [
            SwitchListTile.adaptive(
              title: const Text('启动后自动连接'),
              subtitle: Text('应用和活动订阅就绪后，恢复上次由你保持的连接', style: _subtle(context)),
              value: settings.autoConnectOnLaunch,
              onChanged: state.setAutoConnectOnLaunch,
            ),
          ],
        ),
        _SectionLabel('电池优化'),
        _SettingsGroup(
          children: [
            ListTile(
              title: const Text('忽略电池优化'),
              subtitle: Text(
                _batteryOptimizationIgnored == null
                    ? '正在读取系统状态'
                    : _batteryOptimizationIgnored!
                    ? '已允许后台运行'
                    : '系统可能在后台限制连接',
                style: _subtle(context),
              ),
              trailing: Icon(
                _batteryOptimizationIgnored == true
                    ? Icons.check_circle_outline
                    : Icons.open_in_new,
                color: FlsingColors.of(context).text3,
              ),
              onTap: () async {
                await _deviceService.requestIgnoreBatteryOptimizations();
                await _loadBatteryStatus();
              },
            ),
          ],
        ),
        _SectionLabel('通知'),
        _SettingsGroup(
          children: [
            SwitchListTile.adaptive(
              title: const Text('通知栏实时速率'),
              subtitle: Text(
                '显示 VPN 上下行实时速率，变更会重载 VPN',
                style: _subtle(context),
              ),
              value: _platformSettings.dynamicNotificationEnabled,
              onChanged: _setDynamicNotification,
            ),
          ],
        ),
      ],
    );
  }

  Widget _privacy(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      children: [
        _SectionLabel('本地数据'),
        _SettingsGroup(
          children: [
            _InfoTile(label: '内存日志', value: '${state.logs.length} 条'),
            ListTile(
              title: const Text('清空内存日志'),
              subtitle: Text('不会影响订阅、节点和连接配置', style: _subtle(context)),
              trailing: Icon(
                Icons.delete_outline,
                color: FlsingColors.of(context).text3,
              ),
              onTap: state.logs.isEmpty
                  ? null
                  : () {
                      state.clearLogs();
                      showAppMessage('日志已清空');
                    },
            ),
          ],
        ),
        _SectionLabel('设置备份'),
        _SettingsGroup(
          children: [
            ListTile(
              title: const Text('导出设置'),
              subtitle: Text('不包含订阅链接、节点配置或安装包缓存', style: _subtle(context)),
              trailing: Icon(
                Icons.ios_share_outlined,
                color: FlsingColors.of(context).text3,
              ),
              onTap: _exportSettings,
            ),
            ListTile(
              title: const Text('恢复设置'),
              subtitle: Text('恢复后会重载当前 VPN', style: _subtle(context)),
              trailing: Icon(
                Icons.file_open_outlined,
                color: FlsingColors.of(context).text3,
              ),
              onTap: _restoreSettings,
            ),
          ],
        ),
      ],
    );
  }

  Widget _advanced(BuildContext context) {
    final settings = AppSettings();
    return ListView(
      children: [
        _SectionLabel('测速'),
        _SettingsGroup(
          children: [
            for (final item in const [
              (LatencyTestMethod.smart, '智能', '未连接时直连，连接后由内核实测'),
              (LatencyTestMethod.direct, '直连', '设备直接 TCP 握手节点端口'),
              (LatencyTestMethod.proxy, '内核', '通过代理进行真实链路测速，需要先连接'),
            ])
              _ChoiceTile(
                label: item.$2,
                subtitle: item.$3,
                active: settings.latencyTestMethod == item.$1,
                onTap: () =>
                    setState(() => settings.latencyTestMethod = item.$1),
              ),
            ListTile(
              title: const Text('测试链接'),
              subtitle: Text(
                settings.testUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _subtle(context),
              ),
              trailing: Icon(
                Icons.edit_outlined,
                color: FlsingColors.of(context).text3,
              ),
              onTap: () => _editTestUrl(settings),
            ),
          ],
        ),
      ],
    );
  }

  Widget _diagnostics(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      children: [
        _SectionLabel('连接快照'),
        _SettingsGroup(
          children: [
            _InfoTile(label: 'VPN 状态', value: _phaseName(state.phase)),
            _InfoTile(label: '出口 IP', value: state.ipInfo?.ip ?? '未获取'),
            _InfoTile(label: '最近错误', value: state.lastError ?? '无'),
            ListTile(
              title: const Text('复制诊断信息'),
              subtitle: Text('不包含订阅链接和节点凭据', style: _subtle(context)),
              trailing: Icon(
                Icons.copy_outlined,
                color: FlsingColors.of(context).text3,
              ),
              onTap: () => _copyDiagnostics(share: false),
            ),
            ListTile(
              title: const Text('分享诊断信息'),
              subtitle: Text('以文本文件交给系统分享面板', style: _subtle(context)),
              trailing: Icon(
                Icons.ios_share_outlined,
                color: FlsingColors.of(context).text3,
              ),
              onTap: () => _copyDiagnostics(share: true),
            ),
          ],
        ),
        _SectionLabel('日志'),
        _SettingsGroup(
          children: [
            ListTile(
              title: const Text('查看日志'),
              subtitle: Text(
                '${state.logs.length} 条，仅保留最近 600 条',
                style: _subtle(context),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: FlsingColors.of(context).text4,
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const _LogsPage()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _about(BuildContext context) => ListView(
    children: [
      const SizedBox(height: 18),
      Center(
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: FlsingColors.of(context).surface2,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: Image.asset('assets/logo.png', fit: BoxFit.contain),
        ),
      ),
      const SizedBox(height: 12),
      Center(
        child: Text('FLsing', style: Theme.of(context).textTheme.titleLarge),
      ),
      const SizedBox(height: 24),
      _SettingsGroup(
        children: [
          _InfoTile(label: '应用', value: 'FLsing'),
          _InfoTile(
            label: '版本',
            future: _updateService.currentVersion(),
            onTap: _checkForUpdates,
          ),
          ListTile(
            title: const Text('开源许可'),
            trailing: _TrailingValue('MIT'),
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(
                title: Text('MIT License'),
                content: Text('FLsing 以 MIT License 开源发布。'),
              ),
            ),
          ),
        ],
      ),
    ],
  );

  TextStyle _subtle(BuildContext context) =>
      TextStyle(color: FlsingColors.of(context).text4, fontSize: 13);

  String _ruleSetSubtitle(AppSettings settings) {
    final updatedAt = settings.ruleSetUpdatedAt;
    if (updatedAt == 0) return '当前为内置版本';
    final date = DateTime.fromMillisecondsSinceEpoch(updatedAt);
    return '上次更新：${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _updateRuleSets() async {
    setState(() => _updatingRuleSets = true);
    final state = context.read<AppState>();
    await state.updateRuleSets();
    final message = state.takeFeedback();
    if (message != null) showAppMessage(message);
    if (mounted) setState(() => _updatingRuleSets = false);
  }

  String _perAppProxySummary() {
    final mode = _perAppProxyService.mode;
    final count = _perAppProxyService.selectedPackages.length;
    return switch (mode) {
      PerAppProxyMode.disabled => '未启用',
      PerAppProxyMode.include => '仅代理 $count 个应用',
      PerAppProxyMode.exclude => '$count 个应用不走代理',
    };
  }

  Future<void> _setSystemHttpProxy(bool value) async {
    final state = context.read<AppState>();
    await state.setSystemHttpProxyEnabled(value);
    final message = state.takeFeedback();
    if (message != null) showAppMessage(message);
    if (mounted) setState(() {});
  }

  Future<void> _setDynamicNotification(bool value) async {
    final state = context.read<AppState>();
    await state.setDynamicNotificationEnabled(value);
    final message = state.takeFeedback();
    if (message != null) showAppMessage(message);
    if (mounted) setState(() {});
  }

  Future<void> _checkForUpdates() => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(service: _updateService),
  );

  Future<void> _copyDiagnostics({required bool share}) async {
    final report = await context.read<AppState>().buildDiagnosticReport();
    if (share) {
      await _deviceService.shareTextFile(
        filename: 'flsing-diagnostic.txt',
        content: report,
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: report));
    showAppMessage('诊断信息已复制');
  }

  Future<void> _exportSettings() async {
    await _deviceService.shareTextFile(
      filename: 'flsing-settings-backup.json',
      content: _settingsBackupService.export(),
      title: '导出 FLsing 设置',
    );
  }

  Future<void> _restoreSettings() async {
    final appState = context.read<AppState>();
    final themeProvider = context.read<ThemeProvider>();
    final path = await ConfigurationFileImporter().pickFile();
    if (!mounted || path == null) return;
    final confirmed = await confirmDestructive(
      context,
      title: '恢复设置',
      message: '将覆盖当前应用偏好、分应用代理和平台开关，订阅与节点不会变化。',
      confirmLabel: '恢复',
    );
    if (!mounted || !confirmed) return;
    try {
      final result = await _settingsBackupService.restore(File(path));
      themeProvider.setMode(_themeModeFromSetting(result.themeMode));
      final advancedNetwork = result.advancedNetworkSettings;
      if (advancedNetwork != null) {
        final saved = await appState.saveAdvancedNetworkSettings(
          advancedNetwork,
        );
        if (!saved) {
          throw StateError(appState.takeFeedback() ?? '高级网络设置校验失败');
        }
      } else {
        await appState.applySettingsPatch();
        await appState.reloadVpnForSettings();
      }
      if (mounted) showAppMessage('设置已恢复');
    } catch (error) {
      if (mounted) showAppMessage('恢复设置失败：$error');
    }
  }

  Future<void> _editTestUrl(AppSettings settings) async {
    final controller = TextEditingController(text: settings.testUrl);
    final formKey = GlobalKey<FormState>();
    final appState = context.read<AppState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('测试链接'),
        content: Form(
          key: formKey,
          child: TextFormField(
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
    if (saved != true) return;
    settings.testUrl = controller.text.trim();
    await appState.applySettingsPatch();
    if (mounted) {
      setState(() {});
      showAppMessage('测试链接已保存，重新连接后生效');
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

  Future<void> _pickRetryCount(AppSettings settings) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('自动更新失败重试'),
        children: [
          for (final count in const [0, 1, 2, 3])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, count),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(count == 0 ? '不重试' : '$count 次'),
              ),
            ),
        ],
      ),
    );
    if (selected != null) {
      setState(() => settings.subscriptionUpdateRetryCount = selected);
    }
  }
}

class _PerAppProxyPage extends StatefulWidget {
  const _PerAppProxyPage();

  @override
  State<_PerAppProxyPage> createState() => _PerAppProxyPageState();
}

class _PerAppProxyPageState extends State<_PerAppProxyPage> {
  final _service = PerAppProxyService();
  late PerAppProxyMode _mode = _service.mode;
  late List<String> _selected = _service.selectedPackages;

  @override
  Widget build(BuildContext context) {
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
                      CircleIconButton(
                        icon: Icons.arrow_back,
                        tooltip: '返回',
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '分应用代理',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        const _SectionLabel('模式'),
                        _SettingsGroup(
                          children: [
                            _ChoiceTile(
                              label: '关闭',
                              subtitle: '所有应用遵循 VPN 默认行为',
                              active: _mode == PerAppProxyMode.disabled,
                              onTap: () => _setMode(PerAppProxyMode.disabled),
                            ),
                            _ChoiceTile(
                              label: '仅代理已选应用',
                              subtitle: '未选中的应用不进入 VPN',
                              active: _mode == PerAppProxyMode.include,
                              onTap: () => _setMode(PerAppProxyMode.include),
                            ),
                            _ChoiceTile(
                              label: '排除已选应用',
                              subtitle: '已选中的应用不走 VPN',
                              active: _mode == PerAppProxyMode.exclude,
                              onTap: () => _setMode(PerAppProxyMode.exclude),
                            ),
                          ],
                        ),
                        if (_mode != PerAppProxyMode.disabled) ...[
                          const _SectionLabel('应用'),
                          _SettingsGroup(
                            children: [
                              ListTile(
                                title: const Text('选择应用'),
                                subtitle: Text(
                                  _selected.isEmpty
                                      ? '尚未选择应用'
                                      : '已选择 ${_selected.length} 个应用',
                                  style: TextStyle(
                                    color: FlsingColors.of(context).text4,
                                    fontSize: 13,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.chevron_right,
                                  color: FlsingColors.of(context).text4,
                                ),
                                onTap: _selectApplications,
                              ),
                            ],
                          ),
                        ],
                        const Padding(
                          padding: EdgeInsets.fromLTRB(4, 14, 4, 0),
                          child: Text(
                            '保存后会重载 VPN，连接会短暂中断。',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
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

  Future<void> _setMode(PerAppProxyMode mode) async {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _selected = _service.packagesFor(mode);
    });
    if (mode != PerAppProxyMode.disabled && _selected.isEmpty) return;
    _service.save(mode: mode, packages: _selected);
    await _reloadVpn();
  }

  Future<void> _selectApplications() async {
    final result = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute<List<String>>(
        builder: (_) =>
            _ApplicationSelectorPage(mode: _mode, selectedPackages: _selected),
      ),
    );
    if (result == null) return;
    setState(() => _selected = result);
    _service.save(mode: _mode, packages: result);
    await _reloadVpn();
  }

  Future<void> _reloadVpn() async {
    final state = context.read<AppState>();
    await state.reloadVpnForSettings();
    final message = state.takeFeedback();
    if (message != null) showAppMessage(message);
  }
}

class _ApplicationSelectorPage extends StatefulWidget {
  const _ApplicationSelectorPage({
    required this.mode,
    required this.selectedPackages,
  });

  final PerAppProxyMode mode;
  final List<String> selectedPackages;

  @override
  State<_ApplicationSelectorPage> createState() =>
      _ApplicationSelectorPageState();
}

class _ApplicationSelectorPageState extends State<_ApplicationSelectorPage> {
  final _deviceService = DeviceService();
  final _searchController = TextEditingController();
  late final Set<String> _selected = widget.selectedPackages.toSet();
  List<InstalledApplication>? _applications;
  bool _showSystemApps = false;
  String _query = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadApplications();
    _searchController.addListener(
      () => setState(() {
        _query = _searchController.text.trim().toLowerCase();
      }),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApplications() async {
    try {
      final applications = await _deviceService.installedApplications();
      if (mounted) setState(() => _applications = applications);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = FlsingColors.of(context);
    final applications = _filteredApplications;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            children: [
              Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back,
                    tooltip: '返回',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.mode == PerAppProxyMode.include
                          ? '选择要代理的应用'
                          : '选择不代理的应用',
                      style: Theme.of(context).textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: '保存',
                    icon: const Icon(Icons.check),
                    onPressed: () => Navigator.pop(context, _selected.toList()),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '搜索应用或包名',
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('显示系统应用'),
                value: _showSystemApps,
                onChanged: (value) => setState(() => _showSystemApps = value),
              ),
              Expanded(
                child: _applications == null
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Text(_error!, style: TextStyle(color: c.danger)),
                      )
                    : ListView.builder(
                        itemCount: applications.length,
                        itemBuilder: (_, index) {
                          final application = applications[index];
                          final selected = _selected.contains(
                            application.packageName,
                          );
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: c.surface3,
                              child: Icon(Icons.apps_outlined, color: c.text3),
                            ),
                            title: Text(
                              application.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              application.packageName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: c.text4, fontSize: 12),
                            ),
                            trailing: Checkbox(
                              value: selected,
                              onChanged: (_) =>
                                  _toggle(application.packageName),
                            ),
                            onTap: () => _toggle(application.packageName),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<InstalledApplication> get _filteredApplications {
    final apps = _applications ?? const <InstalledApplication>[];
    return apps
        .where((application) {
          if (!_showSystemApps && application.isSystem) return false;
          if (_query.isEmpty) return true;
          return application.name.toLowerCase().contains(_query) ||
              application.packageName.toLowerCase().contains(_query);
        })
        .toList(growable: false);
  }

  void _toggle(String packageName) {
    setState(() {
      if (!_selected.add(packageName)) _selected.remove(packageName);
    });
  }
}

class _LogsPage extends StatelessWidget {
  const _LogsPage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = FlsingColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            children: [
              Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back,
                    tooltip: '返回',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Text('日志', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    tooltip: '复制',
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: state.logs.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(
                              ClipboardData(
                                text: state.buildSanitizedLogReport(),
                              ),
                            );
                            showAppMessage('脱敏日志已复制');
                          },
                  ),
                  IconButton(
                    tooltip: '清空',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: state.logs.isEmpty ? null : state.clearLogs,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: state.logs.isEmpty
                    ? Center(
                        child: Text('暂无日志', style: TextStyle(color: c.text4)),
                      )
                    : Material(
                        color: c.surface1,
                        borderRadius: BorderRadius.circular(8),
                        child: ListView.builder(
                          itemCount: state.logs.length,
                          itemBuilder: (_, index) {
                            final log = state.logs[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              child: Text(
                                '[${_logLevelName(log.level)}] ${state.sanitizedLogMessage(log.message)}',
                                style: TextStyle(
                                  color: c.text3,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: Text(
      label,
      style: TextStyle(color: FlsingColors.of(context).text4, fontSize: 13),
    ),
  );
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
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: c.border1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
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
  Widget build(BuildContext context) => ListTile(
    title: Text(label),
    subtitle: Text(
      subtitle,
      style: TextStyle(color: FlsingColors.of(context).text4, fontSize: 13),
    ),
    trailing: active
        ? Icon(Icons.check, color: FlsingColors.of(context).accent)
        : null,
    onTap: active ? null : onTap,
  );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, this.value, this.future, this.onTap});
  final String label;
  final String? value;
  final Future<String>? future;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: FlsingColors.of(context).text4,
      fontSize: 13,
    );
    return ListTile(
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (future != null)
            FutureBuilder<String>(
              future: future,
              builder: (_, snapshot) =>
                  Text(snapshot.data ?? '...', style: style),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                value ?? '',
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          if (onTap != null)
            Icon(Icons.chevron_right, size: 18, color: style.color),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _TrailingValue extends StatelessWidget {
  const _TrailingValue(this.value);
  final String value;

  @override
  Widget build(BuildContext context) => Text(
    value,
    style: TextStyle(color: FlsingColors.of(context).text4, fontSize: 13),
  );
}

String _phaseName(ConnectionPhase phase) => switch (phase) {
  ConnectionPhase.connected => '已连接',
  ConnectionPhase.connecting => '连接中',
  ConnectionPhase.disconnecting => '断开中',
  ConnectionPhase.disconnected => '未连接',
};

String _modeName(ProxyMode mode) => switch (mode) {
  ProxyMode.rule => '规则模式',
  ProxyMode.global => '全局模式',
  ProxyMode.direct => '直连模式',
};

String _themeName(ThemeMode mode) => switch (mode) {
  ThemeMode.system => '跟随系统',
  ThemeMode.light => '浅色',
  ThemeMode.dark => '深色',
};

ThemeMode _themeModeFromSetting(String value) => switch (value) {
  ThemeModeOption.light => ThemeMode.light,
  ThemeModeOption.dark => ThemeMode.dark,
  _ => ThemeMode.system,
};

String _logLevelName(int level) => switch (level) {
  0 => 'panic',
  1 => 'fatal',
  2 => 'error',
  3 => 'warn',
  4 => 'info',
  5 => 'debug',
  _ => 'trace',
};

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
          if (mounted) {
            setState(() {
              _received = received;
              _total = total;
            });
          }
        },
      );
      if (!mounted) return;
      setState(() => _phase = _UpdatePhase.installing);
      await widget.service.installApk(apk);
    } catch (error) {
      if (mounted) {
        setState(() {
          _phase = _UpdatePhase.failed;
          _error = error.toString();
        });
      }
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
    _UpdatePhase.checking => '正在从 GitHub 获取最新版本。',
    _UpdatePhase.downloading => '发现 v${_release?.version}，正在下载安装包。',
    _UpdatePhase.upToDate => '当前版本已经是 GitHub 上的最新版本。',
    _UpdatePhase.installing => '安装包已下载，已唤起系统安装器。',
    _UpdatePhase.failed => _error ?? '发生未知错误',
  };

  String get _downloadProgress {
    final received = (_received / 1024 / 1024).toStringAsFixed(1);
    if (_total == null || _total == 0) return '$received MB';
    return '$received / ${(_total! / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
