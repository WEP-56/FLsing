import 'dart:convert';
import 'dart:io';

import 'package:flutter_sing_box/flutter_sing_box.dart' show FlutterSingBox;

import 'advanced_network_settings.dart';
import 'route_settings.dart';

abstract interface class ConfigurationValidator {
  Future<void> validate(String configuration);
}

class PlatformConfigurationValidator implements ConfigurationValidator {
  @override
  Future<void> validate(String configuration) async {
    if (!Platform.isAndroid) return;
    await FlutterSingBox().checkConfig(configuration);
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
    _applyRoute(config, settings.route);
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
    if (settings.tunEnabled) {
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
    _validateRouteSettings(settings.route);
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

  void _applyRoute(
    Map<String, dynamic> config,
    RouteOverrideSettings settings,
  ) {
    if (!settings.enabled) return;
    final route = _map(config['route']) ?? <String, dynamic>{};
    config['route'] = route;
    final originalRulesValue = route['rules'];
    if (originalRulesValue != null && originalRulesValue is! List) {
      throw const AdvancedNetworkSettingsException('当前配置没有路由规则列表');
    }
    final originalRules = originalRulesValue as List? ?? const <dynamic>[];
    final outboundTags = (config['outbounds'] as List? ?? const [])
        .whereType<Map>()
        .map((outbound) => outbound['tag'])
        .whereType<String>()
        .toSet();
    final ruleSetTags = (route['rule_set'] as List? ?? const [])
        .whereType<Map>()
        .map((ruleSet) => ruleSet['tag'])
        .whereType<String>()
        .toSet();

    final finalOutbound = settings.finalOutbound.trim();
    if (finalOutbound.isNotEmpty) route['final'] = finalOutbound;
    route['auto_detect_interface'] = settings.autoDetectInterface;
    final effectiveFinalOutbound = route['final'] is String
        ? (route['final'] as String).trim()
        : '';

    final managedRules = <Map<String, dynamic>>[
      if (settings.ipMode == RouteIpMode.ipv4Only)
        {'ip_version': 6, 'action': 'reject'},
      if (settings.ipMode == RouteIpMode.ipv6Only)
        {'ip_version': 4, 'action': 'reject'},
      if (settings.blockQuic)
        {
          'protocol': ['quic'],
          'action': 'reject',
        },
      if (settings.privateNetworkDirect)
        {'ip_is_private': true, 'action': 'route', 'outbound': 'direct'},
      if (settings.chinaRulesDirect)
        {
          'rule_set': ['geoip-cn', 'geosite-cn'],
          'action': 'route',
          'outbound': 'direct',
        },
      ...settings.rules
          .where((rule) => rule.enabled)
          .map((rule) => _routeRuleJson(rule, effectiveFinalOutbound)),
    ];

    final insertionIndex = originalRules
        .takeWhile((rule) => _isControlRule(_map(rule)))
        .length;
    final rules = List<dynamic>.from(originalRules)
      ..insertAll(insertionIndex, managedRules);
    route['rules'] = rules;

    if (settings.chinaRulesDirect &&
        (!ruleSetTags.contains('geoip-cn') ||
            !ruleSetTags.contains('geosite-cn'))) {
      throw const AdvancedNetworkSettingsException(
        '当前配置缺少 geoip-cn 或 geosite-cn 规则集',
      );
    }
    _validateRouteReferences(route, outboundTags, ruleSetTags);
  }

  void _validateRouteSettings(RouteOverrideSettings settings) {
    if (!settings.enabled) return;
    final enabledRules = settings.rules.where((rule) => rule.enabled).toList();
    for (var index = 0; index < enabledRules.length; index++) {
      final rule = enabledRules[index];
      final values = _validatedRuleValues(rule);
      if (rule.match == RouteRuleMatch.ipVersion &&
          values.contains('4') &&
          values.contains('6') &&
          index != enabledRules.length - 1) {
        throw const AdvancedNetworkSettingsException(
          '覆盖 IPv4 和 IPv6 的规则必须放在自定义规则末尾',
        );
      }
    }
  }

  List<String> _validatedRuleValues(CustomRouteRule rule) {
    final values = rule.values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (values.isEmpty) {
      throw const AdvancedNetworkSettingsException('自定义路由规则缺少匹配值');
    }
    switch (rule.match) {
      case RouteRuleMatch.ipCidr:
        if (values.any((value) => !_isCidr(value))) {
          throw const AdvancedNetworkSettingsException('路由 IP 地址必须是有效的 CIDR');
        }
      case RouteRuleMatch.port:
        for (final value in values) {
          _parsePort(value);
        }
      case RouteRuleMatch.ipVersion:
        if (values.any((value) => value != '4' && value != '6')) {
          throw const AdvancedNetworkSettingsException('IP 版本只能是 4 或 6');
        }
      case RouteRuleMatch.networkType:
        const types = {'wifi', 'cellular', 'ethernet', 'other'};
        if (values.any((value) => !types.contains(value.toLowerCase()))) {
          throw const AdvancedNetworkSettingsException(
            '网络类型只能是 wifi、cellular、ethernet 或 other',
          );
        }
      case RouteRuleMatch.domain:
      case RouteRuleMatch.domainSuffix:
      case RouteRuleMatch.domainKeyword:
      case RouteRuleMatch.packageName:
        if (values.any((value) => value.contains(RegExp(r'\s')))) {
          throw const AdvancedNetworkSettingsException('域名或包名不能包含空格');
        }
      case RouteRuleMatch.processName:
      case RouteRuleMatch.wifiSsid:
        break;
    }
    return values;
  }

  Map<String, dynamic> _routeRuleJson(
    CustomRouteRule rule,
    String defaultOutbound,
  ) {
    final values = _validatedRuleValues(rule);
    final selectedOutbound = rule.outbound.trim().isEmpty
        ? defaultOutbound
        : rule.outbound.trim();
    if (rule.action == RouteRuleAction.route && selectedOutbound.isEmpty) {
      throw const AdvancedNetworkSettingsException('当前配置没有可用的默认出口');
    }
    final result = <String, dynamic>{
      'action': rule.action == RouteRuleAction.reject ? 'reject' : 'route',
      if (rule.action == RouteRuleAction.route) 'outbound': selectedOutbound,
    };
    switch (rule.match) {
      case RouteRuleMatch.domain:
        result['domain'] = values;
      case RouteRuleMatch.domainSuffix:
        result['domain_suffix'] = values;
      case RouteRuleMatch.domainKeyword:
        result['domain_keyword'] = values;
      case RouteRuleMatch.ipCidr:
        result['ip_cidr'] = values;
      case RouteRuleMatch.port:
        final ports = <int>[];
        final ranges = <String>[];
        for (final value in values) {
          final parsed = _parsePort(value);
          if (parsed.port != null) {
            ports.add(parsed.port!);
          } else {
            ranges.add('${parsed.start}-${parsed.end}');
          }
        }
        if (ports.isNotEmpty) result['port'] = ports;
        if (ranges.isNotEmpty) result['port_range'] = ranges;
      case RouteRuleMatch.processName:
        result['process_name'] = values;
      case RouteRuleMatch.packageName:
        result['package_name'] = values;
      case RouteRuleMatch.wifiSsid:
        result['wifi_ssid'] = values;
      case RouteRuleMatch.networkType:
        result['network_type'] = values
            .map((value) => value.toLowerCase())
            .toList(growable: false);
      case RouteRuleMatch.ipVersion:
        if (values.length == 1) {
          result['ip_version'] = int.parse(values.single);
        } else {
          result['type'] = 'logical';
          result['mode'] = 'or';
          result['rules'] = values
              .map((value) => <String, dynamic>{'ip_version': int.parse(value)})
              .toList(growable: false);
        }
    }
    return result;
  }

  ({int? port, int? start, int? end}) _parsePort(String value) {
    final port = int.tryParse(value);
    if (port != null && port >= 1 && port <= 65535) {
      return (port: port, start: null, end: null);
    }
    final parts = value.split('-');
    if (parts.length == 2) {
      final start = int.tryParse(parts[0]);
      final end = int.tryParse(parts[1]);
      if (start != null &&
          end != null &&
          start >= 1 &&
          end <= 65535 &&
          start <= end) {
        return (port: null, start: start, end: end);
      }
    }
    throw const AdvancedNetworkSettingsException('端口必须是 1-65535 的数值或有效范围');
  }

  bool _isControlRule(Map<String, dynamic>? rule) {
    if (rule == null) return false;
    if (rule['clash_mode'] != null) return true;
    final action = rule['action'];
    return action != null && action != 'route';
  }

  void _validateRouteReferences(
    Map<String, dynamic> route,
    Set<String> outboundTags,
    Set<String> ruleSetTags,
  ) {
    final finalOutbound = route['final'];
    if (finalOutbound is String &&
        finalOutbound.isNotEmpty &&
        !outboundTags.contains(finalOutbound)) {
      throw AdvancedNetworkSettingsException('默认出口不存在：$finalOutbound');
    }
    final rules = route['rules'];
    if (rules is! List) return;
    for (final value in rules) {
      final rule = _map(value);
      if (rule == null) continue;
      final outbound = rule['outbound'];
      if (outbound is String && !outboundTags.contains(outbound)) {
        throw AdvancedNetworkSettingsException('路由规则引用了不存在的出口：$outbound');
      }
      final ruleSets = rule['rule_set'];
      if (ruleSets is List) {
        final missing = ruleSets
            .whereType<String>()
            .where((tag) => !ruleSetTags.contains(tag))
            .firstOrNull;
        if (missing != null) {
          throw AdvancedNetworkSettingsException('路由规则引用了不存在的规则集：$missing');
        }
      }
      final nested = rule['rules'];
      if (nested is List) {
        _validateRouteReferences({'rules': nested}, outboundTags, ruleSetTags);
      }
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
