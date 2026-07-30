import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class DeviceService {
  static const _channel = MethodChannel('flsing/device');

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    return await _channel.invokeMethod<bool>(
          'isIgnoringBatteryOptimizations',
        ) ??
        false;
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('requestIgnoreBatteryOptimizations');
  }

  Future<void> shareTextFile({
    required String filename,
    required String content,
  }) async {
    if (!Platform.isAndroid) return;
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}shares',
    );
    await directory.create(recursive: true);
    final safeName = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${directory.path}${Platform.pathSeparator}$safeName');
    await file.writeAsString(content);
    await _channel.invokeMethod<void>('shareFile', {
      'path': file.path,
      'mimeType': 'text/plain',
      'title': '分享 FLsing 诊断信息',
    });
  }
}
