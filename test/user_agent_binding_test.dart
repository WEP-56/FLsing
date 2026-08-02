import 'package:flutter_sing_box/flutter_sing_box.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flsing/data/services/app_settings.dart';
import 'package:flsing/data/services/ip_service.dart';
import 'package:flsing/data/services/sing_box_service.dart';
import 'package:flsing/models/user_agents.dart';
import 'package:flsing/providers/app_state.dart';

void main() {
  setUp(() {
    AppSettings.setStorageForTesting(MemoryStorage());
    AppSettings().autoUpdateSubscriptions = false;
  });

  tearDown(() {
    AppSettings.setStorageForTesting(null);
  });

  group('AppSettings user agents', () {
    test('custom list round trips and survives corrupt data', () {
      final settings = AppSettings();
      expect(settings.customUserAgents, isEmpty);

      settings.customUserAgents = ['MyClient/1.0', 'Another/2'];
      expect(settings.customUserAgents, ['MyClient/1.0', 'Another/2']);

      AppSettings.setStorageForTesting(
        MemoryStorage()..setString('custom_user_agents', 'not-json'),
      );
      expect(AppSettings().customUserAgents, isEmpty);
    });

    test('subscription binding stores, overwrites and clears', () {
      final settings = AppSettings();
      expect(settings.subscriptionUserAgentFor(3), isNull);

      settings.setSubscriptionUserAgentFor(3, 'clash.meta/1.19.13');
      settings.setSubscriptionUserAgentFor(7, 'v2rayN/7.12.5');
      expect(settings.subscriptionUserAgentFor(3), 'clash.meta/1.19.13');
      expect(settings.subscriptionUserAgentFor(7), 'v2rayN/7.12.5');

      settings.setSubscriptionUserAgentFor(3, '  SFA/1.13.14  ');
      expect(settings.subscriptionUserAgentFor(3), 'SFA/1.13.14');

      settings.setSubscriptionUserAgentFor(3, null);
      expect(settings.subscriptionUserAgentFor(3), isNull);
      expect(settings.subscriptionUserAgentFor(7), 'v2rayN/7.12.5');
    });
  });

  group('UA validation', () {
    test('accepts printable ASCII and rejects the rest', () {
      expect(isValidUserAgentValue('clash-verge/v2.4.7'), isTrue);
      expect(isValidUserAgentValue('Mozilla/5.0 (Windows NT 10.0)'), isTrue);
      expect(isValidUserAgentValue(''), isFalse);
      expect(isValidUserAgentValue('带中文/1.0'), isFalse);
      expect(isValidUserAgentValue('line\nbreak'), isFalse);
      expect(isValidUserAgentValue('x' * 513), isFalse);
    });
  });

  group('AppState binding flow', () {
    test('addSubscription passes the selected UA to the service', () async {
      final service = _RecordingService();
      final state = AppState(
        service: service,
        ipService: _FakeIpService(),
        tcpLatencyProbe: (host, port) async => null,
      );

      final ok = await state.addSubscription(
        name: 'Sub',
        url: 'https://example.com/sub',
        userAgent: 'clash.meta/1.19.13',
      );

      expect(ok, isTrue);
      expect(service.importedUserAgents, ['clash.meta/1.19.13']);
      state.dispose();
    });

    test('editSubscription forwards the UA binding', () async {
      final service = _RecordingService();
      final state = AppState(
        service: service,
        ipService: _FakeIpService(),
        tcpLatencyProbe: (host, port) async => null,
      );

      await state.editSubscription(
        '1',
        name: 'Sub',
        url: 'https://example.com/sub',
        userAgent: 'v2rayNG/1.10.16',
      );

      expect(service.updatedUserAgents, ['v2rayNG/1.10.16']);
      state.dispose();
    });
  });
}

class _RecordingService extends SingBoxService {
  _RecordingService()
    : profile = Profile(
        id: 1,
        order: 1,
        name: 'Sub',
        outboundsCount: 1,
        typed: TypedProfile(
          type: ProfileType.remote,
          path: 'unused',
          lastUpdated: DateTime.now().millisecondsSinceEpoch,
          subscribeUrl: 'https://example.com/sub',
        ),
      );

  final Profile profile;
  final List<String?> importedUserAgents = [];
  final List<String?> updatedUserAgents = [];

  @override
  Stream<ProxyState> get proxyStateStream => const Stream.empty();

  @override
  Stream<List<ClientGroup>> get groupStream => const Stream.empty();

  @override
  Stream<ClientClashMode> get clashModeStream => const Stream.empty();

  @override
  Stream<List<ClientLog>> get logStream => const Stream.empty();

  @override
  List<Profile> get profiles => [profile];

  @override
  Profile? get selectedProfile => profile;

  @override
  Future<void> initialize() async {}

  @override
  Future<Profile> importSubscription({
    required Uri url,
    required String name,
    String? userAgent,
  }) async {
    importedUserAgents.add(userAgent);
    return profile;
  }

  @override
  Future<Profile> updateProfile(
    Profile profile, {
    required String name,
    required Uri url,
    String? userAgent,
  }) async {
    updatedUserAgents.add(userAgent);
    return profile;
  }

  @override
  Future<ConfiguredNodeGroup?> configuredNodeGroup(Profile profile) async =>
      null;
}

class _FakeIpService extends IpService {
  @override
  Future<({String ip, String region})?> fetch() async => null;
}
