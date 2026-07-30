import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_messenger.dart';
import '../../core/motion.dart';
import '../../core/theme/flsing_theme.dart';
import '../../models/app_models.dart';

/// IP 状态条 —— 位于 Header 下方的紧凑单行胶囊。
///
/// 刻意做成 36dp 高的窄条，不与地球争夺垂直空间。
/// 接第三方 IP 检测服务时，只需替换外部传入的 [info]。
///
/// 候选接口：ip-api.com（免 key）/ ip.sb / ipinfo.io / ipapi.co
class IpChip extends StatelessWidget {
  const IpChip({
    super.key,
    required this.info,
    required this.loading,
    required this.onRefresh,
    this.refreshing = false,
  });

  final IpInfo? info;
  final bool loading;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final c = FlsingColors.of(context);
    final exit = !loading && (info?.isExit ?? false);

    return Container(
      height: 36,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border1),
      ),
      child: Row(
        children: [
          _StatusDot(active: exit, loading: loading),
          const SizedBox(width: 8),
          Icon(
            exit ? Icons.verified_user_outlined : Icons.place_outlined,
            size: 12,
            color: c.text4,
          ),
          const SizedBox(width: 6),
          Text(exit ? '出口' : '本地',
              style: TextStyle(fontSize: 11, color: c.text4)),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.fast,
              child: loading
                  ? _Skeleton(key: const ValueKey('sk'), color: c.surface3)
                  : Row(
                      key: ValueKey(info?.ip),
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          info?.ip ?? '—',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: c.text1,
                            fontFeatures: kTabularFigures,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            info?.region ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10.5, color: c.text5),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          _IconBtn(
            icon: Icons.copy_outlined,
            enabled: !loading && info != null,
            onTap: () {
              Clipboard.setData(ClipboardData(text: info!.ip));
              showAppMessage('已复制 IP 地址');
            },
          ),
          _IconBtn(
            icon: Icons.refresh,
            enabled: !loading,
            spinning: refreshing,
            onTap: onRefresh,
          ),
        ],
      ),
    );
  }
}

/// 出口状态下带缓慢扩散的 ping 光环
class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.active, required this.loading});
  final bool active;
  final bool loading;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  // 不能用 late final 懒初始化：未连接时 build 不会触碰控制器，
  // dispose 里才首次创建会在卸载阶段查找祖先而崩溃。
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = FlsingColors.of(context);
    final color = widget.loading
        ? c.text6
        : widget.active
            ? c.accent
            : c.text4;

    return SizedBox(
      width: 7,
      height: 7,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (widget.active)
            AnimatedBuilder(
              animation: _c,
              builder: (_, _) => Transform.scale(
                scale: 1 + _c.value * 1.8,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.accent.withValues(alpha: 0.5 * (1 - _c.value)),
                  ),
                ),
              ),
            ),
          AnimatedContainer(
            duration: Motion.slow,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatefulWidget {
  const _Skeleton({super.key, required this.color});
  final Color color;

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 96,
          height: 9,
          color: widget.color,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Align(
              alignment: Alignment(_c.value * 2.4 - 1.2, 0),
              child: Container(
                width: 32,
                color: widget.color.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.spinning = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    final c = FlsingColors.of(context);
    Widget child = Icon(icon, size: 12.5, color: c.text4);

    if (spinning) {
      child = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        builder: (_, v, ch) =>
            Transform.rotate(angle: v * 6.28318, child: ch),
        child: child,
      );
    }

    return Opacity(
      opacity: enabled ? 1 : 0.3,
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: 16,
        child: SizedBox(width: 28, height: 28, child: Center(child: child)),
      ),
    );
  }
}
