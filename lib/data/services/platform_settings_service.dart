import 'package:flutter_sing_box/flutter_sing_box.dart';

/// Android settings consumed directly by flutter_sing_box's VPN service.
class PlatformSettingsService {
  static const _systemHttpProxyKey = 'system_proxy_enabled';
  static const _dynamicNotificationKey = 'dynamic_notification';

  final KeyValueStorage _store = MmkvStorage('cs_settings');

  bool get systemHttpProxyEnabled =>
      _store.getBool(_systemHttpProxyKey, defaultValue: true);
  set systemHttpProxyEnabled(bool value) =>
      _store.setBool(_systemHttpProxyKey, value);

  bool get dynamicNotificationEnabled =>
      _store.getBool(_dynamicNotificationKey, defaultValue: true);
  set dynamicNotificationEnabled(bool value) =>
      _store.setBool(_dynamicNotificationKey, value);
}
