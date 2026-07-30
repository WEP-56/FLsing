import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_messenger.dart';
import '../../core/theme/flsing_theme.dart';
import '../../data/services/advanced_network_settings.dart';
import '../../data/services/app_settings.dart';
import '../../providers/app_state.dart';
import '../widgets/app_surfaces.dart';

class AdvancedNetworkPage extends StatefulWidget {
  const AdvancedNetworkPage({super.key});

  @override
  State<AdvancedNetworkPage> createState() => _AdvancedNetworkPageState();
}

class _AdvancedNetworkPageState extends State<AdvancedNetworkPage> {
  @override
  Widget build(BuildContext context) {
    final settings = AppSettings().advancedNetworkSettings;
    return _PageFrame(
      title: '高级网络',
      child: ListView(
        children: [
          const _SectionLabel('配置覆写'),
          _SettingsGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: const Text('DNS'),
                subtitle: Text(_dnsSummary(settings), style: _subtle(context)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(const _DnsSettingsPage()),
              ),
              ListTile(
                leading: const Icon(Icons.hub_outlined),
                title: const Text('TUN 参数'),
                subtitle: Text(
                  settings.tunEnabled
                      ? '${settings.tunStack.name} · MTU ${settings.tunMtu}'
                      : '使用订阅配置',
                  style: _subtle(context),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(const _TunSettingsPage()),
              ),
            ],
          ),
          const _SectionLabel('生效方式'),
          _SettingsGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: const Text('保存后重载 VPN'),
                subtitle: Text(
                  context.watch<AppState>().isConnected
                      ? '当前已连接，保存会造成短暂中断'
                      : '当前未连接，下次连接时生效',
                  style: _subtle(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() {});
  }

  String _dnsSummary(AdvancedNetworkSettings settings) =>
      switch (settings.dnsMode) {
        DnsOverrideMode.subscription => '使用订阅配置',
        DnsOverrideMode.flsing => 'FLsing 默认',
        DnsOverrideMode.manual =>
          '手动 ${settings.dnsTransport == DnsTransport.https ? 'DoH' : 'DoT'}',
      };
}

class _DnsSettingsPage extends StatefulWidget {
  const _DnsSettingsPage();

  @override
  State<_DnsSettingsPage> createState() => _DnsSettingsPageState();
}

class _DnsSettingsPageState extends State<_DnsSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late DnsOverrideMode _mode;
  late DnsTransport _transport;
  late DnsStrategy _strategy;
  late bool _cacheEnabled;
  late bool _independentCache;
  late bool _fakeIpEnabled;
  late TextEditingController _serverController;
  late TextEditingController _clientSubnetController;
  bool _saving = false;

  bool get _overridden => _mode != DnsOverrideMode.subscription;

  @override
  void initState() {
    super.initState();
    _load(AppSettings().advancedNetworkSettings);
  }

  void _load(AdvancedNetworkSettings settings) {
    _mode = settings.dnsMode;
    _transport = settings.dnsTransport;
    _strategy = settings.dnsStrategy;
    _cacheEnabled = settings.dnsCacheEnabled;
    _independentCache = settings.dnsIndependentCache;
    _fakeIpEnabled = settings.dnsFakeIpEnabled;
    _serverController = TextEditingController(text: settings.dnsServer);
    _clientSubnetController = TextEditingController(
      text: settings.dnsClientSubnet,
    );
  }

  @override
  void dispose() {
    _serverController.dispose();
    _clientSubnetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _PageFrame(
    title: 'DNS',
    actions: [
      IconButton(
        tooltip: '恢复默认',
        onPressed: _saving ? null : _reset,
        icon: const Icon(Icons.restore),
      ),
      IconButton(
        tooltip: '保存',
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
      ),
    ],
    child: Form(
      key: _formKey,
      child: ListView(
        children: [
          const _SectionLabel('策略'),
          _SettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<DnsOverrideMode>(
                    segments: const [
                      ButtonSegment(
                        value: DnsOverrideMode.subscription,
                        label: Text('订阅'),
                      ),
                      ButtonSegment(
                        value: DnsOverrideMode.flsing,
                        label: Text('默认'),
                      ),
                      ButtonSegment(
                        value: DnsOverrideMode.manual,
                        label: Text('手动'),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (value) =>
                        setState(() => _mode = value.first),
                  ),
                ),
              ),
              if (_mode == DnsOverrideMode.manual) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: DropdownButtonFormField<DnsTransport>(
                    initialValue: _transport,
                    decoration: const InputDecoration(labelText: '协议'),
                    items: const [
                      DropdownMenuItem(
                        value: DnsTransport.https,
                        child: Text('DoH (HTTPS)'),
                      ),
                      DropdownMenuItem(
                        value: DnsTransport.tls,
                        child: Text('DoT (TLS)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _transport = value;
                        _serverController.text = value == DnsTransport.https
                            ? 'https://1.1.1.1/dns-query'
                            : 'tls://1.1.1.1:853';
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: TextFormField(
                    controller: _serverController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: _transport == DnsTransport.https
                          ? 'DoH 地址'
                          : 'DoT 地址',
                      hintText: _transport == DnsTransport.https
                          ? 'https://dns.example/dns-query'
                          : 'tls://dns.example:853',
                    ),
                    validator: _validateDnsAddress,
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: DropdownButtonFormField<DnsStrategy>(
                  initialValue: _strategy,
                  decoration: const InputDecoration(labelText: '解析策略'),
                  items: const [
                    DropdownMenuItem(
                      value: DnsStrategy.preferIpv4,
                      child: Text('优先 IPv4'),
                    ),
                    DropdownMenuItem(
                      value: DnsStrategy.preferIpv6,
                      child: Text('优先 IPv6'),
                    ),
                    DropdownMenuItem(
                      value: DnsStrategy.ipv4Only,
                      child: Text('仅 IPv4'),
                    ),
                    DropdownMenuItem(
                      value: DnsStrategy.ipv6Only,
                      child: Text('仅 IPv6'),
                    ),
                  ],
                  onChanged: _overridden
                      ? (value) {
                          if (value != null) setState(() => _strategy = value);
                        }
                      : null,
                ),
              ),
            ],
          ),
          const _SectionLabel('缓存与响应'),
          _SettingsGroup(
            children: [
              SwitchListTile.adaptive(
                title: const Text('DNS 缓存'),
                value: _cacheEnabled,
                onChanged: _overridden
                    ? (value) => setState(() => _cacheEnabled = value)
                    : null,
              ),
              SwitchListTile.adaptive(
                title: const Text('独立缓存'),
                subtitle: Text('按 DNS 服务器隔离缓存', style: _subtle(context)),
                value: _independentCache,
                onChanged: _overridden && _cacheEnabled
                    ? (value) => setState(() => _independentCache = value)
                    : null,
              ),
              SwitchListTile.adaptive(
                title: const Text('FakeIP'),
                subtitle: Text('为代理域名返回虚拟地址', style: _subtle(context)),
                value: _fakeIpEnabled,
                onChanged: _overridden
                    ? (value) => setState(() => _fakeIpEnabled = value)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: TextFormField(
                  controller: _clientSubnetController,
                  enabled: _overridden,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: '客户端子网（可选）',
                    hintText: '203.0.113.0/24',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  String? _validateDnsAddress(String? value) {
    if (_mode != DnsOverrideMode.manual) return null;
    final uri = Uri.tryParse(value?.trim() ?? '');
    final scheme = _transport == DnsTransport.https ? 'https' : 'tls';
    if (uri == null || uri.scheme != scheme || uri.host.isEmpty) {
      return _transport == DnsTransport.https
          ? '请输入有效的 https:// 地址'
          : '请输入有效的 tls:// 地址';
    }
    if (_transport == DnsTransport.https && uri.path.isEmpty) {
      return 'DoH 地址需要包含查询路径';
    }
    return null;
  }

  AdvancedNetworkSettings _candidate() =>
      AppSettings().advancedNetworkSettings.copyWith(
        dnsMode: _mode,
        dnsTransport: _transport,
        dnsServer: _serverController.text.trim(),
        dnsStrategy: _strategy,
        dnsCacheEnabled: _cacheEnabled,
        dnsIndependentCache: _independentCache,
        dnsFakeIpEnabled: _fakeIpEnabled,
        dnsClientSubnet: _clientSubnetController.text.trim(),
      );

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final state = context.read<AppState>();
    await state.saveAdvancedNetworkSettings(_candidate());
    final message = state.takeFeedback();
    if (message != null) showAppMessage(message);
    if (mounted) setState(() => _saving = false);
  }

  void _reset() {
    const defaults = AdvancedNetworkSettings();
    setState(() {
      _mode = defaults.dnsMode;
      _transport = defaults.dnsTransport;
      _strategy = defaults.dnsStrategy;
      _cacheEnabled = defaults.dnsCacheEnabled;
      _independentCache = defaults.dnsIndependentCache;
      _fakeIpEnabled = defaults.dnsFakeIpEnabled;
      _serverController.text = defaults.dnsServer;
      _clientSubnetController.text = defaults.dnsClientSubnet;
    });
  }
}

class _TunSettingsPage extends StatefulWidget {
  const _TunSettingsPage();

  @override
  State<_TunSettingsPage> createState() => _TunSettingsPageState();
}

class _TunSettingsPageState extends State<_TunSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late bool _enabled;
  late TunStack _stack;
  late bool _autoRoute;
  late bool _strictRoute;
  late bool _sniff;
  late bool _overrideDestination;
  late TextEditingController _mtuController;
  late TextEditingController _addressesController;
  late TextEditingController _exclusionsController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = AppSettings().advancedNetworkSettings;
    _enabled = settings.tunEnabled;
    _stack = settings.tunStack;
    _autoRoute = settings.tunAutoRoute;
    _strictRoute = settings.tunStrictRoute;
    _sniff = settings.tunSniff;
    _overrideDestination = settings.tunOverrideDestination;
    _mtuController = TextEditingController(text: '${settings.tunMtu}');
    _addressesController = TextEditingController(
      text: settings.tunAddresses.join('\n'),
    );
    _exclusionsController = TextEditingController(
      text: settings.tunRouteExclusions.join('\n'),
    );
  }

  @override
  void dispose() {
    _mtuController.dispose();
    _addressesController.dispose();
    _exclusionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _PageFrame(
    title: 'TUN 参数',
    actions: [
      IconButton(
        tooltip: '恢复默认',
        onPressed: _saving ? null : _reset,
        icon: const Icon(Icons.restore),
      ),
      IconButton(
        tooltip: '保存',
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
      ),
    ],
    child: Form(
      key: _formKey,
      child: ListView(
        children: [
          const _SectionLabel('覆写'),
          _SettingsGroup(
            children: [
              SwitchListTile.adaptive(
                title: const Text('自定义 TUN 参数'),
                subtitle: Text('关闭时完整保留订阅配置', style: _subtle(context)),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            ],
          ),
          const _SectionLabel('接口'),
          _SettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextFormField(
                  controller: _mtuController,
                  enabled: _enabled,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'MTU'),
                  validator: (value) {
                    if (!_enabled) return null;
                    final mtu = int.tryParse(value ?? '');
                    return mtu != null && mtu >= 1280 && mtu <= 9000
                        ? null
                        : '请输入 1280 到 9000 之间的数值';
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: DropdownButtonFormField<TunStack>(
                  initialValue: _stack,
                  decoration: const InputDecoration(labelText: '协议栈'),
                  items: const [
                    DropdownMenuItem(
                      value: TunStack.system,
                      child: Text('System'),
                    ),
                    DropdownMenuItem(
                      value: TunStack.gvisor,
                      child: Text('gVisor'),
                    ),
                    DropdownMenuItem(
                      value: TunStack.mixed,
                      child: Text('Mixed'),
                    ),
                  ],
                  onChanged: _enabled
                      ? (value) {
                          if (value != null) setState(() => _stack = value);
                        }
                      : null,
                ),
              ),
              SwitchListTile.adaptive(
                title: const Text('自动路由'),
                value: _autoRoute,
                onChanged: _enabled
                    ? (value) => setState(() => _autoRoute = value)
                    : null,
              ),
              SwitchListTile.adaptive(
                title: const Text('严格路由'),
                subtitle: Text('减少 DNS 泄漏风险', style: _subtle(context)),
                value: _strictRoute,
                onChanged: _enabled && _autoRoute
                    ? (value) => setState(() => _strictRoute = value)
                    : null,
              ),
            ],
          ),
          const _SectionLabel('流量识别'),
          _SettingsGroup(
            children: [
              SwitchListTile.adaptive(
                title: const Text('嗅探协议'),
                value: _sniff,
                onChanged: _enabled
                    ? (value) => setState(() => _sniff = value)
                    : null,
              ),
              SwitchListTile.adaptive(
                title: const Text('覆盖目标地址'),
                value: _overrideDestination,
                onChanged: _enabled && _sniff
                    ? (value) => setState(() => _overrideDestination = value)
                    : null,
              ),
            ],
          ),
          const _SectionLabel('地址与路由'),
          _SettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextFormField(
                  controller: _addressesController,
                  enabled: _enabled,
                  minLines: 2,
                  maxLines: 4,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: '接口地址',
                    hintText: '172.19.0.1/30',
                  ),
                  validator: (value) => _enabled && _lines(value ?? '').isEmpty
                      ? '至少需要一个地址'
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: TextFormField(
                  controller: _exclusionsController,
                  enabled: _enabled && _autoRoute,
                  minLines: 2,
                  maxLines: 4,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: '排除路由（可选）',
                    hintText: '192.168.0.0/16',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  AdvancedNetworkSettings _candidate() =>
      AppSettings().advancedNetworkSettings.copyWith(
        tunEnabled: _enabled,
        tunMtu: int.tryParse(_mtuController.text) ?? 1400,
        tunStack: _stack,
        tunAutoRoute: _autoRoute,
        tunStrictRoute: _strictRoute,
        tunSniff: _sniff,
        tunOverrideDestination: _overrideDestination,
        tunAddresses: _lines(_addressesController.text),
        tunRouteExclusions: _lines(_exclusionsController.text),
      );

  List<String> _lines(String value) => value
      .split(RegExp(r'[,\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final state = context.read<AppState>();
    await state.saveAdvancedNetworkSettings(_candidate());
    final message = state.takeFeedback();
    if (message != null) showAppMessage(message);
    if (mounted) setState(() => _saving = false);
  }

  void _reset() {
    const defaults = AdvancedNetworkSettings();
    setState(() {
      _enabled = defaults.tunEnabled;
      _stack = defaults.tunStack;
      _autoRoute = defaults.tunAutoRoute;
      _strictRoute = defaults.tunStrictRoute;
      _sniff = defaults.tunSniff;
      _overrideDestination = defaults.tunOverrideDestination;
      _mtuController.text = '${defaults.tunMtu}';
      _addressesController.text = defaults.tunAddresses.join('\n');
      _exclusionsController.text = defaults.tunRouteExclusions.join('\n');
    });
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.title, required this.child, this.actions});

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Scaffold(
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
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    ...?actions,
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    ),
  );
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
    final colors = FlsingColors.of(context);
    return Material(
      color: colors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.border1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

TextStyle _subtle(BuildContext context) =>
    TextStyle(color: FlsingColors.of(context).text4, fontSize: 13);
