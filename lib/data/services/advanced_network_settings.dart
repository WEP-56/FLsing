import 'route_settings.dart';

enum DnsOverrideMode { subscription, flsing, manual }

enum DnsTransport { https, tls }

enum DnsStrategy { preferIpv4, preferIpv6, ipv4Only, ipv6Only }

enum TunStack { system, gvisor, mixed }

class AdvancedNetworkSettings {
  const AdvancedNetworkSettings({
    this.dnsMode = DnsOverrideMode.subscription,
    this.dnsTransport = DnsTransport.https,
    this.dnsServer = 'https://1.1.1.1/dns-query',
    this.dnsStrategy = DnsStrategy.preferIpv4,
    this.dnsCacheEnabled = true,
    this.dnsIndependentCache = true,
    this.dnsFakeIpEnabled = true,
    this.dnsClientSubnet = '',
    this.tunEnabled = false,
    this.tunMtu = 1400,
    this.tunStack = TunStack.system,
    this.tunAutoRoute = true,
    this.tunStrictRoute = true,
    this.tunSniff = false,
    this.tunOverrideDestination = false,
    this.tunAddresses = const ['172.19.0.1/30', 'fdfe:dcba:9876::1/126'],
    this.tunRouteExclusions = const [],
    this.route = const RouteOverrideSettings(),
  });

  final DnsOverrideMode dnsMode;
  final DnsTransport dnsTransport;
  final String dnsServer;
  final DnsStrategy dnsStrategy;
  final bool dnsCacheEnabled;
  final bool dnsIndependentCache;
  final bool dnsFakeIpEnabled;
  final String dnsClientSubnet;
  final bool tunEnabled;
  final int tunMtu;
  final TunStack tunStack;
  final bool tunAutoRoute;
  final bool tunStrictRoute;
  final bool tunSniff;
  final bool tunOverrideDestination;
  final List<String> tunAddresses;
  final List<String> tunRouteExclusions;
  final RouteOverrideSettings route;

  AdvancedNetworkSettings copyWith({
    DnsOverrideMode? dnsMode,
    DnsTransport? dnsTransport,
    String? dnsServer,
    DnsStrategy? dnsStrategy,
    bool? dnsCacheEnabled,
    bool? dnsIndependentCache,
    bool? dnsFakeIpEnabled,
    String? dnsClientSubnet,
    bool? tunEnabled,
    int? tunMtu,
    TunStack? tunStack,
    bool? tunAutoRoute,
    bool? tunStrictRoute,
    bool? tunSniff,
    bool? tunOverrideDestination,
    List<String>? tunAddresses,
    List<String>? tunRouteExclusions,
    RouteOverrideSettings? route,
  }) => AdvancedNetworkSettings(
    dnsMode: dnsMode ?? this.dnsMode,
    dnsTransport: dnsTransport ?? this.dnsTransport,
    dnsServer: dnsServer ?? this.dnsServer,
    dnsStrategy: dnsStrategy ?? this.dnsStrategy,
    dnsCacheEnabled: dnsCacheEnabled ?? this.dnsCacheEnabled,
    dnsIndependentCache: dnsIndependentCache ?? this.dnsIndependentCache,
    dnsFakeIpEnabled: dnsFakeIpEnabled ?? this.dnsFakeIpEnabled,
    dnsClientSubnet: dnsClientSubnet ?? this.dnsClientSubnet,
    tunEnabled: tunEnabled ?? this.tunEnabled,
    tunMtu: tunMtu ?? this.tunMtu,
    tunStack: tunStack ?? this.tunStack,
    tunAutoRoute: tunAutoRoute ?? this.tunAutoRoute,
    tunStrictRoute: tunStrictRoute ?? this.tunStrictRoute,
    tunSniff: tunSniff ?? this.tunSniff,
    tunOverrideDestination:
        tunOverrideDestination ?? this.tunOverrideDestination,
    tunAddresses: tunAddresses ?? this.tunAddresses,
    tunRouteExclusions: tunRouteExclusions ?? this.tunRouteExclusions,
    route: route ?? this.route,
  );

  factory AdvancedNetworkSettings.fromJson(Map<String, dynamic> json) =>
      AdvancedNetworkSettings(
        dnsMode: _enumValue(
          DnsOverrideMode.values,
          json['dnsMode'],
          DnsOverrideMode.subscription,
        ),
        dnsTransport: _enumValue(
          DnsTransport.values,
          json['dnsTransport'],
          DnsTransport.https,
        ),
        dnsServer: _string(json['dnsServer'], 'https://1.1.1.1/dns-query'),
        dnsStrategy: _enumValue(
          DnsStrategy.values,
          json['dnsStrategy'],
          DnsStrategy.preferIpv4,
        ),
        dnsCacheEnabled: _bool(json['dnsCacheEnabled'], true),
        dnsIndependentCache: _bool(json['dnsIndependentCache'], true),
        dnsFakeIpEnabled: _bool(json['dnsFakeIpEnabled'], true),
        dnsClientSubnet: _string(json['dnsClientSubnet'], ''),
        tunEnabled: _bool(json['tunEnabled'], false),
        tunMtu: _int(json['tunMtu'], 1400),
        tunStack: _enumValue(
          TunStack.values,
          json['tunStack'],
          TunStack.system,
        ),
        tunAutoRoute: _bool(json['tunAutoRoute'], true),
        tunStrictRoute: _bool(json['tunStrictRoute'], true),
        tunSniff: _bool(json['tunSniff'], false),
        tunOverrideDestination: _bool(json['tunOverrideDestination'], false),
        tunAddresses: _stringList(json['tunAddresses'], const [
          '172.19.0.1/30',
          'fdfe:dcba:9876::1/126',
        ]),
        tunRouteExclusions: _stringList(json['tunRouteExclusions'], const []),
        route: _map(json['route']) == null
            ? const RouteOverrideSettings()
            : RouteOverrideSettings.fromJson(_map(json['route'])!),
      );

  Map<String, dynamic> toJson() => {
    'dnsMode': dnsMode.name,
    'dnsTransport': dnsTransport.name,
    'dnsServer': dnsServer,
    'dnsStrategy': dnsStrategy.name,
    'dnsCacheEnabled': dnsCacheEnabled,
    'dnsIndependentCache': dnsIndependentCache,
    'dnsFakeIpEnabled': dnsFakeIpEnabled,
    'dnsClientSubnet': dnsClientSubnet,
    'tunEnabled': tunEnabled,
    'tunMtu': tunMtu,
    'tunStack': tunStack.name,
    'tunAutoRoute': tunAutoRoute,
    'tunStrictRoute': tunStrictRoute,
    'tunSniff': tunSniff,
    'tunOverrideDestination': tunOverrideDestination,
    'tunAddresses': tunAddresses,
    'tunRouteExclusions': tunRouteExclusions,
    'route': route.toJson(),
  };

  static T _enumValue<T extends Enum>(
    List<T> values,
    Object? raw,
    T fallback,
  ) => values.where((value) => value.name == raw).firstOrNull ?? fallback;

  static String _string(Object? value, String fallback) =>
      value is String ? value : fallback;
  static bool _bool(Object? value, bool fallback) =>
      value is bool ? value : fallback;
  static int _int(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;
  static List<String> _stringList(Object? value, List<String> fallback) =>
      value is List ? value.whereType<String>().toList() : fallback;
  static Map<String, dynamic>? _map(Object? value) =>
      value is Map<String, dynamic>
      ? value
      : value is Map
      ? Map<String, dynamic>.from(value)
      : null;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
