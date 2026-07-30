import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_messenger.dart';
import '../core/theme/app_theme.dart';
import '../providers/theme_provider.dart';
import '../ui/pages/home_page.dart';

class FlsingApp extends StatelessWidget {
  const FlsingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().mode;
    return MaterialApp(
      title: 'FLsing',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const HomePage(),
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        final colors = FlsingColors.of(context);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value:
              (brightness == Brightness.dark
                      ? SystemUiOverlayStyle.light
                      : SystemUiOverlayStyle.dark)
                  .copyWith(
                    statusBarColor: Colors.transparent,
                    systemNavigationBarColor: colors.page,
                    systemNavigationBarDividerColor: Colors.transparent,
                  ),
          child: child!,
        );
      },
    );
  }
}
