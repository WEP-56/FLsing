import 'dart:convert';
import 'dart:io';

import 'advanced_network_config_service.dart';
import 'advanced_network_settings.dart';
import 'app_settings.dart';
import 'per_app_proxy_service.dart';
import 'platform_settings_service.dart';

class SettingsBackupService {
  static const _schemaVersion = 1;

  final AppSettings _settings = AppSettings();
  final PerAppProxyService _perAppProxy = PerAppProxyService();
  final PlatformSettingsService _platform = PlatformSettingsService();

  String export() => const JsonEncoder.withIndent('  ').convert({
    'schemaVersion': _schemaVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'settings': {
      'clashMode': _settings.clashMode,
      'autoUpdateSubscriptions': _settings.autoUpdateSubscriptions,
      'subscriptionStaleHours': _settings.subscriptionStaleHours,
      'subscriptionUpdatesOnWifiOnly': _settings.subscriptionUpdatesOnWifiOnly,
      'subscriptionUpdateRetryCount': _settings.subscriptionUpdateRetryCount,
      'autoReconnect': _settings.autoReconnect,
      'autoConnectOnLaunch': _settings.autoConnectOnLaunch,
      'latencyTestMethod': _settings.latencyTestMethod,
      'themeMode': _settings.themeMode,
      'testUrl': _settings.testUrl,
      'advancedNetwork': _settings.advancedNetworkSettings.toJson(),
    },
    'platform': {
      'systemHttpProxyEnabled': _platform.systemHttpProxyEnabled,
      'dynamicNotificationEnabled': _platform.dynamicNotificationEnabled,
      'perAppProxyMode': _perAppProxy.mode.name,
      'perAppProxyPackages': _perAppProxy.selectedPackages,
    },
  });

  Future<SettingsRestoreResult> restore(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic> ||
        decoded['schemaVersion'] != _schemaVersion) {
      throw const SettingsBackupException('不是兼容的 FLsing 设置备份文件');
    }
    final settings = _map(decoded['settings']);
    final platform = _map(decoded['platform']);
    if (settings == null || platform == null) {
      throw const SettingsBackupException('设置备份文件不完整');
    }
    final advancedNetworkJson = _map(settings['advancedNetwork']);
    final advancedNetwork = advancedNetworkJson == null
        ? null
        : AdvancedNetworkSettings.fromJson(advancedNetworkJson);
    if (advancedNetwork != null) {
      const AdvancedNetworkConfigService().validateSettings(advancedNetwork);
    }

    _setString(settings, 'clashMode', (value) => _settings.clashMode = value);
    _setBool(
      settings,
      'autoUpdateSubscriptions',
      (value) => _settings.autoUpdateSubscriptions = value,
    );
    _setInt(
      settings,
      'subscriptionStaleHours',
      (value) => _settings.subscriptionStaleHours = value,
    );
    _setBool(
      settings,
      'subscriptionUpdatesOnWifiOnly',
      (value) => _settings.subscriptionUpdatesOnWifiOnly = value,
    );
    _setInt(
      settings,
      'subscriptionUpdateRetryCount',
      (value) => _settings.subscriptionUpdateRetryCount = value,
    );
    _setBool(
      settings,
      'autoReconnect',
      (value) => _settings.autoReconnect = value,
    );
    _setBool(
      settings,
      'autoConnectOnLaunch',
      (value) => _settings.autoConnectOnLaunch = value,
    );
    _setString(
      settings,
      'latencyTestMethod',
      (value) => _settings.latencyTestMethod = value,
    );
    _setString(settings, 'themeMode', (value) => _settings.themeMode = value);
    _setString(settings, 'testUrl', (value) => _settings.testUrl = value);

    _setBool(
      platform,
      'systemHttpProxyEnabled',
      (value) => _platform.systemHttpProxyEnabled = value,
    );
    _setBool(
      platform,
      'dynamicNotificationEnabled',
      (value) => _platform.dynamicNotificationEnabled = value,
    );
    final mode = _perAppMode(platform['perAppProxyMode']);
    final packages =
        (platform['perAppProxyPackages'] as List?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
    if (mode != null) _perAppProxy.save(mode: mode, packages: packages);

    return SettingsRestoreResult(
      themeMode: _settings.themeMode,
      advancedNetworkSettings: advancedNetwork,
    );
  }

  Map<String, dynamic>? _map(Object? value) => value is Map<String, dynamic>
      ? value
      : value is Map
      ? Map<String, dynamic>.from(value)
      : null;

  void _setBool(
    Map<String, dynamic> values,
    String key,
    void Function(bool) set,
  ) {
    final value = values[key];
    if (value is bool) set(value);
  }

  void _setInt(
    Map<String, dynamic> values,
    String key,
    void Function(int) set,
  ) {
    final value = values[key];
    if (value is num) set(value.toInt());
  }

  void _setString(
    Map<String, dynamic> values,
    String key,
    void Function(String) set,
  ) {
    final value = values[key];
    if (value is String && value.isNotEmpty) set(value);
  }

  PerAppProxyMode? _perAppMode(Object? value) => switch (value) {
    'disabled' => PerAppProxyMode.disabled,
    'include' => PerAppProxyMode.include,
    'exclude' => PerAppProxyMode.exclude,
    _ => null,
  };
}

class SettingsRestoreResult {
  const SettingsRestoreResult({
    required this.themeMode,
    this.advancedNetworkSettings,
  });
  final String themeMode;
  final AdvancedNetworkSettings? advancedNetworkSettings;
}

class SettingsBackupException implements Exception {
  const SettingsBackupException(this.message);
  final String message;

  @override
  String toString() => message;
}
