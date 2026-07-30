import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 8,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.052),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: size,
        child: IconButton.filledTonal(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          icon: Icon(icon, size: size * 0.5),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.07),
            shape: const CircleBorder(
              side: BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ),
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 48,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.white38,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class GlobeGraphic extends StatefulWidget {
  const GlobeGraphic({
    super.key,
    required this.active,
    required this.connecting,
    required this.center,
  });

  final bool active;
  final bool connecting;
  final Widget center;

  @override
  State<GlobeGraphic> createState() => _GlobeGraphicState();
}

class _GlobeGraphicState extends State<GlobeGraphic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          painter: _GlobePainter(
            progress: _controller.value,
            active: widget.active,
            connecting: widget.connecting,
          ),
          child: Center(child: widget.center),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _GlobePainter extends CustomPainter {
  _GlobePainter({
    required this.progress,
    required this.active,
    required this.connecting,
  });

  final double progress;
  final bool active;
  final bool connecting;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * 0.38;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: active ? 0.18 : 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.25));
    canvas.drawCircle(center, radius * 1.25, glow);

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: active ? 0.38 : 0.2);
    canvas.drawCircle(center, radius, outline);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 1.15, height: radius * 2),
      outline,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 1.82, height: radius * 2),
      outline,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 2, height: radius * 0.72),
      outline,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 2, height: radius * 1.42),
      outline,
    );

    final orbitRadius = radius * 1.2;
    canvas.drawCircle(
      center,
      orbitRadius,
      outline..color = Colors.white.withValues(alpha: 0.15),
    );
    final angle = progress * math.pi * 2;
    final dot =
        center +
        Offset(
          math.cos(angle) * orbitRadius,
          math.sin(angle) * orbitRadius * 0.42,
        );
    canvas.drawCircle(
      dot,
      connecting ? 6 : 4,
      Paint()..color = active ? AppColors.success : Colors.white70,
    );
  }

  @override
  bool shouldRepaint(covariant _GlobePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.active != active ||
      oldDelegate.connecting != connecting;
}
