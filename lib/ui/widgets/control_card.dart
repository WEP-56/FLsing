import 'package:flutter/material.dart';

import '../../core/theme/flsing_theme.dart';
import '../../models/app_models.dart';
import 'globe/connection_globe.dart' show SignalBars;
import 'mode_selector.dart';

/// 首页控制卡片：模式切换 + 当前节点。
///
/// 严格遵循「Header → 地球 → 控制区」的固定结构，
/// 不添加流量统计、CPU、内存、日志等开发者视角信息。
class ControlCard extends StatelessWidget {
  const ControlCard({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.node,
    required this.onOpenNodes,
  });

  final ProxyMode mode;
  final ValueChanged<ProxyMode> onModeChanged;
  final ProxyNode? node;
  final VoidCallback onOpenNodes;

  @override
  Widget build(BuildContext context) {
    final c = FlsingColors.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: c.border1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('模式', style: TextStyle(fontSize: 12, color: c.text4)),
          const SizedBox(height: 8),
          ModeSelector(value: mode, onChanged: onModeChanged),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: c.border1),
          const SizedBox(height: 12),
          Text('当前节点', style: TextStyle(fontSize: 12, color: c.text4)),
          const SizedBox(height: 8),
          _NodeRow(node: node, onTap: onOpenNodes),
        ],
      ),
    );
  }
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({required this.node, required this.onTap});

  final ProxyNode? node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = FlsingColors.of(context);
    final n = node;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.surface2,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.hub_outlined, size: 18, color: c.text2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    n == null ? '暂无节点' : n.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: c.text1,
                    ),
                  ),
                  if (n != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text('延迟 ',
                            style: TextStyle(fontSize: 12, color: c.text4)),
                        Text(
                          n.latency == null ? '超时' : '${n.latency} ms',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: c.latency(n.latency),
                            fontFeatures: kTabularFigures,
                          ),
                        ),
                        const SizedBox(width: 6),
                        SignalBars(
                          level: FlsingColors.latencyLevel(n.latency),
                          size: 10,
                          color: c.latency(n.latency),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 19, color: c.text5),
          ],
        ),
      ),
    );
  }
}
