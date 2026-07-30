import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_messenger.dart';
import '../core/theme/app_theme.dart';
import '../ui/pages/home_page.dart';

class FlsingApp extends StatelessWidget {
  const FlsingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FLsing',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.dark,
      home: const HomePage(),
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: AppColors.background,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
          child: child!,
        );
      },
    );
  }
}
