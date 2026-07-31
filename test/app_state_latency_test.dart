import 'dart:async';

import 'package:flutter_sing_box/flutter_sing_box.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flsing/data/services/app_settings.dart';
import 'package:flsing/data/services/ip_service.dart';
import 'package:flsing/data/services/sing_box_service.dart';
import 'package:flsing/providers/app_state.dart';

void main() {
  late _MemoryStorage storage;
  late _FakeSingBoxService service;
  late AppState state;
  late List<({String host, int port})> probes;
  late StreamController<ProxyState> proxyStates;

  setUp(() async {
    storage = _MemoryStorage();
    AppSettings.setStorageForTesting(storage);
    AppSettings().autoUpdateSubscriptions = false;
    service = _FakeSingBoxService();
    proxyStates = StreamController<ProxyState>.broadcast();
    service.proxyStates = proxyStates.stream;
    probes = [];
    state = AppState(
      service: service,
      ipService: _FakeIpService(),
      tcpLatencyProbe: (host, port) async {
        probes.add((host: host, port: port));
        return 42;
      },
    );
    await state.initialize();
  });

  tearDown(() async {
    state.dispose();
    await proxyStates.close();
    AppSettings.setStorageForTesting(null);
  });

  test('single-node direct test uses one physical TCP probe', () async {
    AppSettings().latencyTestMethod = LatencyTestMethod.direct;

    await state.testNode('node-a');

    expect(probes, [(host: 'node-a.example', port: 443)]);
    expect(service.outboundTests, isEmpty);
    expect(state.nodes.firstWhere((node) => node.id == 'node-a').latency, 42);
    expect(state.nodes.firstWhere((node) => node.id == 'node-b').latency, null);
  });

  test('single-node proxy test requires an active connection', () async {
    AppSettings().latencyTestMethod = LatencyTestMethod.proxy;

    await state.testNode('node-a');

    expect(probes, isEmpty);
    expect(service.outboundTests, isEmpty);
    expect(state.takeFeedback(), '代理测速需要先连接');
  });

  test('single-node proxy test uses the selected core outbound', () async {
    AppSettings().latencyTestMethod = LatencyTestMethod.proxy;
    proxyStates.add(ProxyState.started);
    await Future<void>.delayed(Duration.zero);

    await state.testNode('node-a');

    expect(probes, isEmpty);
    expect(service.outboundTests, ['node-a']);
    expect(service.groupTestCount, 0);
    expect(state.nodes.firstWhere((node) => node.id == 'node-a').latency, 73);
    expect(state.nodes.firstWhere((node) => node.id == 'node-b').latency, null);
  });

  test('all-node test still respects the proxy test setting', () async {
    AppSettings().latencyTestMethod = LatencyTestMethod.proxy;

    await state.testAllNodes();

    expect(probes, isEmpty);
    expect(service.groupTestCount, 0);
    expect(state.takeFeedback(), '代理测速需要先连接');
  });
}

class _FakeSingBoxService extends SingBoxService {
  _FakeSingBoxService()
    : profile = Profile(
        id: 1,
        order: 1,
        name: 'Test',
        outboundsCount: 2,
        typed: TypedProfile(
          type: ProfileType.local,
          path: 'unused',
          lastUpdated: DateTime.now().millisecondsSinceEpoch,
        ),
      );

  final Profile profile;
  int groupTestCount = 0;
  final List<String> outboundTests = [];
  late Stream<ProxyState> proxyStates;

  @override
  Stream<ProxyState> get proxyStateStream => proxyStates;

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
  String get preferredMode => ClashMode.rule;

  @override
  Future<void> initialize() async {}

  @override
  Future<ConfiguredNodeGroup?> configuredNodeGroup(Profile profile) async {
    return const ConfiguredNodeGroup(
      tag: 'proxy',
      selected: 'node-a',
      nodes: [
        ConfiguredNode(
          tag: 'node-a',
          type: 'vless',
          server: 'node-a.example',
          serverPort: 443,
        ),
        ConfiguredNode(
          tag: 'node-b',
          type: 'shadowsocks',
          server: 'node-b.example',
          serverPort: 8443,
        ),
      ],
    );
  }

  @override
  Future<void> testGroup(String groupTag) async {
    groupTestCount++;
  }

  @override
  Future<int> testOutbound(String outboundTag) async {
    outboundTests.add(outboundTag);
    return 73;
  }
}

class _FakeIpService extends IpService {
  @override
  Future<({String ip, String region})?> fetch() async => null;
}

class _MemoryStorage implements KeyValueStorage {
  final Map<String, Object> _values = {};

  @override
  List<String> get allKeys => _values.keys.toList(growable: false);

  @override
  void clearAll() => _values.clear();

  @override
  bool getBool(String key, {bool defaultValue = false}) =>
      _values[key] as bool? ?? defaultValue;

  @override
  int getInt(String key, {int defaultValue = 0}) =>
      _values[key] as int? ?? defaultValue;

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  void removeValue(String key) => _values.remove(key);

  @override
  void removeValues(List<String> keys) {
    for (final key in keys) {
      _values.remove(key);
    }
  }

  @override
  bool setBool(String key, bool value) {
    _values[key] = value;
    return true;
  }

  @override
  bool setInt(String key, int value) {
    _values[key] = value;
    return true;
  }

  @override
  bool setString(String key, String value) {
    _values[key] = value;
    return true;
  }
}
