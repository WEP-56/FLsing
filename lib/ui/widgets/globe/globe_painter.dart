import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/flsing_theme.dart';

/// 地球绘制器。
///
/// 与 Web 版 Canvas 2D 实现 1:1 对应，绘制顺序：
///   扩散光环 → 柔光 → 轨道环 → 追逐亮弧 → 卫星 → 球体 → 边缘光 → 大陆点
///
/// **性能要点**：Web 版逐点 `arc + fill`（数千次调用），Flutter 里改为
/// 按深度分 8 桶后 `drawRawPoints` 批绘，draw call 从数千降到 8。
class GlobePainter extends CustomPainter {
  GlobePainter({
    required this.points,
    required this.spin,
    required this.satAngle,
    required this.alpha,
    required this.ring,
    required this.halo,
    required this.glow,
    required this.halos,
    required this.colors,
    required this.isLight,
  });

  /// 点云 [x,y,z, ...]，单位球面坐标
  final Float32List? points;

  /// 自转角（弧度，持续累加）
  final double spin;

  /// 卫星在轨道上的角度
  final double satAngle;

  /// 整体不透明度 0–1
  final double alpha;

  /// 轨道环强度 0–1
  final double ring;

  /// 连接中强度 0–1（驱动扩散环与追逐亮弧）
  final double halo;

  /// 外部柔光强度 0–1
  final double glow;

  /// 进行中的扩散环进度列表，每项 0–1
  final List<double> halos;

  final FlsingColors colors;
  final bool isLight;

  /// 地轴倾角，与 Web 版一致
  static const _tilt = -0.42;
  static final _cosT = math.cos(_tilt);
  static final _sinT = math.sin(_tilt);

