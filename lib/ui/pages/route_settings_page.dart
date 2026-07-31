import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_messenger.dart';
import '../../core/theme/flsing_theme.dart';
import '../../data/services/app_settings.dart';
import '../../data/services/route_settings.dart';
import '../../providers/app_state.dart';
import '../widgets/app_surfaces.dart';

class RouteSettingsPage extends StatefulWidget {
  const RouteSettingsPage({super.key});

  @override
  State<RouteSettingsPage> createState() => _RouteSettingsPageState();
}

class _RouteSettingsPageState extends State<RouteSettingsPage> {
  late RouteOverrideSettings _settings;
  List<String> _outbounds = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _settings = AppSettings().advancedNetworkSettings.route;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOutbounds());
  }

  Future<void> _loadOutbounds() async {
    final values = await context.read<AppState>().availableRouteOutbounds();
    if (!mounted) return;
    setState(() => _outbounds = values);
  }

  List<String> get _outboundOptions {
    final values = <String>{..._outbounds};
    final finalOutbound = _settings.finalOutbound.trim();
    if (finalOutbound.isNotEmpty) values.add(finalOutbound);
    for (final rule in _settings.rules) {
      final outbound = rule.outbound.trim();
      if (outbound.isNotEmpty) values.add(outbound);
    }
    return values.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) => _PageFrame(
    title: '路由策略',
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
    child: ListView(
      children: [
        const _SectionLabel('覆写'),
        _SettingsGroup(
          children: [
            SwitchListTile.adaptive(
              title: const Text('自定义路由策略'),
              subtitle: Text('关闭时完整保留订阅配置', style: _subtle(context)),
              value: _settings.enabled,
              onChanged: (value) => setState(
                () => _settings = _settings.copyWith(enabled: value),
              ),
            ),
          ],
        ),
        const _SectionLabel('基础策略'),
        _SettingsGroup(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: DropdownButtonFormField<String>(
                key: ValueKey(
                  '${_settings.finalOutbound}:${_outboundOptions.join(',')}',
                ),
                initialValue: _settings.finalOutbound,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '默认出口'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('沿用订阅')),
                  ..._outboundOptions.map(
                    (outbound) => DropdownMenuItem(
                      value: outbound,
                      child: Text(outbound, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: _settings.enabled
                    ? (value) => setState(
                        () => _settings = _settings.copyWith(
                          finalOutbound: value ?? '',
                        ),
                      )
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: DropdownButtonFormField<RouteIpMode>(
                initialValue: _settings.ipMode,
                decoration: const InputDecoration(labelText: 'IP 版本'),
                items: const [
                  DropdownMenuItem(
                    value: RouteIpMode.dualStack,
                    child: Text('IPv4 + IPv6'),
                  ),
                  DropdownMenuItem(
                    value: RouteIpMode.ipv4Only,
                    child: Text('仅 IPv4'),
                  ),
                  DropdownMenuItem(
                    value: RouteIpMode.ipv6Only,
                    child: Text('仅 IPv6'),
                  ),
                ],
                onChanged: _settings.enabled
                    ? (value) {
                        if (value == null) return;
                        setState(
                          () => _settings = _settings.copyWith(ipMode: value),
                        );
                      }
                    : null,
              ),
            ),
            SwitchListTile.adaptive(
              title: const Text('自动探测出口接口'),
              value: _settings.autoDetectInterface,
              onChanged: _settings.enabled
                  ? (value) => setState(
                      () => _settings = _settings.copyWith(
                        autoDetectInterface: value,
                      ),
                    )
                  : null,
            ),
          ],
        ),
        const _SectionLabel('常用规则'),
        _SettingsGroup(
          children: [
            SwitchListTile.adaptive(
              title: const Text('私有网络直连'),
              value: _settings.privateNetworkDirect,
              onChanged: _settings.enabled
                  ? (value) => setState(
                      () => _settings = _settings.copyWith(
                        privateNetworkDirect: value,
                      ),
                    )
                  : null,
            ),
            SwitchListTile.adaptive(
              title: const Text('中国大陆规则直连'),
              value: _settings.chinaRulesDirect,
              onChanged: _settings.enabled
                  ? (value) => setState(
                      () => _settings = _settings.copyWith(
                        chinaRulesDirect: value,
                      ),
                    )
                  : null,
            ),
            SwitchListTile.adaptive(
              title: const Text('阻止 QUIC'),
              value: _settings.blockQuic,
              onChanged: _settings.enabled
                  ? (value) => setState(
                      () => _settings = _settings.copyWith(blockQuic: value),
                    )
                  : null,
            ),
          ],
        ),
        _SectionLabelWithAction(
          label: '自定义规则',
          onAdd: _settings.enabled ? _addRule : null,
        ),
        _SettingsGroup(
          children: [
            if (_settings.rules.isEmpty)
              ListTile(
                leading: const Icon(Icons.rule_outlined),
                title: const Text('暂无自定义规则'),
                enabled: false,
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: _settings.rules.length,
                onReorder: _reorderRules,
                itemBuilder: (context, index) {
                  final rule = _settings.rules[index];
                  return ListTile(
                    key: ValueKey(rule),
                    leading: Checkbox(
                      value: rule.enabled,
                      onChanged: _settings.enabled
                          ? (value) => _replaceRule(
                              index,
                              rule.copyWith(enabled: value ?? false),
                            )
                          : null,
                    ),
                    title: Text('${index + 1}. ${_matchLabel(rule.match)}'),
                    subtitle: Text(
                      '${rule.values.join('、')} → ${_actionLabel(rule)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _subtle(context),
                    ),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      enabled: _settings.enabled,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                    enabled: _settings.enabled,
                    onTap: _settings.enabled ? () => _editRule(index) : null,
                  );
                },
              ),
          ],
        ),
      ],
    ),
  );

  String _actionLabel(CustomRouteRule rule) =>
      rule.action == RouteRuleAction.reject
      ? '拒绝'
      : (rule.outbound.isEmpty ? '默认出口' : rule.outbound);

  Future<void> _addRule() async {
    final result = await Navigator.of(context).push<_RouteRuleEditResult>(
      MaterialPageRoute(
        builder: (_) => _RouteRuleEditorPage(
          rule: const CustomRouteRule(),
          outbounds: _outboundOptions,
          allowDelete: false,
        ),
      ),
    );
    if (result?.rule == null || !mounted) return;
    setState(
      () => _settings = _settings.copyWith(
        rules: [..._settings.rules, result!.rule!],
      ),
    );
  }

  Future<void> _editRule(int index) async {
    final result = await Navigator.of(context).push<_RouteRuleEditResult>(
      MaterialPageRoute(
        builder: (_) => _RouteRuleEditorPage(
          rule: _settings.rules[index],
          outbounds: _outboundOptions,
          allowDelete: true,
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (result.deleted) {
      final rules = [..._settings.rules]..removeAt(index);
      setState(() => _settings = _settings.copyWith(rules: rules));
    } else if (result.rule != null) {
      _replaceRule(index, result.rule!);
    }
  }

  void _replaceRule(int index, CustomRouteRule rule) {
    final rules = [..._settings.rules]..[index] = rule;
    setState(() => _settings = _settings.copyWith(rules: rules));
  }

  void _reorderRules(int oldIndex, int newIndex) {
    final rules = [..._settings.rules];
    if (newIndex > oldIndex) newIndex--;
    final rule = rules.removeAt(oldIndex);
    rules.insert(newIndex, rule);
    setState(() => _settings = _settings.copyWith(rules: rules));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final candidate = AppSettings().advancedNetworkSettings.copyWith(
      route: _settings,
    );
    await state.saveAdvancedNetworkSettings(candidate);
    final message = state.takeFeedback();
    if (message != null) showAppMessage(message);
    if (mounted) setState(() => _saving = false);
  }

  void _reset() {
    setState(() => _settings = const RouteOverrideSettings());
  }
}

class _RouteRuleEditorPage extends StatefulWidget {
  const _RouteRuleEditorPage({
    required this.rule,
    required this.outbounds,
    required this.allowDelete,
  });

  final CustomRouteRule rule;
  final List<String> outbounds;
  final bool allowDelete;

  @override
  State<_RouteRuleEditorPage> createState() => _RouteRuleEditorPageState();
}

class _RouteRuleEditorPageState extends State<_RouteRuleEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late bool _enabled;
  late RouteRuleMatch _match;
  late RouteRuleAction _action;
  late String _outbound;
  late TextEditingController _valuesController;

  @override
  void initState() {
    super.initState();
    _enabled = widget.rule.enabled;
    _match = widget.rule.match;
    _action = widget.rule.action;
    _outbound = widget.rule.outbound;
    _valuesController = TextEditingController(
      text: widget.rule.values.join('\n'),
    );
  }

  @override
  void dispose() {
    _valuesController.dispose();
    super.dispose();
  }

  List<String> get _outboundOptions {
    final values = <String>{...widget.outbounds};
    if (_outbound.isNotEmpty) values.add(_outbound);
    return values.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) => _PageFrame(
    title: '路由规则',
    actions: [
      if (widget.allowDelete)
        IconButton(
          tooltip: '删除',
          onPressed: () =>
              Navigator.pop(context, const _RouteRuleEditResult(deleted: true)),
          icon: const Icon(Icons.delete_outline),
        ),
      IconButton(
        tooltip: '保存',
        onPressed: _save,
        icon: const Icon(Icons.save_outlined),
      ),
    ],
    child: Form(
      key: _formKey,
      child: ListView(
        children: [
          const _SectionLabel('状态'),
          _SettingsGroup(
            children: [
              SwitchListTile.adaptive(
                title: const Text('启用规则'),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            ],
          ),
          const _SectionLabel('匹配条件'),
          _SettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: DropdownButtonFormField<RouteRuleMatch>(
                  initialValue: _match,
                  decoration: const InputDecoration(labelText: '类型'),
                  items: RouteRuleMatch.values
                      .map(
                        (match) => DropdownMenuItem(
                          value: match,
                          child: Text(_matchLabel(match)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setState(() => _match = value);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: TextFormField(
                  controller: _valuesController,
                  minLines: 2,
                  maxLines: 6,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: '匹配值',
                    hintText: _matchHint(_match),
                  ),
                  validator: (value) =>
                      _values(value ?? '').isEmpty ? '至少需要一个匹配值' : null,
                ),
              ),
            ],
          ),
          const _SectionLabel('处理方式'),
          _SettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<RouteRuleAction>(
                    segments: const [
                      ButtonSegment(
                        value: RouteRuleAction.route,
                        label: Text('出口'),
                      ),
                      ButtonSegment(
                        value: RouteRuleAction.reject,
                        label: Text('拒绝'),
                      ),
                    ],
                    selected: {_action},
                    onSelectionChanged: (value) =>
                        setState(() => _action = value.first),
                  ),
                ),
              ),
              if (_action == RouteRuleAction.route)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('$_outbound:${_outboundOptions.join(',')}'),
                    initialValue: _outbound,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '出口'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('默认出口')),
                      ..._outboundOptions.map(
                        (outbound) => DropdownMenuItem(
                          value: outbound,
                          child: Text(
                            outbound,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _outbound = value ?? ''),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _RouteRuleEditResult(
        rule: widget.rule.copyWith(
          enabled: _enabled,
          match: _match,
          values: _values(_valuesController.text),
          action: _action,
          outbound: _action == RouteRuleAction.route ? _outbound : '',
        ),
      ),
    );
  }
}

class _RouteRuleEditResult {
  const _RouteRuleEditResult({this.rule, this.deleted = false});

  final CustomRouteRule? rule;
  final bool deleted;
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

class _SectionLabelWithAction extends StatelessWidget {
  const _SectionLabelWithAction({required this.label, required this.onAdd});

  final String label;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: FlsingColors.of(context).text4,
              fontSize: 13,
            ),
          ),
        ),
        IconButton(
          tooltip: '新增规则',
          onPressed: onAdd,
          icon: const Icon(Icons.add),
        ),
      ],
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

List<String> _values(String value) => value
    .split(RegExp(r'[,\n]'))
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toSet()
    .toList(growable: false);

String _matchLabel(RouteRuleMatch match) => switch (match) {
  RouteRuleMatch.domain => '完整域名',
  RouteRuleMatch.domainSuffix => '域名后缀',
  RouteRuleMatch.domainKeyword => '域名关键字',
  RouteRuleMatch.ipCidr => 'IP 地址',
  RouteRuleMatch.port => '目标端口',
  RouteRuleMatch.processName => '进程名称',
  RouteRuleMatch.packageName => '应用包名',
  RouteRuleMatch.wifiSsid => 'Wi-Fi SSID',
  RouteRuleMatch.networkType => '网络类型',
  RouteRuleMatch.ipVersion => 'IP 版本',
};

String _matchHint(RouteRuleMatch match) => switch (match) {
  RouteRuleMatch.domain => 'example.com',
  RouteRuleMatch.domainSuffix => '.example.com',
  RouteRuleMatch.domainKeyword => 'example',
  RouteRuleMatch.ipCidr => '203.0.113.0/24',
  RouteRuleMatch.port => '443\n8000-9000',
  RouteRuleMatch.processName => 'example.exe',
  RouteRuleMatch.packageName => 'com.example.app',
  RouteRuleMatch.wifiSsid => 'Office WiFi',
  RouteRuleMatch.networkType => 'wifi\ncellular',
  RouteRuleMatch.ipVersion => '4\n6',
};

TextStyle _subtle(BuildContext context) =>
    TextStyle(color: FlsingColors.of(context).text4, fontSize: 13);
