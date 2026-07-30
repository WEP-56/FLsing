import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme/flsing_theme.dart';

/// FLsing 抽屉体系。
///
/// - **Partial Drawer**（订阅 / 节点）：84% 高度，保留背景上下文
/// - **Full Drawer**（设置）：覆盖整页，独立页面体验
///
/// 这是 Flutter 明显优于 Web 的部分：拖拽手势、边缘返回、
/// 触觉反馈全部原生支持，Web 版都是手写模拟的。
class FlsingSheets {
  const FlsingSheets._();

  /// Partial Drawer —— 订阅、节点使用
  static Future<T?> partial<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    double heightFactor = 0.84,
  }) {
    final c = FlsingColors.of(context);

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: c.page.withValues(alpha: 0.58),
      elevation: 0,
      // 唯一使用 BackdropFilter 的位置之一
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: FractionallySizedBox(
          heightFactor: heightFactor,
          child: Container(
            decoration: BoxDecoration(
              color: c.sheet,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border(top: BorderSide(color: c.border2)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                const SheetHandle(),
                Expanded(child: builder(ctx)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Full Drawer —— 设置使用
  static Future<T?> full<T>(BuildContext context, {required Widget page}) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder(
        opaque: false,
        transitionDuration: Motion.normal,
        reverseTransitionDuration: Motion.normal,
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, anim, _, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
              .chain(CurveTween(curve: Motion.ease))
              .animate(anim),
          child: child,
        ),
      ),
    );
  }
}

/// 顶部拖拽把手
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 5,
      decoration: BoxDecoration(
        color: FlsingColors.of(context).border3,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

/* --------------------------------- 长按菜单 --------------------------------- */

class SheetMenuItem {
  const SheetMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
}

/// 长按 / 更多按钮弹出的操作菜单。
///
/// 订阅卡片的编辑、更新、复制、删除全部收在这里，
/// 保持列表本身干净 —— 「一步一个动作」。
Future<void> showFlsingMenu(
  BuildContext context, {
  required List<SheetMenuItem> items,
  required RelativeRect position,
}) async {
  final c = FlsingColors.of(context);

  final selected = await showMenu<int>(
    context: context,
    position: position,
    color: c.menu,
    elevation: 12,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: c.border2),
    ),
    items: [
      for (var i = 0; i < items.length; i++)
        PopupMenuItem(
          value: i,
          height: 44,
          child: Row(
            children: [
              Icon(
                items[i].icon,
                size: 16,
                color: items[i].danger ? c.danger : c.text3,
              ),
              const SizedBox(width: 12),
              Text(
                items[i].label,
                style: TextStyle(
                  fontSize: 13.5,
                  color: items[i].danger ? c.danger : c.text1,
                ),
              ),
            ],
          ),
        ),
    ],
  );

  if (selected != null) items[selected].onTap();
}

/// 从 Widget 计算菜单弹出位置的辅助方法
RelativeRect menuPositionFrom(BuildContext context) {
  final box = context.findRenderObject() as RenderBox;
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  final bottomRight =
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);
  return RelativeRect.fromLTRB(
    topLeft.dx,
    bottomRight.dy,
    overlay.size.width - bottomRight.dx,
    overlay.size.height - bottomRight.dy,
  );
}

/* -------------------------------- 二次确认对话框 -------------------------------- */

/// 删除类破坏性操作必须二次确认。
///
/// 返回 true 表示用户确认执行。
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '删除',
  String cancelLabel = '取消',
}) async {
  final c = FlsingColors.of(context);

  final result = await showDialog<bool>(
    context: context,
    barrierColor: c.page.withValues(alpha: 0.62),
    builder: (ctx) => Dialog(
      backgroundColor: c.dialog,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: c.border2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.text1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 13, height: 1.5, color: c.text3),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _DialogButton(
                    label: cancelLabel,
                    background: c.surface2,
                    foreground: c.text1,
                    onTap: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DialogButton(
                    label: confirmLabel,
                    background: c.dangerSoft,
                    foreground: c.danger,
                    onTap: () => Navigator.pop(ctx, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  return result ?? false;
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: 42,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
