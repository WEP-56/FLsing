import 'package:flutter_sing_box/flutter_sing_box.dart';

/// 应用自身的轻量设置存储（MMKV），与插件的 cs_profile / cs_settings 隔离。
class AppSettings {
  AppSettings._internal();
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;

  static KeyValueStorage? _storage;
  static KeyValueStorage get _store => _storage ??= MmkvStorage('flsing_app');

  /// 代理模式（ClashMode 常量值），未连接时的选择也会持久化。
  String get clashMode => _store.getString(_Keys.clashMode) ?? ClashMode.rule;
  set clashMode(String value) => _store.setString(_Keys.clashMode, value);

  /// 打开 app 时自动更新过期订阅。
  bool get autoUpdateSubscriptions =>
      _store.getBool(_Keys.autoUpdateSubscriptions, defaultValue: true);
  set autoUpdateSubscriptions(bool value) =>
      _store.setBool(_Keys.autoUpdateSubscriptions, value);

  /// 订阅视为过期的小时数。
  int get subscriptionStaleHours =>
      _store.getInt(_Keys.subscriptionStaleHours, defaultValue: 24);
  set subscriptionStaleHours(int value) =>
      _store.setInt(_Keys.subscriptionStaleHours, value);

  /// 规则库最近一次更新时间（毫秒时间戳，0 表示仍是内置版本）。
  int get ruleSetUpdatedAt => _store.getInt(_Keys.ruleSetUpdatedAt);
  set ruleSetUpdatedAt(int value) => _store.setInt(_Keys.ruleSetUpdatedAt, value);

  /// 延迟测速方法：smart（未连接直连、连接后走内核）/ direct（TCP 直连）/ proxy（内核实测）。
  String get latencyTestMethod =>
      _store.getString(_Keys.latencyTestMethod) ?? LatencyTestMethod.smart;
  set latencyTestMethod(String value) =>
      _store.setString(_Keys.latencyTestMethod, value);

  /// 主题模式：system / light / dark。
  String get themeMode => _store.getString(_Keys.themeMode) ?? ThemeModeOption.system;
  set themeMode(String value) => _store.setString(_Keys.themeMode, value);

  /// 内核 urltest 测速链接。
  static const defaultTestUrl = 'https://www.gstatic.com/generate_204';
  String get testUrl {
    final value = _store.getString(_Keys.testUrl);
    return (value == null || value.isEmpty) ? defaultTestUrl : value;
  }

  set testUrl(String value) => _store.setString(_Keys.testUrl, value.trim());
}

class ThemeModeOption {
  static const system = 'system';
  static const light = 'light';
  static const dark = 'dark';
}

class LatencyTestMethod {
  static const smart = 'smart';
  static const direct = 'direct';
  static const proxy = 'proxy';
}

class _Keys {
  static const clashMode = 'clash_mode';
  static const autoUpdateSubscriptions = 'auto_update_subscriptions';
  static const subscriptionStaleHours = 'subscription_stale_hours';
  static const ruleSetUpdatedAt = 'rule_set_updated_at';
  static const latencyTestMethod = 'latency_test_method';
  static const themeMode = 'theme_mode';
  static const testUrl = 'test_url';
}
