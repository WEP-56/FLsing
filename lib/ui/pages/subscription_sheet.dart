import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_messenger.dart';
import '../../core/motion.dart';
import '../../core/theme/flsing_theme.dart';
import '../../data/services/configuration_file_importer.dart';
import '../../models/app_models.dart';
import '../../providers/app_state.dart';
import '../widgets/flsing_sheets.dart';
import 'node_sheet.dart' show formatDateTime;

Future<void> showSubscriptionSheet(BuildContext context) {
  return FlsingSheets.partial(
    context,
    builder: (_) => const SubscriptionSheet(),
  );
}

class SubscriptionSheet extends StatefulWidget {
  const SubscriptionSheet({super.key});

  @override
  State<SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<SubscriptionSheet> {
  final DateTime _openedAt = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = FlsingColors.of(context);
    final subs = state.subscriptions;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
          child: Row(
            children: [
              Text(
                '订阅管理',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: c.text1,
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: '添加订阅',
                onSelected: _addSubscription,
                itemBuilder: (_) => [
                  _importMenuItem(c, 'link', Icons.link, '链接导入'),
                  _importMenuItem(c, 'clipboard', Icons.content_paste, '剪贴板'),
                  _importMenuItem(
                    c,
                    'file',
                    Icons.insert_drive_file_outlined,
                    '文件导入',
                  ),
                ],
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.surface2,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.border1),
                  ),
                  child: Icon(Icons.add, size: 20, color: c.text1),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: subs.isEmpty
              ? Center(
                  child: Text(
                    '还没有订阅，点右上角 + 导入',
                    style: TextStyle(fontSize: 13, color: c.text5),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                  itemCount: subs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => StaggeredEntrance(
                    index: index,
                    epoch: _openedAt,
                    child: _SubscriptionTile(item: subs[index]),
                  ),
                ),
        ),
        Padding(
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
              Text(
                '长按订阅项可快速操作',
                style: TextStyle(fontSize: 11.5, color: c.text5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _importMenuItem(
    FlsingColors c,
    String value,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 16, color: c.text3),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  Future<void> _addSubscription(String source) async {
    if (source == 'link') {
      await showSubscriptionForm(context);
    } else if (source == 'clipboard') {
      await _importClipboard();
    } else if (source == 'file') {
      await _importFile();
    }
  }

  Future<void> _importClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final value = data?.text?.trim() ?? '';
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) {
      showAppMessage('剪贴板中没有有效链接');
      return;
    }
    await showSubscriptionForm(context, initialUrl: value);
  }

  Future<void> _importFile() async {
    final path = await ConfigurationFileImporter().pickFile();
    if (!mounted || path == null) return;
    final state = context.read<AppState>();
    await state.addSubscriptionFile(File(path));
    final message = state.takeFeedback();
    if (message != null) showAppMessage(message);
  }
}

class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile({required this.item});

  final SubscriptionItem item;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = FlsingColors.of(context);
    final active = state.activeSubscription?.id == item.id;

    return Material(
      color: active ? c.surface2 : c.surface1,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: active
            ? null
            : () async {
                await state.activateSubscription(item.id);
                final message = state.takeFeedback();
                if (message != null) showAppMessage(message);
              },
        onLongPress: () => _showMenu(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? c.border2 : c.border1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: c.text1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: active ? c.accentSoft : c.surface2,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            active ? '已启用' : '未启用',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: active ? c.accent : c.text4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.text4),
                    ),
                    if (item.usedBytes != null || item.totalBytes != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _usageLabel(item),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: c.text3,
                          fontFeatures: kTabularFigures,
                        ),
                      ),
                    ],
                    if (item.expireAt != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        _expiryLabel(item.expireAt!),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: item.expireAt!.isBefore(DateTime.now())
                              ? c.danger
                              : c.text4,
                          fontFeatures: kTabularFigures,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '更新时间：${formatDateTime(item.updatedAt)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: c.text5,
                        fontFeatures: kTabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
              Builder(
                builder: (buttonContext) => InkResponse(
                  onTap: () => _showMenu(buttonContext),
                  radius: 18,
                  child: SizedBox(
                    width: 32,
                    height: 40,
                    child: Icon(Icons.more_vert, size: 17, color: c.text4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _usageLabel(SubscriptionItem item) {
    final used = item.usedBytes;
    final total = item.totalBytes;
    if (total != null && total > 0) {
      final percent = used == null ? null : (used / total * 100).clamp(0, 999);
      final progress = percent == null
          ? ''
          : ' (${percent.toStringAsFixed(1)}%)';
      return '已用 ${_formatBytes(used ?? 0)} / ${_formatBytes(total)}$progress';
    }
    return '上行 ${_formatBytes(item.uploadBytes ?? 0)} · 下行 ${_formatBytes(item.downloadBytes ?? 0)}';
  }

  String _expiryLabel(DateTime expiry) {
    final date =
        '${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}';
    return expiry.isBefore(DateTime.now()) ? '已于 $date 到期' : '到期：$date';
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final digits = value >= 100 || unit == 0 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[unit]}';
  }

  void _showMenu(BuildContext context) {
    final state = context.read<AppState>();
    showFlsingMenu(
      context,
      position: menuPositionFrom(context),
      items: [
        SheetMenuItem(
          icon: Icons.edit_outlined,
          label: '编辑',
          onTap: () => showSubscriptionForm(context, item: item),
        ),
        SheetMenuItem(
          icon: Icons.refresh,
          label: '更新',
          onTap: () async {
            await state.refreshSubscription(item.id);
            final message = state.takeFeedback();
            showAppMessage(message ?? '订阅已更新');
          },
        ),
        SheetMenuItem(
          icon: Icons.copy_outlined,
          label: '复制链接',
          onTap: () {
            Clipboard.setData(ClipboardData(text: item.url));
            showAppMessage('链接已复制');
          },
        ),
        SheetMenuItem(
          icon: Icons.delete_outline,
          label: '删除',
          danger: true,
          onTap: () => _confirmDelete(context),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final state = context.read<AppState>();
    if (state.subscriptions.length <= 1) {
      showAppMessage('至少保留一个订阅');
      return;
    }
    final approved = await confirmDestructive(
      context,
      title: '删除订阅？',
      message: '将删除“${item.name}”及其节点列表。此操作无法撤销。',
    );
    if (!approved) return;
    await state.deleteSubscription(item.id);
    final message = state.takeFeedback();
    if (message != null) showAppMessage(message);
  }
}

Future<bool> showSubscriptionForm(
  BuildContext context, {
  SubscriptionItem? item,
  String initialUrl = '',
}) async {
  final state = context.read<AppState>();
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _SubscriptionFormDialog(
      state: state,
      item: item,
      initialUrl: initialUrl,
    ),
  );
  return saved ?? false;
}

class _SubscriptionFormDialog extends StatefulWidget {
  const _SubscriptionFormDialog({
    required this.state,
    this.item,
    this.initialUrl = '',
  });

  final AppState state;
  final SubscriptionItem? item;
  final String initialUrl;

  @override
  State<_SubscriptionFormDialog> createState() =>
      _SubscriptionFormDialogState();
}

class _SubscriptionFormDialogState extends State<_SubscriptionFormDialog> {
  late final _nameController = TextEditingController(
    text: widget.item?.name ?? '',
  );
  late final _urlController = TextEditingController(
    text: widget.item?.url ?? widget.initialUrl,
  );
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    // 控制器归 State 管理，等对话框（含关闭动画）真正销毁后才释放。
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final item = widget.item;
    var success = true;
    if (item == null) {
      success = await widget.state.addSubscription(
        name: _nameController.text.trim(),
        url: _urlController.text.trim(),
      );
    } else {
      await widget.state.editSubscription(
        item.id,
        name: _nameController.text.trim(),
        url: _urlController.text.trim(),
      );
    }
    final message = widget.state.takeFeedback();
    if (message != null) showAppMessage(message);
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? '添加订阅' : '编辑订阅'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '名称'),
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? '请输入名称' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(labelText: '订阅链接'),
              keyboardType: TextInputType.url,
              validator: (value) {
                final uri = Uri.tryParse(value?.trim() ?? '');
                return uri != null && uri.hasScheme ? null : '请输入有效链接';
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}
