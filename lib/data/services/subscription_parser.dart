import 'dart:convert';

/// 解析“分享链接”类订阅（vmess:// 列表，可能整体 base64 编码），
/// 输出 sing-box 原生 outbound JSON。
///
/// flutter_sing_box 1.1.4 自带的转换器不支持 vmess/vless/ss，
/// 且会把明文链接列表误判为 YAML，所以这一步在 app 层完成。
class SubscriptionParser {
  static final _linkPattern = RegExp(
    r'^(vmess|vless|trojan|ss|hysteria2|hy2|hysteria|tuic|anytls)://',
  );

  /// 返回解析出的节点列表；返回 null 表示正文不是分享链接订阅
  /// （可能是 sing-box JSON 或 Clash YAML，交回给插件处理）。
  static List<Map<String, dynamic>>? parse(String body) {
    final links = _extractLinks(body);
    if (links.isEmpty) return null;
    final nodes = <Map<String, dynamic>>[];
    final usedTags = <String>{};
    for (final link in links) {
      final node = _parseLink(link);
      if (node == null) continue;
      var tag = (node['tag'] as String?)?.trim() ?? '';
      if (tag.isEmpty) tag = '${node['server']}:${node['server_port']}';
      var unique = tag;
      var counter = 2;
      while (!usedTags.add(unique)) {
        unique = '$tag ${counter++}';
      }
      node['tag'] = unique;
      nodes.add(node);
    }
    return nodes;
  }

  static List<String> _extractLinks(String body) {
    var text = body.trim();
    if (!text.contains('://')) {
      final decoded = _tryBase64(text);
      if (decoded == null) return const [];
      text = decoded;
    }
    return text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where(_linkPattern.hasMatch)
        .toList();
  }

  static String? _tryBase64(String input) {
    var value = input
        .replaceAll(RegExp(r'\s'), '')
        .replaceAll('-', '+')
        .replaceAll('_', '/');
    if (value.isEmpty) return null;
    final padding = value.length % 4;
    if (padding == 1) return null;
    if (padding > 0) value += '=' * (4 - padding);
    try {
      return utf8.decode(base64.decode(value), allowMalformed: true);
    } on FormatException {
      return null;
    }
  }

