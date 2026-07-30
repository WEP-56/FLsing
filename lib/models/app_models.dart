enum ConnectionPhase { disconnected, connecting, connected, disconnecting }

enum ProxyMode { rule, global, direct }

/// IP 检测结果。
class IpInfo {
  const IpInfo({required this.ip, required this.region, required this.isExit});

  final String ip;
  final String region;

  /// true = 走代理的出口 IP，false = 本地 IP
  final bool isExit;
}

class ProxyNode {
  const ProxyNode({
    required this.id,
    required this.country,
    required this.flag,
    required this.name,
    required this.protocol,
    required this.transport,
    this.latency,
    this.testing = false,
  });

  final String id;
  final String country;
  final String flag;
  final String name;
  final String protocol;
  final String transport;
  final int? latency;
  final bool testing;

  String get displayName => country.isEmpty ? name : '$country | $name';

  ProxyNode copyWith({int? latency, bool? testing}) => ProxyNode(
    id: id,
    country: country,
    flag: flag,
    name: name,
    protocol: protocol,
    transport: transport,
    latency: latency ?? this.latency,
    testing: testing ?? this.testing,
  );
}

class SubscriptionItem {
  const SubscriptionItem({
    required this.id,
    required this.name,
    required this.url,
    required this.updatedAt,
    required this.nodeCount,
  });

  final String id;
  final String name;
  final String url;
  final DateTime updatedAt;
  final int nodeCount;

  SubscriptionItem copyWith({String? name, String? url, DateTime? updatedAt}) {
    return SubscriptionItem(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      updatedAt: updatedAt ?? this.updatedAt,
      nodeCount: nodeCount,
    );
  }
}
