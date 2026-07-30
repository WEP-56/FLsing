import 'package:flutter/material.dart';

/// FLsing 色彩令牌。
///
/// 对应 Web 版 `src/index.css` 的 CSS 变量系统。
/// 表面色刻意写成**实色**而非半透明叠加 —— Flutter 的多层 alpha 混合
/// 与浏览器结果有细微差异，预先算好可避免层层叠加后的偏色。
@immutable
class FlsingColors extends ThemeExtension<FlsingColors> {
  const FlsingColors({
    required this.page,
    required this.frame,
    required this.sheet,
    required this.dialog,
    required this.menu,
    required this.stage,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.text4,
    required this.text5,
    required this.text6,
    required this.surface0,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.border1,
    required this.border2,
    required this.border3,
    required this.inverseBg,
    required this.inverseFg,
    required this.accent,
    required this.accentSoft,
    required this.warn,
    required this.danger,
    required this.dangerSoft,
    required this.globeCore,
    required this.globeDot,
    required this.globeLine,
  });

  // 结构层
  final Color page;    // 应用底色
  final Color frame;   // 设备边框（预览用）
  final Color sheet;   // 抽屉
  final Color dialog;  // 对话框
  final Color menu;    // 弹出菜单
  final Color stage;   // 预览舞台背景

  // 文字六级
  final Color text1, text2, text3, text4, text5, text6;

  // 表面四级
  final Color surface0, surface1, surface2, surface3;

  // 描边三级
  final Color border1, border2, border3;

  // 反色（选中胶囊 / 主按钮 / 开关）
  final Color inverseBg, inverseFg;

  // 语义色
  final Color accent, accentSoft, warn, danger, dangerSoft;

  // 地球专用
  final Color globeCore; // 中心状态舱底色
  final Color globeDot;  // 大陆点
  final Color globeLine; // 轨道 / 光环 / 卫星

  /* ------------------------------ 深色 ------------------------------ */

  static const dark = FlsingColors(
    page: Color(0xFF000000),
    frame: Color(0xFF101010),
    sheet: Color(0xFF0B0B0B),
    dialog: Color(0xFF151515),
    menu: Color(0xF2161616),
    stage: Color(0xFF060606),

    text1: Color(0xEDFFFFFF),
    text2: Color(0xB8FFFFFF),
    text3: Color(0x8CFFFFFF),
    text4: Color(0x66FFFFFF),
    text5: Color(0x4DFFFFFF),
    text6: Color(0x33FFFFFF),

    // 在 #000 上叠 2.8% / 4.8% / 7% / 12% 白的等效实色
    surface0: Color(0xFF070707),
    surface1: Color(0xFF0C0C0C),
    surface2: Color(0xFF121212),
    surface3: Color(0xFF1F1F1F),

    border1: Color(0x12FFFFFF),
    border2: Color(0x1FFFFFFF),
    border3: Color(0x40FFFFFF),

    inverseBg: Color(0xFFFFFFFF),
    inverseFg: Color(0xFF000000),

    accent: Color(0xFF30D158),
    accentSoft: Color(0x2130D158),
    warn: Color(0xFFF0B13C),
    danger: Color(0xFFF0524F),
    dangerSoft: Color(0x26F0524F),

    globeCore: Color(0x8C000000),
    globeDot: Color(0xFFE8E8E8),
    globeLine: Color(0xFFFFFFFF),
  );

  /* ------------------------------ 浅色 ------------------------------ */
  // 暖调纸白，避免纯白炫光；文字用暖近黑；强调绿加深以适应浅底。

  static const light = FlsingColors(
    page: Color(0xFFEAE8E3),
    frame: Color(0xFFD5D2CA),
    sheet: Color(0xFFF4F3EF),
    dialog: Color(0xFFFAF9F6),
    menu: Color(0xF5FAF9F6),
    stage: Color(0xFFDEDBD4),

    text1: Color(0xEB1A1915),
    text2: Color(0xB31A1915),
    text3: Color(0x8F1A1915),
    text4: Color(0x731A1915),
    text5: Color(0x591A1915),
    text6: Color(0x401A1915),

    // 在 #EAE8E3 上叠 3% / 5.2% / 7.5% / 11.5% 墨的等效实色
    surface0: Color(0xFFE4E2DD),
    surface1: Color(0xFFDFDDD8),
    surface2: Color(0xFFD9D7D2),
    surface3: Color(0xFFD0CEC8),

    border1: Color(0x171A1915),
    border2: Color(0x241A1915),
    border3: Color(0x471A1915),

    inverseBg: Color(0xFF1E1D19),
    inverseFg: Color(0xFFF5F4F0),

    accent: Color(0xFF178B3F),
    accentSoft: Color(0x21178B3F),
    warn: Color(0xFFA56A00),
    danger: Color(0xFFC0332C),
    dangerSoft: Color(0x1FC0332C),

    globeCore: Color(0x9EFFFFFF),
    globeDot: Color(0xFF2C2A24),
    globeLine: Color(0xFF1A1915),
  );

