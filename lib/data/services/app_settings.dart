import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_sing_box/flutter_sing_box.dart';

import 'advanced_network_settings.dart';

/// 应用自身的轻量设置存储（MMKV），与插件的 cs_profile / cs_settings 隔离。
class AppSettings {
  AppSettings._internal();
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;

  static KeyValueStorage? _storage;
  static KeyValueStorage get _store => _storage ??= MmkvStorage('flsing_app');

  @visibleForTesting
  static void setStorageForTesting(KeyValueStorage? storage) {
    _storage = storage;
  }

  /// 代理模式（ClashMode 常量值），未连接时的选择也会持久化。
  String get clashMode => _store.getString(_Keys.clashMode) ?? ClashMode.rule;
  set clashMode(String value) => _store.setString(_Keys.clashMode, value);

  /// 打开 app 时自动更新过期订阅。
  bool get autoUpdateSubscriptions =>
      _store.getBool(_Keys.autoUpdateSubscriptions, defaultValue: true);
  set autoUpdateSubscriptions(bool value) =>
      _store.setBool(_Keys.autoUpdateSubscriptions, value);

  /// VPN 因内核或系统异常停止时是否自动重连。
  bool get autoReconnect =>
      _store.getBool(_Keys.autoReconnect, defaultValue: true);
  set autoReconnect(bool value) => _store.setBool(_Keys.autoReconnect, value);

  /// 应用完成初始化后，恢复上一次由用户发起的连接。
  bool get autoConnectOnLaunch =>
      _store.getBool(_Keys.autoConnectOnLaunch, defaultValue: false);
  set autoConnectOnLaunch(bool value) =>
      _store.setBool(_Keys.autoConnectOnLaunch, value);

  /// 用户上一次是否保持 VPN 连接。手动断开会清除该意图。
  bool get connectionRequested =>
      _store.getBool(_Keys.connectionRequested, defaultValue: false);
  set connectionRequested(bool value) =>
      _store.setBool(_Keys.connectionRequested, value);

  /// 订阅视为过期的小时数。
  int get subscriptionStaleHours =>
      _store.getInt(_Keys.subscriptionStaleHours, defaultValue: 24);
  set subscriptionStaleHours(int value) =>
      _store.setInt(_Keys.subscriptionStaleHours, value);

  /// 自动更新订阅时只允许使用 Wi-Fi。
  bool get subscriptionUpdatesOnWifiOnly =>
      _store.getBool(_Keys.subscriptionUpdatesOnWifiOnly, defaultValue: false);
  set subscriptionUpdatesOnWifiOnly(bool value) =>
      _store.setBool(_Keys.subscriptionUpdatesOnWifiOnly, value);

  /// 自动更新订阅失败后的额外尝试次数。
  int get subscriptionUpdateRetryCount =>
      _store.getInt(_Keys.subscriptionUpdateRetryCount, defaultValue: 2);
  set subscriptionUpdateRetryCount(int value) =>
      _store.setInt(_Keys.subscriptionUpdateRetryCount, value.clamp(0, 3));

  String? get lastSubscriptionUpdateError =>
      _store.getString(_Keys.lastSubscriptionUpdateError);
  set lastSubscriptionUpdateError(String? value) {
    if (value == null || value.isEmpty) {
      _store.removeValue(_Keys.lastSubscriptionUpdateError);
    } else {
      _store.setString(_Keys.lastSubscriptionUpdateError, value);
    }
  }

  /// 规则库最近一次更新时间（毫秒时间戳，0 表示仍是内置版本）。
  int get ruleSetUpdatedAt => _store.getInt(_Keys.ruleSetUpdatedAt);
  set ruleSetUpdatedAt(int value) =>
      _store.setInt(_Keys.ruleSetUpdatedAt, value);

  /// 延迟测速方法：smart（未连接直连、连接后走内核）/ direct（TCP 直连）/ proxy（内核实测）。
  String get latencyTestMethod =>
      _store.getString(_Keys.latencyTestMethod) ?? LatencyTestMethod.smart;
  set latencyTestMethod(String value) =>
      _store.setString(_Keys.latencyTestMethod, value);

