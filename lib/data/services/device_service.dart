import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class DeviceService {
  static const _channel = MethodChannel('flsing/device');

  Future<List<InstalledApplication>> installedApplications() async {
    if (!Platform.isAndroid) return const [];
    final apps =
        await _channel.invokeListMethod<Map<Object?, Object?>>(
          'getInstalledApplications',
        ) ??
        const [];
    return apps
        .map(InstalledApplication.fromPlatformMap)
        .where((app) => app.packageName.isNotEmpty)
        .toList(growable: false);
  }

  Future<bool> isWifiConnection() async {
    if (!Platform.isAndroid) return true;
    return await _channel.invokeMethod<bool>('isWifiConnection') ?? false;
  }

  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    return await _channel.invokeMethod<bool>('requestNotificationPermission') ??
        false;
  }

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
    String title = '分享 FLsing 文件',
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
      'title': title,
    });
  }
}

class InstalledApplication {
  const InstalledApplication({
    required this.name,
    required this.packageName,
    required this.isSystem,
  });

  final String name;
  final String packageName;
  final bool isSystem;

  factory InstalledApplication.fromPlatformMap(Map<Object?, Object?> value) {
    return InstalledApplication(
      name: value['name'] as String? ?? '',
      packageName: value['packageName'] as String? ?? '',
      isSystem: value['isSystem'] as bool? ?? false,
    );
  }
}
