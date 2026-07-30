import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_messenger.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/configuration_file_importer.dart';
import '../../models/app_models.dart';
import '../../providers/app_state.dart';
import '../widgets/app_surfaces.dart';

Future<void> showSubscriptionSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.82,
      child: SubscriptionSheet(),
    ),
  );
}

class SubscriptionSheet extends StatefulWidget {
  const SubscriptionSheet({super.key});

  @override
  State<SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<SubscriptionSheet> {
  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Column(
        children: [
          const SheetHandle(),
          const SizedBox(height: 18),
          Row(
            children: [
              Text('订阅管理', style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: '添加订阅',
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                ),
                onSelected: _addSubscription,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'link',
                    child: ListTile(
                      leading: Icon(Icons.link),
                      title: Text('链接导入'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'clipboard',
                    child: ListTile(
                      leading: Icon(Icons.content_paste),
                      title: Text('剪贴板'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'file',
                    child: ListTile(
                      leading: Icon(Icons.insert_drive_file_outlined),
                      title: Text('文件导入'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: state.subscriptions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _SubscriptionTile(item: state.subscriptions[index]),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.info_outline, size: 17, color: AppColors.secondary),
              SizedBox(width: 8),
              Text(
                '长按订阅项可快速操作',
                style: TextStyle(color: AppColors.secondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addSubscription(String source) async {
    late final bool changed;
    if (source == 'link') {
      if (!mounted) return;
      changed = await _showSubscriptionForm(context);
    } else if (source == 'clipboard') {
      changed = await _importClipboard();
    } else if (source == 'file') {
      changed = await _importFile();
    } else {
      changed = false;
    }
    if (changed && mounted) setState(() {});
  }

  Future<bool> _importClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return false;
    final value = data?.text?.trim() ?? '';
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) {
      showAppMessage('剪贴板中没有有效链接');
      return false;
    }
    return _showSubscriptionForm(context, initialUrl: value);
  }

  Future<bool> _importFile() async {
    final path = await ConfigurationFileImporter().pickFile();
    if (!mounted || path == null) return false;
    final success = await context.read<AppState>().addSubscriptionFile(
      File(path),
    );
    if (!mounted) return false;
    final message = context.read<AppState>().takeFeedback();
    if (message != null) showAppMessage(message);
    return success;
  }
}

class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile({required this.item});
  final SubscriptionItem item;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final active = state.activeSubscription?.id == item.id;
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => state.activateSubscription(item.id),
        onLongPress: () => _showSubscriptionActions(context, item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.secondary),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '更新时间：${_formatDate(item.updatedAt)}',
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.success.withValues(alpha: 0.13)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  active ? '已启用' : '未启用',
                  style: TextStyle(
                    color: active ? AppColors.success : AppColors.secondary,
                    fontSize: 12,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '更多操作',
                onSelected: (value) => _handleAction(context, item, value),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'refresh', child: Text('更新')),
                  PopupMenuItem(value: 'copy', child: Text('复制链接')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

Future<void> _showSubscriptionActions(
  BuildContext context,
  SubscriptionItem item,
) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('编辑'),
            onTap: () {
              Navigator.pop(context);
              _showSubscriptionForm(context, item: item);
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('更新'),
            onTap: () {
              context.read<AppState>().refreshSubscription(item.id);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text('复制链接'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: item.url));
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.danger),
            title: const Text('删除', style: TextStyle(color: AppColors.danger)),
            onTap: () {
              Navigator.pop(context);
              _confirmDelete(context, item);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _handleAction(
  BuildContext context,
  SubscriptionItem item,
  String action,
) async {
  final state = context.read<AppState>();
  switch (action) {
    case 'edit':
      _showSubscriptionForm(context, item: item);
    case 'refresh':
      await state.refreshSubscription(item.id);
      if (!context.mounted) return;
      _showMessage(context, '订阅时间已更新');
    case 'copy':
      await Clipboard.setData(ClipboardData(text: item.url));
      if (context.mounted) _showMessage(context, '链接已复制');
    case 'delete':
      if (context.mounted) _confirmDelete(context, item);
  }
}

Future<void> _confirmDelete(BuildContext context, SubscriptionItem item) async {
  final approved = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('删除订阅？'),
      content: Text('将删除“${item.name}”。此操作无法撤销。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  if (approved == true && context.mounted) {
    await context.read<AppState>().deleteSubscription(item.id);
  }
}

Future<bool> _showSubscriptionForm(
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

void _showMessage(BuildContext context, String message) =>
    showAppMessage(message);
