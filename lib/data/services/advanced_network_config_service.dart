import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'advanced_network_settings.dart';

abstract interface class ConfigurationValidator {
  Future<void> validate(String configuration);
}

class PlatformConfigurationValidator implements ConfigurationValidator {
  static const _channel = MethodChannel('flsing/configuration');

  @override
  Future<void> validate(String configuration) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('checkConfig', configuration);
  }
}

class AdvancedNetworkConfigService {
  const AdvancedNetworkConfigService();

  Map<String, dynamic> apply(
    Map<String, dynamic> source,
    AdvancedNetworkSettings settings,
  ) {
    validateSettings(settings);
    final config = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
    _applyDns(config, settings);
    _applyTun(config, settings);
    return config;
  }

  void validateSettings(AdvancedNetworkSettings settings) {
    if (settings.dnsMode == DnsOverrideMode.manual) {
      final uri = Uri.tryParse(settings.dnsServer.trim());
      final expectedScheme = settings.dnsTransport == DnsTransport.https
          ? 'https'
          : 'tls';
      if (uri == null ||
          uri.scheme != expectedScheme ||
          uri.host.isEmpty ||
          (uri.hasPort && (uri.port < 1 || uri.port > 65535))) {
        throw AdvancedNetworkSettingsException(
          settings.dnsTransport == DnsTransport.https
              ? 'DoH 地址必须是有效的 https:// 地址'
              : 'DoT 地址必须是有效的 tls:// 地址',
        );
      }
      if (settings.dnsTransport == DnsTransport.https && uri.path.isEmpty) {
        throw const AdvancedNetworkSettingsException('DoH 地址需要包含查询路径');
      }
    }
    final clientSubnet = settings.dnsClientSubnet.trim();
    if (clientSubnet.isNotEmpty && !_isCidr(clientSubnet)) {
      throw const AdvancedNetworkSettingsException('DNS 客户端子网不是有效的 CIDR');
    }
    if (!settings.tunEnabled) return;
    if (settings.tunMtu < 1280 || settings.tunMtu > 9000) {
      throw const AdvancedNetworkSettingsException(
        'TUN MTU 必须在 1280 到 9000 之间',
      );
    }
    if (settings.tunAddresses.isEmpty ||
        settings.tunAddresses.any((value) => !_isCidr(value))) {
      throw const AdvancedNetworkSettingsException('TUN 地址必须是有效的 CIDR');
    }
    if (settings.tunRouteExclusions.any((value) => !_isCidr(value))) {
      throw const AdvancedNetworkSettingsException('排除路由必须是有效的 CIDR');
    }
  }

