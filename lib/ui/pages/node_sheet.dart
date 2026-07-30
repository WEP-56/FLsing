import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_messenger.dart';
import '../../core/motion.dart';
import '../../core/region_codes.dart';
import '../../core/theme/flsing_theme.dart';
import '../../models/app_models.dart';
import '../../providers/app_state.dart';
import '../widgets/flsing_sheets.dart';
import '../widgets/globe/connection_globe.dart' show SignalBars;

Future<void> showNodeSheet(BuildContext context) {
  return FlsingSheets.partial(context, builder: (_) => const NodeSheet());
}

class NodeSheet extends StatefulWidget {
  const NodeSheet({super.key});

  @override
  State<NodeSheet> createState() => _NodeSheetState();
}

class _NodeSheetState extends State<NodeSheet> {
  String _query = '';
  bool _grid = false;
  bool _refreshing = false;

  Future<void> _runWithToast(Future<void> Function() action) async {
    final state = context.read<AppState>();
    await action();
    final message = state.takeFeedback();
    if (message != null) showAppMessage(message);
  }

  Future<void> _refreshNodes() async {
    final state = context.read<AppState>();
    final active = state.activeSubscription;
    if (active == null || _refreshing) return;
    setState(() => _refreshing = true);
    await _runWithToast(() => state.refreshSubscription(active.id));
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = FlsingColors.of(context);
    final query = _query.trim().toLowerCase();
    final nodes = state.nodes
        .where(
          (node) =>
              query.isEmpty || node.displayName.toLowerCase().contains(query),
        )
        .toList();

    return Column(
      children: [
        _buildHeader(state, c),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            style: TextStyle(fontSize: 13.5, color: c.text1),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 17, color: c.text5),
              hintText: '搜索节点',
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(color: c.border1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(color: c.border3),
              ),
            ),
          ),
        ),
        Expanded(
          child: nodes.isEmpty
              ? Center(
                  child: Text(
                    state.nodes.isEmpty
                        ? (state.hasSubscription
                              ? '暂无可用节点，试试更新订阅'
                              : '暂无节点，请先添加订阅')
                        : '未找到匹配的节点',
                    style: TextStyle(fontSize: 13, color: c.text5),
                  ),
                )
              : _grid
              ? GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    mainAxisExtent: 128,
                  ),
                  itemCount: nodes.length,
                  itemBuilder: (context, index) => StaggeredEntrance(
                    index: index,
                    child: _NodeGridTile(node: nodes[index]),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                  itemCount: nodes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => StaggeredEntrance(
                    index: index,
                    child: _NodeListTile(node: nodes[index]),
                  ),
                ),
        ),
        _buildFooter(state, c),
      ],
    );
  }

  Widget _buildHeader(AppState state, FlsingColors c) {
    final subs = state.subscriptions;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '节点管理',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: c.text1,
                  ),
                ),
                const SizedBox(height: 2),
                PopupMenuButton<String>(
                  tooltip: '切换订阅',
                  onSelected: (id) =>
                      _runWithToast(() => state.activateSubscription(id)),
                  itemBuilder: (_) => [
                    for (final sub in subs)
                      PopupMenuItem(
                        value: sub.id,
                        height: 44,
                        child: Row(
                          children: [
                            Icon(
                              sub.id == state.activeSubscription?.id
                                  ? Icons.check
                                  : Icons.layers_outlined,
                              size: 16,
                              color: c.text3,
                            ),
                            const SizedBox(width: 12),
                            Text(sub.name),
                          ],
                        ),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '当前订阅：',
                          style: TextStyle(fontSize: 12.5, color: c.text4),
                        ),
                        Flexible(
                          child: Text(
                            state.activeSubscription?.name ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: c.text2,
                            ),
                          ),
                        ),
                        Icon(Icons.expand_more, size: 14, color: c.text4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ToolButton(
            icon: Icons.speed_outlined,
            label: '测速',
            busy: state.isTestingAny,
            onTap: state.isTestingAny
                ? null
                : () => _runWithToast(state.testAllNodes),
          ),
          const SizedBox(width: 8),
          _ToolButton(
            icon: _grid ? Icons.view_list_outlined : Icons.grid_view_outlined,
            label: '视图',
            onTap: () => setState(() => _grid = !_grid),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(AppState state, FlsingColors c) {
    final updatedAt = state.activeSubscription?.updatedAt;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        MediaQuery.paddingOf(context).bottom + 14,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 13, color: c.text5),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              updatedAt == null ? '尚未导入订阅' : '上次更新：${formatDateTime(updatedAt)}',
              style: TextStyle(
                fontSize: 11.5,
                color: c.text5,
                fontFeatures: kTabularFigures,
              ),
            ),
          ),
          InkWell(
            onTap: _refreshNodes,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  _refreshing
                      ? SizedBox.square(
                          dimension: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            color: c.text3,
                          ),
                        )
                      : Icon(Icons.refresh, size: 13, color: c.text3),
                  const SizedBox(width: 5),
                  Text(
                    '更新节点',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: c.text3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = FlsingColors.of(context);
    return Material(
      color: c.surface1,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 56,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              busy
                  ? SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: c.text2,
                      ),
                    )
                  : Icon(icon, size: 16, color: c.text2),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontSize: 9.5, color: c.text4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountryChip extends StatelessWidget {
  const _CountryChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = FlsingColors.of(context);
    final code = regionCodeFor(name);
    return Container(
      width: 40,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border1),
      ),
      child: code == null
          ? Icon(Icons.public_outlined, size: 14, color: c.text3)
          : Text(
              code,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: c.text2,
              ),
            ),
    );
  }
}

