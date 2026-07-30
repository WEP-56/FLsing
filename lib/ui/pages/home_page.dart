import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_messenger.dart';
import '../../core/theme/flsing_theme.dart';
import '../../models/app_models.dart';
import '../../providers/app_state.dart';
import '../widgets/control_card.dart';
import '../widgets/flsing_sheets.dart';
import '../widgets/globe/connection_globe.dart';
import '../widgets/ip_chip.dart';
import 'node_sheet.dart';
import 'settings_page.dart';
import 'subscription_sheet.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  ConnState _connState(ConnectionPhase phase) => switch (phase) {
    ConnectionPhase.connected => ConnState.connected,
    ConnectionPhase.connecting ||
    ConnectionPhase.disconnecting => ConnState.connecting,
    ConnectionPhase.disconnected => ConnState.idle,
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              onSubscriptions: () => showSubscriptionSheet(context),
              onSettings: () => FlsingSheets.full(
                context,
                page: const SettingsPage(),
              ),
            ),
            IpChip(
              info: state.ipInfo,
              loading: state.ipLoading,
              refreshing: state.ipRefreshing,
              onRefresh: state.refreshIpInfo,
            ),
            Expanded(
              child: Center(
                child: ConnectionGlobe(
                  state: _connState(state.phase),
                  elapsed: state.connectedFor,
                  onTap: () async {
                    await state.toggleConnection();
                    final message = state.takeFeedback();
                    if (message != null) showAppMessage(message);
                  },
                ),
              ),
            ),
            ControlCard(
              mode: state.mode,
              onModeChanged: (mode) async {
                await state.selectMode(mode);
                final message = state.takeFeedback();
                if (message != null) showAppMessage(message);
              },
              node: state.selectedNode,
              onOpenNodes: () => showNodeSheet(context),
            ),
          ],
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
    final c = FlsingColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: Row(
        children: [
          Text(
            'FLsing',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: c.text1,
            ),
          ),
          const Spacer(),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: c.surface1,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: c.border1),
            ),
            child: Row(
              children: [
                _HeaderButton(
                  icon: Icons.layers_outlined,
                  tooltip: '订阅管理',
                  onTap: onSubscriptions,
                ),
                _HeaderButton(
                  icon: Icons.settings_outlined,
                  tooltip: '设置',
                  onTap: onSettings,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = FlsingColors.of(context);
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 19, color: c.text2),
        ),
      ),
    );
  }
}
