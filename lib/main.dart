import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mmkv/mmkv.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'providers/app_state.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // AppSettings（MMKV）在首帧前就会被 ThemeProvider 读取，提前初始化。
  if (Platform.isAndroid) await MMKV.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AppState()..initialize()),
      ],
      child: const FlsingApp(),
    ),
  );
}
