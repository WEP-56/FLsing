import 'package:flutter_test/flutter_test.dart';
import 'package:flsing/data/services/advanced_network_config_service.dart';
import 'package:flsing/data/services/advanced_network_settings.dart';

void main() {
  const service = AdvancedNetworkConfigService();

  group('AdvancedNetworkSettings', () {
    test('round trips through JSON', () {
      const settings = AdvancedNetworkSettings(
        dnsMode: DnsOverrideMode.manual,
        dnsTransport: DnsTransport.tls,
        dnsServer: 'tls://dns.example:853',
        dnsStrategy: DnsStrategy.ipv6Only,
        dnsCacheEnabled: false,
        dnsIndependentCache: false,
        dnsFakeIpEnabled: false,
        dnsClientSubnet: '2001:db8::/48',
        tunEnabled: true,
        tunMtu: 1500,
        tunStack: TunStack.mixed,
        tunAutoRoute: true,
        tunStrictRoute: false,
        tunSniff: true,
        tunOverrideDestination: true,
        tunAddresses: ['10.10.0.1/30'],
        tunRouteExclusions: ['192.168.0.0/16'],
      );

      final restored = AdvancedNetworkSettings.fromJson(settings.toJson());

      expect(restored.toJson(), settings.toJson());
    });

    test('uses safe defaults for unknown enum values', () {
      final settings = AdvancedNetworkSettings.fromJson({
        'dnsMode': 'unknown',
        'tunStack': 'unknown',
      });

      expect(settings.dnsMode, DnsOverrideMode.subscription);
      expect(settings.tunStack, TunStack.system);
      expect(settings.tunEnabled, isFalse);
    });
  });

  group('AdvancedNetworkConfigService', () {
    test('subscription DNS mode leaves DNS untouched', () {
      final source = _baseConfig();

      final patched = service.apply(source, const AdvancedNetworkSettings());

      expect(patched['dns'], source['dns']);
      expect(patched, isNot(same(source)));
    });

    test('builds the FLsing DNS preset with valid references', () {
      final patched = service.apply(
        _baseConfig(),
        const AdvancedNetworkSettings(dnsMode: DnsOverrideMode.flsing),
      );
      final dns = patched['dns'] as Map<String, dynamic>;
      final servers = (dns['servers'] as List).cast<Map<String, dynamic>>();
      final rules = (dns['rules'] as List).cast<Map<String, dynamic>>();

      expect(dns['final'], 'flsing-upstream');
      expect(dns['strategy'], 'prefer_ipv4');
      expect(
        servers.map((item) => item['tag']),
        containsAll(['flsing-system', 'flsing-upstream', 'flsing-fakeip']),
      );
      expect(
        rules,
        contains(
          predicate<Map<String, dynamic>>(
            (rule) =>
                rule['server'] == 'flsing-system' && rule['rule_set'] is List,
          ),
        ),
      );
      expect(
        (patched['route'] as Map<String, dynamic>)['default_domain_resolver'],
        'flsing-system',
      );
    });

    test('maps a hostname DoH URL to a bootstrapped server', () {
      final patched = service.apply(
        _baseConfig(),
        const AdvancedNetworkSettings(
          dnsMode: DnsOverrideMode.manual,
          dnsServer: 'https://dns.example:8443/dns-query',
        ),
      );
      final dns = patched['dns'] as Map<String, dynamic>;
      final server = (dns['servers'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((item) => item['tag'] == 'flsing-upstream');

      expect(server['type'], 'https');
      expect(server['server'], 'dns.example');
      expect(server['server_port'], 8443);
      expect(server['path'], '/dns-query');
      expect(server['domain_resolver'], 'flsing-system');
      expect(
        (server['tls'] as Map<String, dynamic>)['server_name'],
        'dns.example',
      );
    });

    test('applies all supported TUN fields', () {
      final patched = service.apply(
        _baseConfig(),
        const AdvancedNetworkSettings(
          tunEnabled: true,
          tunMtu: 1500,
          tunStack: TunStack.gvisor,
          tunAutoRoute: true,
          tunStrictRoute: false,
          tunSniff: true,
          tunOverrideDestination: true,
          tunAddresses: ['10.20.0.1/30', 'fd00::1/126'],
          tunRouteExclusions: ['192.168.0.0/16'],
        ),
      );
      final tun = (patched['inbounds'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((item) => item['type'] == 'tun');

      expect(tun['mtu'], 1500);
      expect(tun['stack'], 'gvisor');
      expect(tun['strict_route'], isFalse);
      expect(tun['sniff'], isTrue);
      expect(tun['sniff_override_destination'], isTrue);
      expect(tun['address'], ['10.20.0.1/30', 'fd00::1/126']);
      expect(tun['route_exclude_address'], ['192.168.0.0/16']);
      expect(
        (tun['platform'] as Map<String, dynamic>)['http_proxy'],
        isNotNull,
      );
    });

    test('rejects invalid values before patching', () {
      expect(
        () => service.apply(
          _baseConfig(),
          const AdvancedNetworkSettings(
            dnsMode: DnsOverrideMode.manual,
            dnsServer: 'http://dns.example/dns-query',
          ),
        ),
        throwsA(isA<AdvancedNetworkSettingsException>()),
      );
      expect(
        () => service.apply(
          _baseConfig(),
          const AdvancedNetworkSettings(
            tunEnabled: true,
            tunAddresses: ['not-a-cidr'],
          ),
        ),
        throwsA(isA<AdvancedNetworkSettingsException>()),
      );
    });

    test('does not add unavailable rule-set references', () {
      final source = _baseConfig();
      (source['route'] as Map<String, dynamic>)['rule_set'] = <dynamic>[];

      final patched = service.apply(
        source,
        const AdvancedNetworkSettings(dnsMode: DnsOverrideMode.flsing),
      );
      final rules = ((patched['dns'] as Map<String, dynamic>)['rules'] as List)
          .cast<Map<String, dynamic>>();

      expect(rules.any((rule) => rule.containsKey('rule_set')), isFalse);
    });
  });
}

Map<String, dynamic> _baseConfig() => {
  'dns': {
    'servers': [
      {'tag': 'subscription-dns', 'type': 'local'},
    ],
    'rules': <dynamic>[],
    'final': 'subscription-dns',
  },
  'inbounds': [
    {
      'tag': 'tun',
      'type': 'tun',
      'address': ['172.19.0.1/30'],
      'mtu': 1400,
      'stack': 'system',
      'auto_route': true,
      'strict_route': true,
      'platform': {
        'http_proxy': {
          'enabled': false,
          'server': '127.0.0.1',
          'server_port': 8890,
        },
      },
    },
  ],
  'route': {
    'default_domain_resolver': 'subscription-dns',
    'rules': <dynamic>[],
    'final': 'direct',
    'rule_set': [
      {'tag': 'geoip-cn', 'type': 'local', 'path': 'geoip-cn.srs'},
      {'tag': 'geosite-cn', 'type': 'local', 'path': 'geosite-cn.srs'},
    ],
  },
  'outbounds': [
    {'tag': 'direct', 'type': 'direct'},
  ],
};