  /// 主题模式：system / light / dark。
  String get themeMode =>
      _store.getString(_Keys.themeMode) ?? ThemeModeOption.system;
  set themeMode(String value) => _store.setString(_Keys.themeMode, value);

  /// 内核 urltest 测速链接。
  static const defaultTestUrl = 'https://www.gstatic.com/generate_204';
  String get testUrl {
    final value = _store.getString(_Keys.testUrl);
    return (value == null || value.isEmpty) ? defaultTestUrl : value;
  }

  set testUrl(String value) => _store.setString(_Keys.testUrl, value.trim());

  /// 用户自定义的订阅 User-Agent（预设之外的部分）。
  List<String> get customUserAgents {
    final raw = _store.getString(_Keys.customUserAgents);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final value = jsonDecode(raw);
      return value is List
          ? value.whereType<String>().toList(growable: false)
          : const [];
    } catch (_) {
      return const [];
    }
  }

  set customUserAgents(List<String> value) =>
      _store.setString(_Keys.customUserAgents, jsonEncode(value));

  /// 订阅绑定的 User-Agent（profileId → UA 原文）。绑定存原文而不是列表
  /// 索引，从列表里删除某个 UA 不影响已绑定的订阅。null 表示默认 UA。
  String? subscriptionUserAgentFor(int profileId) {
    final value = _subscriptionUserAgents['$profileId'];
    return (value == null || value.isEmpty) ? null : value;
  }

  void setSubscriptionUserAgentFor(int profileId, String? userAgent) {
    final map = _subscriptionUserAgents;
    final trimmed = userAgent?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      if (map.remove('$profileId') == null) return;
    } else {
      map['$profileId'] = trimmed;
    }
    _store.setString(_Keys.subscriptionUserAgents, jsonEncode(map));
  }

  Map<String, String> get _subscriptionUserAgents {
    final raw = _store.getString(_Keys.subscriptionUserAgents);
    if (raw == null || raw.isEmpty) return {};
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic>) return {};
      return value.map((key, item) => MapEntry(key, item.toString()));
    } catch (_) {
      return {};
    }
  }

  /// Internal authenticated Clash API port used for per-outbound URL tests.
  int get clashApiPort => _store.getInt(_Keys.clashApiPort);
  set clashApiPort(int value) => _store.setInt(_Keys.clashApiPort, value);

  /// Per-install secret for the loopback Clash API. It is never exported.
  String get clashApiSecret {
    final existing = _store.getString(_Keys.clashApiSecret);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final value = base64UrlEncode(
      List<int>.generate(24, (_) => random.nextInt(256), growable: false),
    ).replaceAll('=', '');
    _store.setString(_Keys.clashApiSecret, value);
    return value;
  }

  AdvancedNetworkSettings get advancedNetworkSettings {
    final raw = _store.getString(_Keys.advancedNetworkSettings);
    if (raw == null || raw.isEmpty) return const AdvancedNetworkSettings();
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic>
          ? AdvancedNetworkSettings.fromJson(value)
          : const AdvancedNetworkSettings();
    } catch (_) {
      return const AdvancedNetworkSettings();
    }
  }

  set advancedNetworkSettings(AdvancedNetworkSettings value) => _store
      .setString(_Keys.advancedNetworkSettings, jsonEncode(value.toJson()));
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
  static const autoReconnect = 'auto_reconnect';
  static const autoConnectOnLaunch = 'auto_connect_on_launch';
  static const connectionRequested = 'connection_requested';
  static const subscriptionStaleHours = 'subscription_stale_hours';
  static const subscriptionUpdatesOnWifiOnly =
      'subscription_updates_on_wifi_only';
  static const subscriptionUpdateRetryCount = 'subscription_update_retry_count';
  static const lastSubscriptionUpdateError = 'last_subscription_update_error';
  static const ruleSetUpdatedAt = 'rule_set_updated_at';
  static const latencyTestMethod = 'latency_test_method';
  static const themeMode = 'theme_mode';
  static const testUrl = 'test_url';
  static const clashApiPort = 'clash_api_port';
  static const clashApiSecret = 'clash_api_secret';
  static const advancedNetworkSettings = 'advanced_network_settings';
  static const customUserAgents = 'custom_user_agents';
  static const subscriptionUserAgents = 'subscription_user_agents';
}
