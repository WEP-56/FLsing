import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_models.dart';
import '../../providers/app_state.dart';
import '../widgets/app_surfaces.dart';
import 'node_sheet.dart';
import 'settings_page.dart';
import 'subscription_sheet.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 760;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Column(
                children: [
                  _Header(
                    onSubscriptions: () => showSubscriptionSheet(context),
                    onSettings: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 22),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () async {
                              await state.toggleConnection();
                              if (!context.mounted) return;
                              final message = state.takeFeedback();
                              if (message != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(message)),
                                );
                              }
                            },
                            child: GlobeGraphic(
                              active: state.isConnected,
                              connecting: state.isTransitioning,
                              center: _ConnectionStatus(state: state),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 18),
                  _ControlPanel(onNodeTap: () => showNodeSheet(context)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSubscriptions, required this.onSettings});
  final VoidCallback onSubscriptions;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'FLsing',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        IconButton(
          onPressed: onSubscriptions,
          tooltip: '订阅管理',
          icon: const Icon(Icons.layers_outlined),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: onSettings,
          tooltip: '设置',
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final label = switch (state.phase) {
      ConnectionPhase.disconnected => '未连接',
      ConnectionPhase.connecting => '连接中',
      ConnectionPhase.connected => '已连接',
      ConnectionPhase.disconnecting => '断开中',
    };
    final seconds = state.connectedFor.inSeconds;
    final time =
        '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Column(
        key: ValueKey(state.phase),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.secondary, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            state.isConnected
                ? time
                : state.hasSubscription
                ? '轻触连接'
                : '添加订阅开始',
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (state.isConnected)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.signal_cellular_alt,
                  size: 17,
                  color: AppColors.success,
                ),
                SizedBox(width: 6),
                Text('稳定', style: TextStyle(color: AppColors.success)),
              ],
            ),
        ],
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.onNodeTap});
  final VoidCallback onNodeTap;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final node = state.selectedNode;
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('模式', style: TextStyle(color: AppColors.secondary)),
          const SizedBox(height: 8),
          SegmentedButton<ProxyMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ProxyMode.rule,
                icon: Icon(Icons.bolt_outlined),
                label: Text('规则'),
              ),
              ButtonSegment(
                value: ProxyMode.global,
                icon: Icon(Icons.public),
                label: Text('全局'),
              ),
              ButtonSegment(
                value: ProxyMode.direct,
                icon: Icon(Icons.link),
                label: Text('直连'),
              ),
            ],
            selected: {state.mode},
            onSelectionChanged: (value) => state.selectMode(value.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
          const Divider(height: 26),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: state.hasSubscription ? onNodeTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.07),
                    child: const Icon(Icons.hub_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node?.displayName ?? '尚未选择节点',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          node == null
                              ? '导入订阅后选择节点'
                              : '延迟  ${node.latency ?? '--'} ms',
                          style: const TextStyle(color: AppColors.success),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