String _latencyText(ProxyNode node) =>
    node.latency == null ? '--' : '${node.latency} ms';

class _NodeListTile extends StatelessWidget {
  const _NodeListTile({required this.node});

  final ProxyNode node;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = FlsingColors.of(context);
    final selected = state.selectedNode?.id == node.id;
    final subtitle = [
      if (node.protocol.isNotEmpty) node.protocol,
      if (node.transport.isNotEmpty) node.transport,
    ].join(' · ');

    return Material(
      color: selected ? c.surface2 : c.surface1,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _select(context),
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            if (selected)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 3,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c.inverseBg,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: selected ? c.border2 : c.border1),
              ),
              child: Row(
                children: [
                  _RadioDot(selected: selected),
                  const SizedBox(width: 10),
                  _CountryChip(name: node.displayName),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: c.text1,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              letterSpacing: 0.3,
                              color: c.text5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _latencyText(node),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: c.latency(node.latency),
                          fontFeatures: kTabularFigures,
                        ),
                      ),
                      const SizedBox(height: 3),
                      SignalBars(
                        level: FlsingColors.latencyLevel(node.latency),
                        size: 11,
                        color: c.latency(node.latency),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  _TestButton(node: node),
                  Builder(
                    builder: (buttonContext) => InkResponse(
                      onTap: () => _showMenu(buttonContext),
                      radius: 18,
                      child: SizedBox(
                        width: 26,
                        height: 32,
                        child: Icon(
                          Icons.more_vert,
                          size: 16,
                          color: c.text4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _select(BuildContext context) async {
    final state = context.read<AppState>();
    await state.selectNode(node.id);
    final message = state.takeFeedback();
    if (message != null) showAppMessage(message);
  }

  void _showMenu(BuildContext context) {
    final state = context.read<AppState>();
    showFlsingMenu(
      context,
      position: menuPositionFrom(context),
      items: [
        SheetMenuItem(
          icon: Icons.check,
          label: '设为当前',
          onTap: () => _select(context),
        ),
        SheetMenuItem(
          icon: Icons.speed_outlined,
          label: '测速',
          onTap: () => state.testNode(node.id),
        ),
        SheetMenuItem(
          icon: Icons.info_outline,
          label: '节点信息',
          onTap: () => _showNodeInfo(context, node),
        ),
      ],
    );
  }
}

class _NodeGridTile extends StatelessWidget {
  const _NodeGridTile({required this.node});

  final ProxyNode node;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = FlsingColors.of(context);
    final selected = state.selectedNode?.id == node.id;

    return Material(
      color: selected ? c.surface2 : c.surface1,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () async {
          await state.selectNode(node.id);
          final message = state.takeFeedback();
          if (message != null) showAppMessage(message);
        },
        onLongPress: () => _showNodeInfo(context, node),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? c.border3 : c.border1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CountryChip(name: node.displayName),
                  if (selected)
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.inverseBg,
                      ),
                      child: Icon(Icons.check, size: 12, color: c.inverseFg),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                node.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: c.text1,
                ),
              ),
              if (node.protocol.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  node.protocol,
                  style: TextStyle(fontSize: 10.5, color: c.text5),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  node.testing
                      ? SizedBox.square(
                          dimension: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            color: c.text3,
                          ),
                        )
                      : Text(
                          _latencyText(node),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: c.latency(node.latency),
                            fontFeatures: kTabularFigures,
                          ),
                        ),
                  SignalBars(
                    level: FlsingColors.latencyLevel(node.latency),
                    size: 11,
                    color: c.latency(node.latency),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = FlsingColors.of(context);
    return AnimatedContainer(
      duration: Motion.fast,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? c.inverseBg : Colors.transparent,
        border: Border.all(
          color: selected ? c.inverseBg : c.border3,
          width: 1.4,
        ),
      ),
      child: selected
          ? Icon(Icons.check, size: 13, color: c.inverseFg)
          : null,
    );
  }
}

class _TestButton extends StatelessWidget {
  const _TestButton({required this.node});

  final ProxyNode node;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = FlsingColors.of(context);
    return Material(
      color: c.surface2,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: state.isTestingAny
            ? null
            : () async {
                await state.testNode(node.id);
                final message = state.takeFeedback();
                if (message != null) showAppMessage(message);
              },
        child: SizedBox.square(
          dimension: 36,
          child: node.testing
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: c.text3,
                  ),
                )
              : Icon(Icons.speed_outlined, size: 15, color: c.text3),
        ),
      ),
    );
  }
}

void _showNodeInfo(BuildContext context, ProxyNode node) {
  final state = context.read<AppState>();
  final c = FlsingColors.of(context);
  final rows = <(String, String)>[
    ('名称', node.name),
    ('协议', node.protocol.isEmpty ? '—' : node.protocol),
    if (node.transport.isNotEmpty) ('传输', node.transport),
    ('延迟', node.latency == null ? '--' : '${node.latency} ms'),
    ('来源', state.activeSubscription?.name ?? '—'),
  ];
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(node.displayName, maxLines: 2),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, row) in rows.indexed)
            Container(
              padding: EdgeInsets.only(
                top: index == 0 ? 0 : 10,
                bottom: index == rows.length - 1 ? 0 : 10,
              ),
              decoration: BoxDecoration(
                border: index == rows.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: c.border1)),
              ),
              child: Row(
                children: [
                  Text(row.$1, style: TextStyle(fontSize: 13, color: c.text4)),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        color: c.text1,
                        fontFeatures: kTabularFigures,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

String formatDateTime(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
