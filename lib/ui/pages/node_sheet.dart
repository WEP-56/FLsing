import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_models.dart';
import '../../providers/app_state.dart';
import '../widgets/app_surfaces.dart';

Future<void> showNodeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) =>
        const FractionallySizedBox(heightFactor: 0.84, child: NodeSheet()),
  );
}

class NodeSheet extends StatefulWidget {
  const NodeSheet({super.key});

  @override
  State<NodeSheet> createState() => _NodeSheetState();
}

class _NodeSheetState extends State<NodeSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final nodes = state.nodes
        .where(
          (node) =>
              node.displayName.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        children: [
          const SheetHandle(),
          const SizedBox(height: 18),
          Row(
            children: [
              Text('节点管理', style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              if (state.isTestingAny)
                const Padding(
                  padding: EdgeInsets.all(11),
                  child: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                CircleIconButton(
                  icon: Icons.speed,
                  tooltip: '全部测速',
                  onPressed: state.testAllNodes,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '当前订阅：${state.activeSubscription?.name ?? '未选择'}',
              style: const TextStyle(color: AppColors.secondary),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: '搜索节点',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: nodes.isEmpty
                ? const Center(
                    child: Text(
                      '连接服务后将显示订阅中的节点',
                      style: TextStyle(color: AppColors.secondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: nodes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _NodeTile(node: nodes[index]),
                  ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 17,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  '测速方式可在设置中调整（智能 / 直连 / 代理）',
                  style: TextStyle(color: AppColors.secondary, fontSize: 12),
                ),
              ),
              TextButton.icon(
                onPressed: state.activeSubscription == null
                    ? null
                    : () => state.refreshSubscription(
                        state.activeSubscription!.id,
                      ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('更新节点'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({required this.node});
  final ProxyNode node;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selected = state.selectedNode?.id == node.id;
    final color = (node.latency ?? 999) < 100
        ? AppColors.success
        : (node.latency ?? 999) < 140
        ? AppColors.warning
        : AppColors.danger;
    return Material(
      color: Colors.white.withValues(alpha: selected ? 0.09 : 0.045),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: selected ? Colors.white54 : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => state.selectNode(node.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? Colors.white : AppColors.secondary,
              ),
              const SizedBox(width: 10),
              Text(node.flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${node.protocol}    ${node.transport}',
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (node.testing)
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  '${node.latency ?? '--'} ms',
                  style: TextStyle(color: color, fontWeight: FontWeight.w500),
                ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: state.isTestingAny
                    ? null
                    : () => state.testNode(node.id),
                tooltip: '测试延迟',
                icon: const Icon(Icons.speed, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
