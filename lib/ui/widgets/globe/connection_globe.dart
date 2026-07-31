import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/theme/flsing_theme.dart';
import 'globe_painter.dart';
import 'globe_points.dart';

enum ConnState { idle, connecting, connected }

/// 各状态的动画目标值 —— 与 Web 版数值完全一致。
class _Target {
  const _Target(this.speed, this.alpha, this.ring, this.halo, this.glow);
  final double speed, alpha, ring, halo, glow;

  static const idle = _Target(0.05, 0.42, 0.06, 0.0, 0.0);
  static const connecting = _Target(1.4, 0.9, 0.6, 1.0, 0.45);
  static const connected = _Target(0.22, 1.0, 0.9, 0.0, 1.0);

  static _Target of(ConnState s) => switch (s) {
    ConnState.idle => idle,
    ConnState.connecting => connecting,
    ConnState.connected => connected,
  };
}

/// 连接状态地球。
///
/// 三态：未连接（暗淡慢转）→ 连接中（光环扩散 + 加速自转）→ 已连接（稳定旋转）。
/// 状态间用指数缓动插值，不做硬切换。
class ConnectionGlobe extends StatefulWidget {
  const ConnectionGlobe({
    super.key,
    required this.state,
    required this.elapsed,
    this.onTap,
    this.assetPath = 'assets/earth_map.jpg',
    this.maxSize = 356,
  });

  final ConnState state;

  /// 已连接时长，由外部计时器提供
  final Duration elapsed;

  final VoidCallback? onTap;
  final String assetPath;
  final double maxSize;

  @override
  State<ConnectionGlobe> createState() => _ConnectionGlobeState();
}

class _ConnectionGlobeState extends State<ConnectionGlobe>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  Float32List? _points;

  // 累加量
  double _spin = 0.6;
  double _sat = 1.2;

  // 当前插值状态
  double _speed = 0.05;
  double _alpha = 0.42;
  double _ring = 0.06;
  double _halo = 0.0;
  double _glow = 0.0;

  // 扩散环
  final List<double> _halos = [];
  double _haloTimer = 0;

  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadPoints();
    _ticker = createTicker(_onTick)..start();
  }

  Future<void> _loadPoints() async {
    final pts = await GlobePoints.load(widget.assetPath);
    if (mounted) setState(() => _points = pts);
  }

  void _onTick(Duration now) {
    final dt = _last == Duration.zero
        ? 0.016
        : math.min(0.05, (now - _last).inMicroseconds / 1e6);
    _last = now;

    final t = _Target.of(widget.state);

    // 指数逼近：k = 1 - 0.004^dt，帧率无关
    final k = 1 - math.pow(0.004, dt).toDouble();
    _speed += (t.speed - _speed) * k;
    _alpha += (t.alpha - _alpha) * k;
    _ring += (t.ring - _ring) * k;
    _halo += (t.halo - _halo) * k;
    _glow += (t.glow - _glow) * k;

    _spin += _speed * dt;
    _sat += (0.35 + _speed * 0.8) * dt;

    // 连接中周期性放出扩散环
    if (_halo > 0.25) {
      _haloTimer += dt;
      if (_haloTimer > 0.85) {
        _halos.add(0);
        _haloTimer = 0;
      }
    }
    for (var i = _halos.length - 1; i >= 0; i--) {
      _halos[i] += dt / 1.5;
      if (_halos[i] >= 1) _halos.removeAt(i);
    }

    setState(() {});
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = FlsingColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.maxSize,
        maxHeight: widget.maxSize,
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: GlobePainter(
                  points: _points,
                  spin: _spin,
                  satAngle: _sat,
                  alpha: _alpha,
                  ring: _ring,
                  halo: _halo,
                  glow: _glow,
                  halos: List.unmodifiable(_halos),
                  colors: c,
                  isLight: isLight,
                ),
              ),
            ),
            _CenterCapsule(
              state: widget.state,
              elapsed: widget.elapsed,
              onTap: widget.onTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// 中心状态舱 —— 唯一使用 BackdropFilter 的地方之一。
///
/// 同时也是开始 / 断开连接的按钮：命中区域仅限这块圆片
/// （ClipOval 让命中检测跟随圆形），避免整个地球区域误触。
class _CenterCapsule extends StatelessWidget {
  const _CenterCapsule({
    required this.state,
    required this.elapsed,
    required this.onTap,
  });

  final ConnState state;
  final Duration elapsed;
  final VoidCallback? onTap;

  static String _fmt(Duration d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.inHours)}:${p(d.inMinutes % 60)}:${p(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = FlsingColors.of(context);

    return LayoutBuilder(
      builder: (context, box) {
        final d = box.maxHeight * 0.46;
        return SizedBox(
          width: d,
          height: d,
          child: ClipOval(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.globeCore,
                  border: Border.all(color: c.border2),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: switch (state) {
                    ConnState.connected => Column(
                      key: const ValueKey('connected'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '已连接',
                          style: TextStyle(fontSize: 11.5, color: c.text3),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _fmt(elapsed),
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.4,
                            color: c.text1,
                            fontFeatures: kTabularFigures,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SignalBars(level: 4, size: 10, color: c.accent),
                            const SizedBox(width: 6),
                            Text(
                              '稳定',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: c.accent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ConnState.connecting => Column(
                      key: const ValueKey('connecting'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: c.text2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '连接中',
                          style: TextStyle(fontSize: 11.5, color: c.text3),
                        ),
                      ],
                    ),
                    ConnState.idle => Column(
                      key: const ValueKey('idle'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '未连接',
                          style: TextStyle(fontSize: 12.5, color: c.text4),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '轻点这里开始连接',
                          style: TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 1.1,
                            color: c.text6,
                          ),
                        ),
                      ],
                    ),
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 信号柱 —— 对应 Web 版 MiniBars
class SignalBars extends StatelessWidget {
  const SignalBars({
    super.key,
    required this.level,
    this.size = 13,
    required this.color,
    this.inactiveColor,
  });

  final int level;
  final double size;
  final Color color;
  final Color? inactiveColor;

  static const _ratios = [0.36, 0.58, 0.79, 1.0];

  @override
  Widget build(BuildContext context) {
    final off = inactiveColor ?? FlsingColors.of(context).surface3;
    return SizedBox(
      height: size,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(4, (i) {
          return Container(
            width: 3,
            height: size * _ratios[i],
            margin: EdgeInsets.only(left: i == 0 ? 0 : 2.5),
            decoration: BoxDecoration(
              color: i < level ? color : off,
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        }),
      ),
    );
  }
}
