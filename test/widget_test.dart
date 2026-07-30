import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flsing/app/app.dart';
import 'package:flsing/providers/app_state.dart';

void main() {
  Widget app() {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const FlsingApp(),
    );
  }

  testWidgets('home exposes primary controls', (tester) async {
    await tester.pumpWidget(app());
    expect(find.text('FLsing'), findsOneWidget);
    expect(find.text('添加订阅开始'), findsOneWidget);
    expect(find.text('规则'), findsOneWidget);
    expect(find.text('尚未选择节点'), findsOneWidget);
  });

  testWidgets('subscription sheet opens from header', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byTooltip('订阅管理'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('订阅管理'), findsOneWidget);
    expect(find.text('长按订阅项可快速操作'), findsOneWidget);
  });

  testWidgets('connection requires a subscription', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('添加订阅开始'));
    await tester.pump();
    expect(find.text('请先导入订阅'), findsOneWidget);
  });
}