  static Map<String, dynamic>? _parseLink(String link) {
    try {
      final scheme = link.substring(0, link.indexOf('://')).toLowerCase();
      switch (scheme) {
        case 'vmess':
          return _parseVmess(link);
        case 'vless':
          return _parseVless(Uri.parse(link));
        case 'trojan':
          return _parseTrojan(Uri.parse(link));
        case 'ss':
          return _parseShadowsocks(link);
        case 'hysteria2':
        case 'hy2':
          return _parseHysteria2(Uri.parse(link));
        case 'hysteria':
          return _parseHysteria(Uri.parse(link));
        case 'tuic':
          return _parseTuic(Uri.parse(link));
        case 'anytls':
          return _parseAnytls(Uri.parse(link));
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  // vmess://base64({"v":"2","ps":...,"add":...,...})
  static Map<String, dynamic>? _parseVmess(String link) {
    final payload = _tryBase64(link.substring('vmess://'.length));
    if (payload == null) return null;
    final value = jsonDecode(payload);
    if (value is! Map<String, dynamic>) return null;
    final server = value['add']?.toString() ?? '';
    final port = int.tryParse(value['port']?.toString() ?? '');
    final uuid = value['id']?.toString() ?? '';
    if (server.isEmpty || port == null || uuid.isEmpty) return null;
    final host = value['host']?.toString() ?? '';
    final sni = value['sni']?.toString() ?? '';
    final node = <String, dynamic>{
      'type': 'vmess',
      'tag': value['ps']?.toString() ?? '',
      'server': server,
      'server_port': port,
      'uuid': uuid,
      'alter_id': int.tryParse(value['aid']?.toString() ?? '') ?? 0,
      'security': (value['scy']?.toString().isNotEmpty ?? false)
          ? value['scy'].toString()
          : 'auto',
    };
    if (value['tls']?.toString() == 'tls') {
      node['tls'] = _tls(
        serverName: sni.isNotEmpty ? sni : (host.isNotEmpty ? host : server),
        alpn: value['alpn']?.toString(),
      );
    }
    final transport = _transport(
      network: value['net']?.toString() ?? 'tcp',
      path: value['path']?.toString(),
      host: host,
    );
    if (transport != null) node['transport'] = transport;
    return node;
  }

  static Map<String, dynamic>? _parseVless(Uri uri) {
    if (uri.userInfo.isEmpty || uri.host.isEmpty) return null;
    final query = uri.queryParameters;
    final node = <String, dynamic>{
      'type': 'vless',
      'tag': Uri.decodeComponent(uri.fragment),
      'server': uri.host,
      'server_port': uri.port,
      'uuid': uri.userInfo,
      'packet_encoding': 'xudp',
    };
    final flow = query['flow'];
    if (flow?.isNotEmpty ?? false) node['flow'] = flow;
    final security = query['security'] ?? '';
    if (security == 'tls' || security == 'reality') {
      final tls = _tls(
        serverName: query['sni'] ?? uri.host,
        alpn: query['alpn'],
        insecure: query['allowInsecure'] == '1',
        fingerprint: query['fp'],
      );
      if (security == 'reality') {
        tls['reality'] = {
          'enabled': true,
          'public_key': query['pbk'] ?? '',
          'short_id': query['sid'] ?? '',
        };
      }
      node['tls'] = tls;
    }
    final transport = _transport(
      network: query['type'] ?? 'tcp',
      path: query['path'],
      host: query['host'],
      serviceName: query['serviceName'],
    );
    if (transport != null) node['transport'] = transport;
    return node;
  }

  static Map<String, dynamic>? _parseTrojan(Uri uri) {
    if (uri.userInfo.isEmpty || uri.host.isEmpty) return null;
    final query = uri.queryParameters;
    final node = <String, dynamic>{
      'type': 'trojan',
      'tag': Uri.decodeComponent(uri.fragment),
      'server': uri.host,
      'server_port': uri.port,
      'password': Uri.decodeComponent(uri.userInfo),
      'tls': _tls(
        serverName: query['sni'] ?? query['peer'] ?? uri.host,
        alpn: query['alpn'],
        insecure: query['allowInsecure'] == '1',
      ),
    };
    final transport = _transport(
      network: query['type'] ?? 'tcp',
      path: query['path'],
      host: query['host'],
      serviceName: query['serviceName'],
    );
    if (transport != null) node['transport'] = transport;
    return node;
  }

  // 兼容 SIP002（ss://base64(method:pass)@host:port#tag）
  // 与旧格式（ss://base64(method:pass@host:port)#tag）。
  static Map<String, dynamic>? _parseShadowsocks(String link) {
    var body = link.substring('ss://'.length);
    String tag = '';
    final hashIndex = body.indexOf('#');
    if (hashIndex != -1) {
      tag = Uri.decodeComponent(body.substring(hashIndex + 1));
      body = body.substring(0, hashIndex);
    }
    final queryIndex = body.indexOf('?');
    if (queryIndex != -1) body = body.substring(0, queryIndex);

    String userInfo;
    String hostPort;
    final atIndex = body.lastIndexOf('@');
    if (atIndex == -1) {
      final decoded = _tryBase64(body);
      if (decoded == null) return null;
      final decodedAt = decoded.lastIndexOf('@');
      if (decodedAt == -1) return null;
      userInfo = decoded.substring(0, decodedAt);
      hostPort = decoded.substring(decodedAt + 1);
    } else {
      userInfo = Uri.decodeComponent(body.substring(0, atIndex));
      hostPort = body.substring(atIndex + 1);
    }
    if (!userInfo.contains(':')) {
      final decoded = _tryBase64(userInfo);
      if (decoded == null || !decoded.contains(':')) return null;
      userInfo = decoded;
    }
    final splitIndex = userInfo.indexOf(':');
    final method = userInfo.substring(0, splitIndex);
    final password = userInfo.substring(splitIndex + 1);
    final portIndex = hostPort.lastIndexOf(':');
    if (portIndex == -1) return null;
    final server = hostPort.substring(0, portIndex);
    final port = int.tryParse(hostPort.substring(portIndex + 1));
    if (server.isEmpty || port == null) return null;
    return {
      'type': 'shadowsocks',
      'tag': tag,
      'server': server,
      'server_port': port,
      'method': method,
      'password': password,
    };
  }

  static Map<String, dynamic>? _parseHysteria2(Uri uri) {
    if (uri.host.isEmpty) return null;
    final query = uri.queryParameters;
    final node = <String, dynamic>{
      'type': 'hysteria2',
      'tag': Uri.decodeComponent(uri.fragment),
      'server': uri.host,
      'server_port': uri.port,
      'password': Uri.decodeComponent(uri.userInfo),
      'tls': _tls(
        serverName: query['sni'] ?? uri.host,
        alpn: query['alpn'] ?? 'h3',
        insecure: query['insecure'] == '1' || query['allowInsecure'] == '1',
      ),
    };
    final mport = query['mport'];
    if (mport?.isNotEmpty ?? false) {
      node['server_ports'] = [mport!.replaceAll('-', ':')];
    }
    return node;
  }

  static Map<String, dynamic>? _parseHysteria(Uri uri) {
    if (uri.host.isEmpty) return null;
    final query = uri.queryParameters;
    return {
      'type': 'hysteria',
      'tag': Uri.decodeComponent(uri.fragment),
      'server': uri.host,
      'server_port': uri.port,
      'auth_str': query['auth'] ?? '',
      'up_mbps': int.tryParse(query['upmbps'] ?? '') ?? 50,
      'down_mbps': int.tryParse(query['downmbps'] ?? '') ?? 100,
      'disable_mtu_discovery': true,
      'tls': _tls(
        serverName: query['peer'] ?? query['sni'] ?? uri.host,
        alpn: query['alpn'] ?? 'h3',
        insecure: query['insecure'] == '1' || query['allowInsecure'] == '1',
      ),
    };
  }

  static Map<String, dynamic>? _parseTuic(Uri uri) {
    if (uri.host.isEmpty) return null;
    final query = uri.queryParameters;
    final userInfo = Uri.decodeComponent(uri.userInfo);
    final splitIndex = userInfo.indexOf(':');
    return {
      'type': 'tuic',
      'tag': Uri.decodeComponent(uri.fragment),
      'server': uri.host,
      'server_port': uri.port,
      'uuid': splitIndex == -1 ? userInfo : userInfo.substring(0, splitIndex),
      'password': splitIndex == -1 ? '' : userInfo.substring(splitIndex + 1),
      'congestion_control': query['congestion_control'] ?? 'cubic',
      'tls': _tls(
        serverName: query['sni'] ?? uri.host,
        alpn: query['alpn'] ?? 'h3',
        insecure: query['insecure'] == '1' || query['allowInsecure'] == '1',
      ),
    };
  }

  static Map<String, dynamic>? _parseAnytls(Uri uri) {
    if (uri.host.isEmpty) return null;
    final query = uri.queryParameters;
    return {
      'type': 'anytls',
      'tag': Uri.decodeComponent(uri.fragment),
      'server': uri.host,
      'server_port': uri.port,
      'password': Uri.decodeComponent(uri.userInfo),
      'tls': _tls(
        serverName: query['sni'] ?? query['peer'] ?? uri.host,
        insecure: query['insecure'] == '1' || query['allowInsecure'] == '1',
      ),
    };
  }

  static Map<String, dynamic> _tls({
    required String serverName,
    String? alpn,
    bool insecure = false,
    String? fingerprint,
  }) {
    final tls = <String, dynamic>{
      'enabled': true,
      'server_name': serverName,
      'insecure': insecure,
    };
    if (alpn?.isNotEmpty ?? false) tls['alpn'] = alpn!.split(',');
    if (fingerprint?.isNotEmpty ?? false) {
      tls['utls'] = {'enabled': true, 'fingerprint': fingerprint};
    }
    return tls;
  }

  static Map<String, dynamic>? _transport({
    required String network,
    String? path,
    String? host,
    String? serviceName,
  }) {
    switch (network) {
      case 'ws':
        return {
          'type': 'ws',
          'path': (path?.isNotEmpty ?? false) ? path : '/',
          if (host?.isNotEmpty ?? false)
            'headers': {'Host': host},
        };
      case 'grpc':
        return {
          'type': 'grpc',
          'service_name': (serviceName?.isNotEmpty ?? false)
              ? serviceName
              : (path ?? ''),
        };
      case 'h2':
      case 'http':
        return {
          'type': 'http',
          if (path?.isNotEmpty ?? false) 'path': path,
          if (host?.isNotEmpty ?? false) 'host': host!.split(','),
        };
      case 'httpupgrade':
        return {
          'type': 'httpupgrade',
          if (path?.isNotEmpty ?? false) 'path': path,
          if (host?.isNotEmpty ?? false) 'host': host,
        };
      default:
        return null;
    }
  }
}
