import 'package:flutter/material.dart';

import '../../core/theme/flsing_theme.dart';

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
    final c = FlsingColors.of(context);
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: size,
        child: IconButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          icon: Icon(icon, size: size * 0.45, color: c.text2),
          style: IconButton.styleFrom(
            backgroundColor: c.surface2,
            shape: CircleBorder(side: BorderSide(color: c.border1)),
          ),
        ),
      ),
    );
  }
}
