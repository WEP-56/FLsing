import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme/flsing_theme.dart';
import '../../models/app_models.dart';

extension ProxyModeLabel on ProxyMode {
  String get label => switch (this) {
        ProxyMode.rule => '规则',
        ProxyMode.global => '全局',
        ProxyMode.direct => '直连',
      };

  IconData get icon => switch (this) {
        ProxyMode.rule => Icons.bolt_outlined,
        ProxyMode.global => Icons.public_outlined,
        ProxyMode.direct => Icons.link_outlined,
      };
}

/// 模式分段控件 —— 白色胶囊在三段间滑动。
///
/// 对应 Web 版 Framer Motion 的 `layoutId="modePill"`。
/// Flutter 里用 Stack + AnimatedAlign 实现，效果一致且更轻。
class ModeSelector extends StatelessWidget {
  const ModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ProxyMode value;
  final ValueChanged<ProxyMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = FlsingColors.of(context);
    const modes = ProxyMode.values;
    final index = modes.indexOf(value);

    return LayoutBuilder(
      builder: (context, box) {
        const pad = 4.0;
        final segW = (box.maxWidth - pad * 2) / modes.length;

        return Container(
          padding: const EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Stack(
            children: [
              // 滑动胶囊
              AnimatedAlign(
                duration: Motion.normal,
                curve: Motion.ease,
                alignment: Alignment(
                  modes.length == 1 ? 0 : (index / (modes.length - 1)) * 2 - 1,
                  0,
                ),
                child: Container(
                  width: segW,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.inverseBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              // 文字层
              Row(
                children: modes.map((m) {
                  final active = m == value;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(m),
                      child: SizedBox(
                        height: 36,
                        child: AnimatedDefaultTextStyle(
                          duration: Motion.fast,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: active ? c.inverseFg : c.text3,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                m.icon,
                                size: 15,
                                color: active ? c.inverseFg : c.text3,
                              ),
                              const SizedBox(width: 6),
                              Text(m.label),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