  void _applyDns(
    Map<String, dynamic> config,
    AdvancedNetworkSettings settings,
  ) {
    if (settings.dnsMode == DnsOverrideMode.subscription) return;

    const systemTag = 'flsing-system';
    const upstreamTag = 'flsing-upstream';
    const fakeIpTag = 'flsing-fakeip';
    final route = _map(config['route']);
    final ruleSetTags = (route?['rule_set'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => item['tag'])
        .whereType<String>()
        .toSet();
    final servers = <Map<String, dynamic>>[
      {'tag': systemTag, 'type': 'local'},
      settings.dnsMode == DnsOverrideMode.manual
          ? _manualDnsServer(settings, upstreamTag, systemTag)
          : {'tag': upstreamTag, 'type': 'https', 'server': '223.5.5.5'},
      if (settings.dnsFakeIpEnabled)
        {
          'tag': fakeIpTag,
          'type': 'fakeip',
          'inet4_range': '198.18.0.0/15',
          'inet6_range': 'fc00::/18',
        },
    ];
    final rules = <Map<String, dynamic>>[
      if (settings.dnsFakeIpEnabled)
        {
          'clash_mode': 'global',
          'query_type': ['A', 'AAAA'],
          'action': 'route',
          'server': fakeIpTag,
        },
      {'clash_mode': 'direct', 'action': 'route', 'server': systemTag},
      if (ruleSetTags.contains('geoip-cn') &&
          ruleSetTags.contains('geosite-cn'))
        {
          'rule_set': ['geoip-cn', 'geosite-cn'],
          'action': 'route',
          'server': systemTag,
        },
    ];
    config['dns'] = <String, dynamic>{
      'servers': servers,
      'rules': rules,
      'final': upstreamTag,
      'strategy': _dnsStrategy(settings.dnsStrategy),
      'disable_cache': !settings.dnsCacheEnabled,
      'independent_cache': settings.dnsIndependentCache,
      if (settings.dnsClientSubnet.trim().isNotEmpty)
        'client_subnet': settings.dnsClientSubnet.trim(),
    };

    if (route != null) route['default_domain_resolver'] = systemTag;
  }

  Map<String, dynamic> _manualDnsServer(
    AdvancedNetworkSettings settings,
    String tag,
    String systemTag,
  ) {
    final uri = Uri.parse(settings.dnsServer.trim());
    final hostnameNeedsResolver = InternetAddress.tryParse(uri.host) == null;
    return <String, dynamic>{
      'tag': tag,
      'type': settings.dnsTransport.name,
      'server': uri.host,
      if (uri.hasPort) 'server_port': uri.port,
      if (settings.dnsTransport == DnsTransport.https)
        'path': uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path,
      if (hostnameNeedsResolver) 'domain_resolver': systemTag,
      'tls': <String, dynamic>{
        'enabled': true,
        if (hostnameNeedsResolver) 'server_name': uri.host,
      },
    };
  }

  void _applyTun(
    Map<String, dynamic> config,
    AdvancedNetworkSettings settings,
  ) {
    if (!settings.tunEnabled) return;
    final inbounds = config['inbounds'];
    if (inbounds is! List) {
      throw const AdvancedNetworkSettingsException('当前配置没有入站列表');
    }
    final tun = inbounds
        .whereType<Map>()
        .map(_map)
        .whereType<Map<String, dynamic>>()
        .where((item) => item['type'] == 'tun')
        .firstOrNull;
    if (tun == null) {
      throw const AdvancedNetworkSettingsException('当前配置不包含 TUN 入站');
    }
    tun['mtu'] = settings.tunMtu;
    tun['stack'] = settings.tunStack.name;
    tun['auto_route'] = settings.tunAutoRoute;
    tun['strict_route'] = settings.tunStrictRoute;
    tun['sniff'] = settings.tunSniff;
    tun['sniff_override_destination'] = settings.tunOverrideDestination;
    tun['address'] = settings.tunAddresses;
    if (settings.tunRouteExclusions.isEmpty) {
      tun.remove('route_exclude_address');
    } else {
      tun['route_exclude_address'] = settings.tunRouteExclusions;
    }
  }

  String _dnsStrategy(DnsStrategy strategy) => switch (strategy) {
    DnsStrategy.preferIpv4 => 'prefer_ipv4',
    DnsStrategy.preferIpv6 => 'prefer_ipv6',
    DnsStrategy.ipv4Only => 'ipv4_only',
    DnsStrategy.ipv6Only => 'ipv6_only',
  };

  bool _isCidr(String value) {
    final separator = value.lastIndexOf('/');
    if (separator <= 0) return false;
    final address = InternetAddress.tryParse(value.substring(0, separator));
    final prefix = int.tryParse(value.substring(separator + 1));
    if (address == null || prefix == null) return false;
    final maxPrefix = address.type == InternetAddressType.IPv4 ? 32 : 128;
    return prefix >= 0 && prefix <= maxPrefix;
  }

  Map<String, dynamic>? _map(Object? value) => value is Map<String, dynamic>
      ? value
      : value is Map
      ? Map<String, dynamic>.from(value)
      : null;
}

class AdvancedNetworkSettingsException implements Exception {
  const AdvancedNetworkSettingsException(this.message);
  final String message;

  @override
  String toString() => message;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
