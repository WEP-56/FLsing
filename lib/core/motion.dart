import 'package:flutter/material.dart';

/// FLsing 动效常量。
///
/// 设计约束：慢、轻、自然，200–350ms。
/// 禁止弹跳、过度粒子、游戏化动画。
class Motion {
  const Motion._();

  /// 对应 Web 版 cubic-bezier(0.32, 0.72, 0, 1)
  /// 快出慢入，iOS 质感
  static const ease = Cubic(0.32, 0.72, 0, 1);

  static const fast = Duration(milliseconds: 200);
  static const normal = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 350);

  /// 抽屉弹簧 —— 对应 Web 的 spring(damping:31, stiffness:270)
  static const sheetSpring = SpringDescription(
    mass: 1,
    stiffness: 270,
    damping: 31,
  );

  /// 胶囊滑动 —— 对应 spring(stiffness:420, damping:34)
  static const pillSpring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 34,
  );

  /// 列表错峰入场的单项延迟
  static const stagger = Duration(milliseconds: 35);
}

/// 列表项错峰入场（淡入 + 上浮）。
///
/// 对应 Web 版 `initial={{opacity:0, y:16}}` + `delay: i * 0.035`。
///
/// **重要**：只在首次挂载时播放一次。Web 版曾因组件在父级重渲染时
/// 被重新创建而反复播放动画，Flutter 里用 StatefulWidget 持有
/// controller 可天然避免。
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.offset = 16,
    this.duration = Motion.slow,
  });

  final int index;
  final Widget child;
  final double offset;
  final Duration duration;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: Motion.ease,
  );

  @override
  void initState() {
    super.initState();
    final delay = Motion.stagger * widget.index + const Duration(milliseconds: 40);
    Future.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _a.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// 设置二级页转场 —— 横向滑入，对应 Web 版的 AnimatePresence 横滑。
/// 实际项目里直接用 Navigator 即可，自带边缘返回手势。
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  SlidePageRoute({required this.page})
      : super(
          transitionDuration: Motion.normal,
          reverseTransitionDuration: Motion.normal,
          pageBuilder: (_, _, _) => page,
          transitionsBuilder: (_, animation, secondary, child) {
            final slide = Tween(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Motion.ease)).animate(animation);

            // 上一页轻微左移，制造层级纵深
            final push = Tween(
              begin: Offset.zero,
              end: const Offset(-0.32, 0),
            ).chain(CurveTween(curve: Motion.ease)).animate(secondary);

            return SlideTransition(
              position: push,
              child: SlideTransition(position: slide, child: child),
            );
          },
        );

  final Widget page;
}
