import 'dart:async';

import 'package:flutter_sing_box/flutter_sing_box.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flsing/data/services/app_settings.dart';
import 'package:flsing/data/services/ip_service.dart';
import 'package:flsing/data/services/sing_box_service.dart';
import 'package:flsing/models/app_models.dart';
import 'package:flsing/providers/app_state.dart';

void main() {
  late _MemoryStorage storage;
  late _FakeSingBoxService service;
  late AppState state;
  late List<({String host, int port})> probes;
  late StreamController<ProxyState> proxyStates;
  late StreamController<ClientClashMode> clashModes;

  setUp(() async {
    storage = _MemoryStorage();
    AppSettings.setStorageForTesting(storage);
    AppSettings().autoUpdateSubscriptions = false;
    service = _FakeSingBoxService();
    proxyStates = StreamController<ProxyState>.broadcast();
    service.proxyStates = proxyStates.stream;
    clashModes = StreamController<ClientClashMode>.broadcast();
    service.clashModes = clashModes.stream;
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
    await clashModes.close();
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
    await Future<void>.delayed(const Duration(milliseconds: 1300));
  });

  test('all-node test still respects the proxy test setting', () async {
    AppSettings().latencyTestMethod = LatencyTestMethod.proxy;

    await state.testAllNodes();

    expect(probes, isEmpty);
    expect(service.groupTestCount, 0);
    expect(state.takeFeedback(), '代理测速需要先连接');
  });

  test('connection timer restarts after reconnecting', () async {
    proxyStates.add(ProxyState.started);
    await Future<void>.delayed(Duration.zero);
    proxyStates.add(ProxyState.stopped);
    await Future<void>.delayed(Duration.zero);
    proxyStates.add(ProxyState.started);
    await Future<void>.delayed(const Duration(milliseconds: 1300));

    expect(state.connectedFor.inSeconds, greaterThanOrEqualTo(1));
  });

  test('preferred mode is pushed to the core after connect', () async {
    proxyStates.add(ProxyState.started);
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(service.modeSets, [(mode: ClashMode.rule, connected: true)]);
    expect(state.mode, ProxyMode.rule);
    await Future<void>.delayed(const Duration(milliseconds: 1300));
  });

  test('stale kernel mode during connect does not override preference', () async {
    proxyStates.add(ProxyState.started);
    await Future<void>.delayed(Duration.zero);
    // cache.db 恢复的旧模式先于推送完成到达，不能把 UI 拉回全局。
    clashModes.add(
      ClientClashMode(
        modes: ['Rule', 'global', 'direct'],
        currentMode: 'global',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(state.mode, ProxyMode.rule);
    expect(service.modeSets, [(mode: ClashMode.rule, connected: true)]);

    // 推送窗口过后，内核事件恢复正常生效。
    clashModes.add(
      ClientClashMode(
        modes: ['Rule', 'global', 'direct'],
        currentMode: 'global',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(state.mode, ProxyMode.global);
    await Future<void>.delayed(const Duration(milliseconds: 1300));
  });

  test('service init failure still lists stored subscriptions', () async {
    final failing = _FakeSingBoxService()
      ..failInitialize = true
      ..proxyStates = const Stream.empty();
    final appState = AppState(
      service: failing,
      ipService: _FakeIpService(),
      tcpLatencyProbe: (host, port) async => null,
    );
    await appState.initialize();

    expect(appState.isInitialized, isTrue);
    expect(appState.subscriptions, hasLength(1));
    expect(appState.nodes, hasLength(2));
    expect(appState.takeFeedback(), contains('sing-box 初始化失败'));
    appState.dispose();
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
  final List<({String mode, bool connected})> modeSets = [];
  bool failInitialize = false;
  late Stream<ProxyState> proxyStates;
  Stream<ClientClashMode> clashModes = const Stream.empty();

  @override
  Stream<ProxyState> get proxyStateStream => proxyStates;

  @override
  Stream<List<ClientGroup>> get groupStream => const Stream.empty();

  @override
  Stream<ClientClashMode> get clashModeStream => clashModes;

  @override
  Stream<List<ClientLog>> get logStream => const Stream.empty();

  @override
  List<Profile> get profiles => [profile];

  @override
  Profile? get selectedProfile => profile;

  @override
  String get preferredMode => ClashMode.rule;

  @override
  Future<void> initialize() async {
    if (failInitialize) throw StateError('init failed');
  }

  @override
  Future<void> setMode(String mode, {required bool connected}) async {
    modeSets.add((mode: mode, connected: connected));
  }

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
  double getDouble(String key, {double defaultValue = 0.0}) =>
      _values[key] as double? ?? defaultValue;

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
  bool setBool(String key, bool? value) => _setObject(key, value);

  @override
  bool setDouble(String key, double? value) => _setObject(key, value);

  @override
  bool setInt(String key, int? value) => _setObject(key, value);

  @override
  bool setString(String key, String? value) => _setObject(key, value);

  bool _setObject(String key, Object? value) {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
    return true;
  }
}