  /// 深度分桶数 —— 越多越平滑，越少 draw call 越少
  static const _buckets = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) * 0.335;
    final ringR = r * 1.3;

    // 浅色模式给个亮度下限，避免未连接时球体在纸白底上"消失"
    final a = isLight ? 0.55 + alpha * 0.45 : alpha;

    _paintHalos(canvas, c, r);
    _paintGlow(canvas, c, r);
    _paintOrbit(canvas, c, ringR);
    _paintChasingArc(canvas, c, ringR);
    _paintSatellite(canvas, c, ringR);
    _paintSphere(canvas, c, r, a);
    _paintRim(canvas, c, r, a);
    _paintDots(canvas, c, r, a);
  }

  /* ----------------------------- 扩散光环 ----------------------------- */

  void _paintHalos(Canvas canvas, Offset c, double r) {
    if (halos.isEmpty) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final t in halos) {
      final opacity = (1 - t) * (isLight ? 0.30 : 0.22) * halo;
      if (opacity <= 0.001) continue;
      paint.color = colors.globeLine.withValues(alpha: opacity);
      canvas.drawCircle(c, r * (1.05 + 0.62 * t), paint);
    }
  }

  /* ------------------------------ 外部柔光 ------------------------------ */

  void _paintGlow(Canvas canvas, Offset c, double r) {
    if (glow <= 0.02) return;
    final o = (isLight ? 0.06 : 0.05) * glow;
    final paint = Paint()
      ..shader = ui.Gradient.radial(c, r * 1.7, [
        colors.globeLine.withValues(alpha: o),
        colors.globeLine.withValues(alpha: 0),
      ], [
        0.35,
        1.0,
      ]);
    canvas.drawCircle(c, r * 1.7, paint);
  }

  /* ------------------------------ 轨道圆环 ------------------------------ */

  void _paintOrbit(Canvas canvas, Offset c, double ringR) {
    final base = isLight ? 0.08 : 0.05;
    final gain = isLight ? 0.16 : 0.13;
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = colors.globeLine.withValues(alpha: base + gain * ring),
    );
  }

  /* --------------------------- 卫星追逐亮弧 --------------------------- */

  void _paintChasingArc(Canvas canvas, Offset c, double ringR) {
    if (halo <= 0.05) return;
    final rect = Rect.fromCircle(center: c, radius: ringR);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    const segments = 26;
    const step = 0.055;
    for (var i = 0; i < segments; i++) {
      final a0 = satAngle - step * i;
      final o = (1 - i / segments) * (isLight ? 0.5 : 0.4) * halo;
      paint.color = colors.globeLine.withValues(alpha: o);
      canvas.drawArc(rect, a0 - step, step, false, paint);
    }
  }

  /* -------------------------------- 卫星 -------------------------------- */

  void _paintSatellite(Canvas canvas, Offset c, double ringR) {
    final p = Offset(
      c.dx + math.cos(satAngle) * ringR,
      c.dy + math.sin(satAngle) * ringR,
    );

    // 辉光
    canvas.drawCircle(
      p,
      11,
      Paint()
        ..shader = ui.Gradient.radial(p, 11, [
          colors.globeLine.withValues(alpha: 0.5 * ring + 0.08),
          colors.globeLine.withValues(alpha: 0),
        ]),
    );

    // 亮点
    canvas.drawCircle(
      p,
      2.1,
      Paint()..color = colors.globeLine.withValues(alpha: 0.25 + 0.75 * ring),
    );
  }

  /* ------------------------------- 球体本体 ------------------------------- */

  void _paintSphere(Canvas canvas, Offset c, double r, double a) {
    final core = isLight
        ? [
            const Color(0xFFFFFFFF),
            const Color(0xFFE8E6DF),
            const Color(0xFFD6D3CA),
          ]
        : [
            const Color(0xFF1C1C1C),
            const Color(0xFF0C0C0C),
            const Color(0xFF161616),
          ];

    // 光源偏左上，制造体积感
    final focal = c.translate(-r * 0.35, -r * 0.4);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          focal,
          r * 1.02,
          [
            core[0].withValues(alpha: 0.90 * a),
            core[1].withValues(alpha: 0.92 * a),
            core[2].withValues(alpha: 0.70 * a),
          ],
          [0.0, 0.75, 1.0],
        ),
    );
  }

  /* ------------------------------- 边缘光 ------------------------------- */

  void _paintRim(Canvas canvas, Offset c, double r, double a) {
    final rim = isLight ? const Color(0xFF1A1915) : const Color(0xFFFFFFFF);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..shader = ui.Gradient.linear(
          Offset(c.dx - r, c.dy - r),
          Offset(c.dx + r, c.dy + r),
          [
            rim.withValues(alpha: (isLight ? 0.16 : 0.22) * a),
            rim.withValues(alpha: 0.02),
            rim.withValues(alpha: 0.10 * a),
          ],
          [0.0, 0.45, 1.0],
        ),
    );
  }

  /* ------------------------------ 大陆点云 ------------------------------ */

  void _paintDots(Canvas canvas, Offset c, double r, double a) {
    final pts = points;
    if (pts == null || pts.isEmpty) return;

    final cosS = math.cos(spin);
    final sinS = math.sin(spin);
    final scale = r / 114; // 与 Web 版点径比例一致

    // 按深度分桶：同桶共用一个 Paint，一次 drawRawPoints 画完
    final buckets = List.generate(_buckets, (_) => <double>[]);

    for (var i = 0; i < pts.length; i += 3) {
      final x0 = pts[i];
      final y0 = pts[i + 1];
      final z0 = pts[i + 2];

      // 绕 Y 轴自转
      final x1 = x0 * cosS + z0 * sinS;
      final z1 = -x0 * sinS + z0 * cosS;

      // 地轴倾角
      final z2 = y0 * _sinT + z1 * _cosT;
      if (z2 < -0.25) continue; // 背面剔除
      final y1 = y0 * _cosT - z1 * _sinT;

      final depth = (z2 + 1) / 2;
      final b = (depth * (_buckets - 1)).clamp(0, _buckets - 1).toInt();
      buckets[b]
        ..add(c.dx + x1 * r)
        ..add(c.dy + y1 * r);
    }

    final paint = Paint()..strokeCap = StrokeCap.round;
    final dimming = isLight ? 0.82 : 1.0;

    for (var b = 0; b < _buckets; b++) {
      final bucket = buckets[b];
      if (bucket.isEmpty) continue;

      final depth = b / (_buckets - 1);
      paint
        ..color = colors.globeDot
            .withValues(alpha: a * (0.16 + 0.84 * depth * depth) * dimming)
        ..strokeWidth =
            math.max(0.8, 2.1 * scale * (0.5 + 0.6 * depth)); // 直径

      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.fromList(bucket),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(GlobePainter old) =>
      old.spin != spin ||
      old.satAngle != satAngle ||
      old.alpha != alpha ||
      old.ring != ring ||
      old.halo != halo ||
      old.glow != glow ||
      old.points != points ||
      old.colors != colors ||
      old.halos.length != halos.length;
}
