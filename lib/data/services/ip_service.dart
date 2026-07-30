import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// 出口 / 本地 IP 查询。
///
/// 依次尝试多个免 key 服务，任一成功即返回：
/// 1. ip-api.com —— 支持中文地区名，但仅 http（已在网络安全配置中单独放行）；
/// 2. ipwho.is —— https，英文地区名，兜底。
///
/// 请求走系统网络栈：VPN 连接时自然测得出口 IP，未连接时测得本地 IP。
class IpService {
  IpService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 8);

  Future<({String ip, String region})?> fetch() async {
    return await _fromIpApi() ?? await _fromIpWhoIs();
  }

  Future<({String ip, String region})?> _fromIpApi() async {
    try {
      final response = await _client
          .get(
            Uri.parse(
              'http://ip-api.com/json/?lang=zh-CN&fields=status,query,country,city',
            ),
          )
          .timeout(_timeout);
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data['status'] != 'success') {
        return null;
      }
      final ip = data['query'] as String?;
      if (ip == null || ip.isEmpty) return null;
      return (
        ip: ip,
        region: _joinRegion(data['country'] as String?, data['city'] as String?),
      );
    } catch (_) {
      return null;
    }
  }

  Future<({String ip, String region})?> _fromIpWhoIs() async {
    try {
      final response = await _client
          .get(Uri.parse('https://ipwho.is/'))
          .timeout(_timeout);
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data['success'] != true) return null;
      final ip = data['ip'] as String?;
      if (ip == null || ip.isEmpty) return null;
      return (
        ip: ip,
        region: _joinRegion(data['country'] as String?, data['city'] as String?),
      );
    } catch (_) {
      return null;
    }
  }

  String _joinRegion(String? country, String? city) {
    final parts = <String>[
      if (country != null && country.trim().isNotEmpty) country,
      if (city != null && city.trim().isNotEmpty && city != country) city,
    ];
    return parts.join(' · ');
  }
}