  static FlsingColors of(BuildContext context) =>
      Theme.of(context).extension<FlsingColors>() ?? dark;

  /// 延迟色标：<100ms 绿 / <150ms 琥珀 / 其余红 / null 灰
  Color latency(int? ms) {
    if (ms == null) return text5;
    if (ms < 100) return accent;
    if (ms < 150) return warn;
    return danger;
  }

  /// 信号格数：0–4
  static int latencyLevel(int? ms) {
    if (ms == null) return 0;
    if (ms < 100) return 4;
    if (ms < 150) return 3;
    return 2;
  }

  @override
  FlsingColors copyWith({
    Color? page,
    Color? frame,
    Color? sheet,
    Color? dialog,
    Color? menu,
    Color? stage,
    Color? text1,
    Color? text2,
    Color? text3,
    Color? text4,
    Color? text5,
    Color? text6,
    Color? surface0,
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? border1,
    Color? border2,
    Color? border3,
    Color? inverseBg,
    Color? inverseFg,
    Color? accent,
    Color? accentSoft,
    Color? warn,
    Color? danger,
    Color? dangerSoft,
    Color? globeCore,
    Color? globeDot,
    Color? globeLine,
  }) {
    return FlsingColors(
      page: page ?? this.page,
      frame: frame ?? this.frame,
      sheet: sheet ?? this.sheet,
      dialog: dialog ?? this.dialog,
      menu: menu ?? this.menu,
      stage: stage ?? this.stage,
      text1: text1 ?? this.text1,
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
      text4: text4 ?? this.text4,
      text5: text5 ?? this.text5,
      text6: text6 ?? this.text6,
      surface0: surface0 ?? this.surface0,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      border1: border1 ?? this.border1,
      border2: border2 ?? this.border2,
      border3: border3 ?? this.border3,
      inverseBg: inverseBg ?? this.inverseBg,
      inverseFg: inverseFg ?? this.inverseFg,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      warn: warn ?? this.warn,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      globeCore: globeCore ?? this.globeCore,
      globeDot: globeDot ?? this.globeDot,
      globeLine: globeLine ?? this.globeLine,
    );
  }

  /// 主题切换时整套色板自动插值 —— 这是 Web 版没有的能力。
  @override
  FlsingColors lerp(ThemeExtension<FlsingColors>? other, double t) {
    if (other is! FlsingColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return FlsingColors(
      page: c(page, other.page),
      frame: c(frame, other.frame),
      sheet: c(sheet, other.sheet),
      dialog: c(dialog, other.dialog),
      menu: c(menu, other.menu),
      stage: c(stage, other.stage),
      text1: c(text1, other.text1),
      text2: c(text2, other.text2),
      text3: c(text3, other.text3),
      text4: c(text4, other.text4),
      text5: c(text5, other.text5),
      text6: c(text6, other.text6),
      surface0: c(surface0, other.surface0),
      surface1: c(surface1, other.surface1),
      surface2: c(surface2, other.surface2),
      surface3: c(surface3, other.surface3),
      border1: c(border1, other.border1),
      border2: c(border2, other.border2),
      border3: c(border3, other.border3),
      inverseBg: c(inverseBg, other.inverseBg),
      inverseFg: c(inverseFg, other.inverseFg),
      accent: c(accent, other.accent),
      accentSoft: c(accentSoft, other.accentSoft),
      warn: c(warn, other.warn),
      danger: c(danger, other.danger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      globeCore: c(globeCore, other.globeCore),
      globeDot: c(globeDot, other.globeDot),
      globeLine: c(globeLine, other.globeLine),
    );
  }
}

/// 等宽数字 —— 对应 Web 的 `font-variant-numeric: tabular-nums`。
/// 计时器、延迟、IP 必须用，否则数字跳动时宽度会抖。
const kTabularFigures = <FontFeature>[FontFeature.tabularFigures()];
