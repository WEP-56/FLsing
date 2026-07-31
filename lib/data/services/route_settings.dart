enum RouteIpMode { dualStack, ipv4Only, ipv6Only }

enum RouteRuleMatch {
  domain,
  domainSuffix,
  domainKeyword,
  ipCidr,
  port,
  processName,
  packageName,
  wifiSsid,
  networkType,
  ipVersion,
}

enum RouteRuleAction { route, reject }

class RouteOverrideSettings {
  const RouteOverrideSettings({
    this.enabled = false,
    this.finalOutbound = '',
    this.autoDetectInterface = true,
    this.ipMode = RouteIpMode.dualStack,
    this.privateNetworkDirect = false,
    this.chinaRulesDirect = false,
    this.blockQuic = false,
    this.rules = const [],
  });

  final bool enabled;
  final String finalOutbound;
  final bool autoDetectInterface;
  final RouteIpMode ipMode;
  final bool privateNetworkDirect;
  final bool chinaRulesDirect;
  final bool blockQuic;
  final List<CustomRouteRule> rules;

  RouteOverrideSettings copyWith({
    bool? enabled,
    String? finalOutbound,
    bool? autoDetectInterface,
    RouteIpMode? ipMode,
    bool? privateNetworkDirect,
    bool? chinaRulesDirect,
    bool? blockQuic,
    List<CustomRouteRule>? rules,
  }) => RouteOverrideSettings(
    enabled: enabled ?? this.enabled,
    finalOutbound: finalOutbound ?? this.finalOutbound,
    autoDetectInterface: autoDetectInterface ?? this.autoDetectInterface,
    ipMode: ipMode ?? this.ipMode,
    privateNetworkDirect: privateNetworkDirect ?? this.privateNetworkDirect,
    chinaRulesDirect: chinaRulesDirect ?? this.chinaRulesDirect,
    blockQuic: blockQuic ?? this.blockQuic,
    rules: rules ?? this.rules,
  );

  factory RouteOverrideSettings.fromJson(Map<String, dynamic> json) =>
      RouteOverrideSettings(
        enabled: _bool(json['enabled'], false),
        finalOutbound: _string(json['finalOutbound']),
        autoDetectInterface: _bool(json['autoDetectInterface'], true),
        ipMode: _enumValue(
          RouteIpMode.values,
          json['ipMode'],
          RouteIpMode.dualStack,
        ),
        privateNetworkDirect: _bool(json['privateNetworkDirect'], false),
        chinaRulesDirect: _bool(json['chinaRulesDirect'], false),
        blockQuic: _bool(json['blockQuic'], false),
        rules: (json['rules'] as List? ?? const [])
            .map(_map)
            .whereType<Map<String, dynamic>>()
            .map(CustomRouteRule.fromJson)
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'finalOutbound': finalOutbound,
    'autoDetectInterface': autoDetectInterface,
    'ipMode': ipMode.name,
    'privateNetworkDirect': privateNetworkDirect,
    'chinaRulesDirect': chinaRulesDirect,
    'blockQuic': blockQuic,
    'rules': rules.map((rule) => rule.toJson()).toList(growable: false),
  };
}

class CustomRouteRule {
  const CustomRouteRule({
    this.enabled = true,
    this.match = RouteRuleMatch.domainSuffix,
    this.values = const [],
    this.action = RouteRuleAction.route,
    this.outbound = '',
  });

  final bool enabled;
  final RouteRuleMatch match;
  final List<String> values;
  final RouteRuleAction action;
  final String outbound;

  CustomRouteRule copyWith({
    bool? enabled,
    RouteRuleMatch? match,
    List<String>? values,
    RouteRuleAction? action,
    String? outbound,
  }) => CustomRouteRule(
    enabled: enabled ?? this.enabled,
    match: match ?? this.match,
    values: values ?? this.values,
    action: action ?? this.action,
    outbound: outbound ?? this.outbound,
  );

  factory CustomRouteRule.fromJson(Map<String, dynamic> json) =>
      CustomRouteRule(
        enabled: _bool(json['enabled'], true),
        match: _enumValue(
          RouteRuleMatch.values,
          json['match'],
          RouteRuleMatch.domainSuffix,
        ),
        values: (json['values'] as List? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        action: _enumValue(
          RouteRuleAction.values,
          json['action'],
          RouteRuleAction.route,
        ),
        outbound: _string(json['outbound']),
      );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'match': match.name,
    'values': values,
    'action': action.name,
    'outbound': outbound,
  };
}

T _enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) =>
    values.where((value) => value.name == raw).firstOrNull ?? fallback;

String _string(Object? value) => value is String ? value : '';

bool _bool(Object? value, bool fallback) => value is bool ? value : fallback;

Map<String, dynamic>? _map(Object? value) => value is Map<String, dynamic>
    ? value
    : value is Map
    ? Map<String, dynamic>.from(value)
    : null;

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
