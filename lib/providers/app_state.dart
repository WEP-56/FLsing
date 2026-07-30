import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_sing_box/flutter_sing_box.dart';

import '../data/services/app_settings.dart';
import '../data/services/sing_box_service.dart';
import '../models/app_models.dart';

class AppState extends ChangeNotifier {
  AppState({SingBoxService? service}) : _service = service ?? SingBoxService();

  final SingBoxService _service;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final List<SubscriptionItem> _profiles = [];
  final List<ProxyNode> _nodes = [];
  // tag → 节点服务器地址端口，供 TCP 直连测速使用（从配置文件解析）。
  final Map<String, ({String host, int port})> _endpoints = {};

  static const _tcpProbeTimeout = Duration(seconds: 5);
  static const _tcpProbeConcurrency = 8;

  bool _testingAll = false;
  Timer? _kernelTestTimer;

  ConnectionPhase _phase = ConnectionPhase.disconnected;
  ProxyMode _mode = ProxyMode.rule;
  Duration _connectedFor = Duration.zero;
  Timer? _connectionTimer;
  String? _activeSubscriptionId;
  String? _selectedNodeId;
  String? _activeGroupTag;
  String? _feedback;
  bool _initializing = false;
  bool _initialized = false;

  ConnectionPhase get phase => _phase;
  ProxyMode get mode => _mode;
  Duration get connectedFor => _connectedFor;
  List<ProxyNode> get nodes => List.unmodifiable(_nodes);
  List<SubscriptionItem> get subscriptions => List.unmodifiable(_profiles);
  bool get isConnected => _phase == ConnectionPhase.connected;
  bool get isTransitioning =>
      _phase == ConnectionPhase.connecting ||
      _phase == ConnectionPhase.disconnecting;
  bool get isInitializing => _initializing;
  bool get isInitialized => _initialized;
  bool get hasSubscription => _profiles.isNotEmpty;
  SubscriptionItem? get activeSubscription =>
      _findProfile(_activeSubscriptionId);
  ProxyNode? get selectedNode => _findNode(_selectedNodeId);
  bool get isTestingAll => _testingAll;
  bool get isTestingAny => _testingAll || _nodes.any((node) => node.testing);

  String? takeFeedback() {
    final message = _feedback;
    _feedback = null;
    return message;
  }

  Future<String> singBoxVersion() => _service.singBoxVersion();

  Future<void> initialize() async {
    if (_initializing || _initialized) return;
    _initializing = true;
    notifyListeners();
    try {
      await _service.initialize();
      _mode = _modeFromPlugin(_service.preferredMode);
      _reloadProfiles();
      await _loadConfiguredNodes();
      _listenToNativeEvents();
      _initialized = true;
      if (AppSettings().autoUpdateSubscriptions) {
        unawaited(_refreshStaleSubscriptions());
      }
    } catch (error) {
      _feedback = 'sing-box 初始化失败：$error';
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> toggleConnection() async {
    if (isTransitioning) return;
    if (!hasSubscription) {
      _feedback = '请先导入订阅';
      notifyListeners();
      return;
    }
    try {
      if (isConnected) {
        _phase = ConnectionPhase.disconnecting;
        notifyListeners();
        await _service.stopVpn();
      } else {
        _phase = ConnectionPhase.connecting;
        notifyListeners();
        await _service.startVpn();
      }
    } catch (error) {
      _phase = ConnectionPhase.disconnected;
      _feedback = _connectionError(error);
      notifyListeners();
    }
  }

  Future<void> selectMode(ProxyMode mode) async {
    final previous = _mode;
    _mode = mode;
    notifyListeners();
    try {
      await _service.setMode(_pluginMode(mode), connected: isConnected);
    } catch (error) {
      _mode = previous;
      _feedback = '切换模式失败：$error';
      notifyListeners();
    }
  }

  /// 手动拉取最新规则库。
  Future<void> updateRuleSets() async {
    try {
      await _service.updateRuleSets(connected: isConnected);
      _feedback = '规则库已更新';
    } catch (error) {
      _feedback = '规则库更新失败：$error';
    }
    notifyListeners();
  }

  Future<void> selectNode(String id) async {
    if (_activeGroupTag == null) return;
    final previous = _selectedNodeId;
    _selectedNodeId = id;
    notifyListeners();
    if (!isConnected) {
      _feedback = '节点将在连接后启用';
      notifyListeners();
      return;
    }
    try {
      await _service.selectOutbound(groupTag: _activeGroupTag!, nodeTag: id);
    } catch (error) {
      _selectedNodeId = previous;
      _feedback = '切换节点失败：$error';
      notifyListeners();
    }
  }

  /// 当前是否应使用内核测速（由设置项与连接状态共同决定）。
  bool get _useKernelTest => switch (AppSettings().latencyTestMethod) {
    LatencyTestMethod.direct => false,
    LatencyTestMethod.proxy => true,
    _ => isConnected,
  };

  Future<void> testNode(String id) async {
    if (isTestingAny) return;
    if (_useKernelTest) {
      await _kernelTest();
    } else {
      if (!_endpoints.containsKey(id)) {
        _feedback = '该节点缺少地址信息，无法直连测速';
        notifyListeners();
        return;
      }
      await _tcpTest([id]);
    }
  }

  Future<void> testAllNodes() async {
    if (isTestingAny || _nodes.isEmpty) return;
    if (_useKernelTest) {
      await _kernelTest();
    } else {
      await _tcpTest(_nodes.map((node) => node.id).toList());
    }
  }

  /// 内核测速：libbox 只支持整组 urlTest，结果经 groupStream 异步返回。
  Future<void> _kernelTest() async {
    if (!isConnected || _activeGroupTag == null) {
      _feedback = '代理测速需要先连接';
      notifyListeners();
      return;
    }
    _markAllTesting(true);
    _testingAll = true;
    notifyListeners();
    // groupStream 不保证回包（如测速全部超时），兜底解除加载态。
    _kernelTestTimer?.cancel();
    _kernelTestTimer = Timer(const Duration(seconds: 25), _finishKernelTest);
    try {
      await _service.testGroup(_activeGroupTag!);
    } catch (error) {
      _feedback = '测速失败：$error';
      _finishKernelTest();
    }
  }

  void _finishKernelTest() {
    _kernelTestTimer?.cancel();
    _kernelTestTimer = null;
    if (!_testingAll) return;
    _testingAll = false;
    _markAllTesting(false);
    notifyListeners();
  }

  /// TCP 直连测速：设备直接握手节点端口，无需开启 VPN。
  Future<void> _tcpTest(List<String> ids) async {
    final targets = ids.where(_endpoints.containsKey).toList();
    if (targets.isEmpty) {
      _feedback = '当前节点缺少地址信息，请更新订阅后再试';
      notifyListeners();
      return;
    }
    _testingAll = ids.length > 1;
    for (final id in targets) {
      _replaceNode(id, testing: true);
    }
    notifyListeners();
    for (var i = 0; i < targets.length; i += _tcpProbeConcurrency) {
      await Future.wait(
        targets.skip(i).take(_tcpProbeConcurrency).map(_tcpProbe),
      );
    }
    _testingAll = false;
    notifyListeners();
  }

  Future<void> _tcpProbe(String id) async {
    final endpoint = _endpoints[id]!;
    final watch = Stopwatch()..start();
    int? latency;
    try {
      final socket = await Socket.connect(
        endpoint.host,
        endpoint.port,
        timeout: _tcpProbeTimeout,
      );
      latency = watch.elapsedMilliseconds;
      socket.destroy();
    } catch (_) {
      latency = null;
    }
    _replaceNode(id, latency: latency, testing: false, clearLatency: true);
    notifyListeners();
  }

  void _markAllTesting(bool testing) {
    for (var i = 0; i < _nodes.length; i++) {
      _nodes[i] = _nodes[i].copyWith(testing: testing);
    }
  }

  void _replaceNode(
    String id, {
    int? latency,
    bool? testing,
    bool clearLatency = false,
  }) {
    final index = _nodes.indexWhere((node) => node.id == id);
    if (index == -1) return;
    final node = _nodes[index];
    _nodes[index] = ProxyNode(
      id: node.id,
      country: node.country,
      flag: node.flag,
      name: node.name,
      protocol: node.protocol,
      transport: node.transport,
      latency: clearLatency ? latency : (latency ?? node.latency),
      testing: testing ?? node.testing,
    );
  }

  Future<bool> addSubscription({
    required String name,
    required String url,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      _feedback = '订阅链接无效';
      notifyListeners();
      return false;
    }
    try {
      final profile = await _service.importSubscription(url: uri, name: name);
      _reloadProfiles();
      _activeSubscriptionId = profile.id.toString();
      await _loadConfiguredNodes();
      _feedback = '订阅已导入';
      notifyListeners();
      return true;
    } catch (error) {
      _feedback = '导入订阅失败：$error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> addSubscriptionFile(File file) async {
    try {
      final profile = await _service.importFile(
        file: file,
        name: file.uri.pathSegments.last,
      );
      _reloadProfiles();
      _activeSubscriptionId = profile.id.toString();
      await _loadConfiguredNodes();
      _feedback = '配置文件已导入';
      notifyListeners();
      return true;
    } catch (error) {
      _feedback = '导入配置文件失败：$error';
      notifyListeners();
      return false;
    }
  }

  Future<void> editSubscription(
    String id, {
    required String name,
    required String url,
  }) async {
    final profile = _service.profiles
        .where((item) => item.id.toString() == id)
        .firstOrNull;
    final uri = Uri.tryParse(url);
    if (profile == null || uri == null || !uri.hasScheme) return;
    await _runWithFeedback(() async {
      await _service.updateProfile(profile, name: name, url: uri);
      _reloadProfiles();
      await _loadConfiguredNodes();
    }, failurePrefix: '更新订阅失败');
  }

  Future<void> refreshSubscription(String id) async {
    final profile = _service.profiles
        .where((item) => item.id.toString() == id)
        .firstOrNull;
    if (profile == null) return;
    await _runWithFeedback(() async {
      await _service.refreshProfile(profile);
      _reloadProfiles();
      await _loadConfiguredNodes();
    }, failurePrefix: '更新订阅失败');
  }

  Future<void> activateSubscription(String id) async {
    final parsed = int.tryParse(id);
    if (parsed == null) return;
    await _runWithFeedback(() async {
      await _service.selectProfile(parsed);
      _reloadProfiles();
      await _loadConfiguredNodes();
      if (isConnected) await _service.reloadService();
    }, failurePrefix: '启用订阅失败');
  }

  Future<void> deleteSubscription(String id) async {
    final parsed = int.tryParse(id);
    if (parsed == null || _profiles.length <= 1) return;
    await _runWithFeedback(() async {
      await _service.deleteProfile(parsed);
      _reloadProfiles();
      await _loadConfiguredNodes();
      if (isConnected) await _service.reloadService();
    }, failurePrefix: '删除订阅失败');
  }

  void _listenToNativeEvents() {
    _subscriptions.add(
      _service.proxyStateStream.listen(_onProxyState, onError: _onNativeError),
    );
    _subscriptions.add(
      _service.groupStream.listen(_onGroups, onError: _onNativeError),
    );
    _subscriptions.add(
      _service.clashModeStream.listen(_onClashMode, onError: _onNativeError),
    );
  }

  void _onProxyState(ProxyState state) {
    switch (state) {
      case ProxyState.starting:
        _phase = ConnectionPhase.connecting;
      case ProxyState.started:
        _phase = ConnectionPhase.connected;
        _startTimer();
        unawaited(_applySelectionToRunningService());
      case ProxyState.stopping:
        _phase = ConnectionPhase.disconnecting;
      case ProxyState.stopped:
      case ProxyState.unknown:
        _connectionTimer?.cancel();
        _connectedFor = Duration.zero;
        _phase = ConnectionPhase.disconnected;
    }
    notifyListeners();
  }

  void _onGroups(List<ClientGroup> groups) {
    final group = groups
        .where((item) => item.selectable && (item.items?.isNotEmpty ?? false))
        .firstOrNull;
    if (group == null) return;
    _activeGroupTag = group.tag;
    _selectedNodeId = group.selected;
    final hasDelays = group.items!.any((item) => item.urlTestDelay > 0);
    _nodes
      ..clear()
      ..addAll(group.items!.map(_nodeFromGroupItem));
    if (_testingAll && !hasDelays) {
      // 内核测速还没出结果，保持加载态。
      _markAllTesting(true);
    } else if (_testingAll) {
      _finishKernelTest();
    }
    notifyListeners();
  }

  void _onClashMode(ClientClashMode mode) {
    _mode = _modeFromPlugin(mode.currentMode);
    notifyListeners();
  }

  ProxyMode _modeFromPlugin(String value) => switch (value.toLowerCase()) {
    'global' => ProxyMode.global,
    'direct' => ProxyMode.direct,
    _ => ProxyMode.rule,
  };

  /// 打开 app 时静默刷新超过时限未更新的订阅。
  Future<void> _refreshStaleSubscriptions() async {
    final staleBefore = DateTime.now().subtract(
      Duration(hours: AppSettings().subscriptionStaleHours),
    );
    for (final item in List.of(_profiles)) {
      if (item.updatedAt.isAfter(staleBefore)) continue;
      await refreshSubscription(item.id);
    }
  }

  void _onNativeError(Object error, StackTrace stackTrace) {
    _feedback = 'sing-box 服务异常：$error';
    notifyListeners();
  }

  void _reloadProfiles() {
    final selectedId = _service.selectedProfile?.id.toString();
    _profiles
      ..clear()
      ..addAll(
        _service.profiles.map(
          (profile) => SubscriptionItem(
            id: profile.id.toString(),
            name: profile.name,
            url: profile.typed.subscribeUrl ?? '',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(
              profile.typed.lastUpdated,
            ),
            nodeCount: profile.outboundsCount ?? 0,
          ),
        ),
      );
    _activeSubscriptionId = selectedId;
  }

  Future<void> _loadConfiguredNodes() async {
    final id = _activeSubscriptionId;
    final profile = _service.profiles
        .where((item) => item.id.toString() == id)
        .firstOrNull;
    if (profile == null) {
      _activeGroupTag = null;
      _selectedNodeId = null;
      _nodes.clear();
      return;
    }
    final group = await _service.configuredNodeGroup(profile);
    if (group == null) return;
    _activeGroupTag = group.tag;
    _endpoints.clear();
    for (final node in group.nodes) {
      if (node.server != null && node.serverPort != null) {
        _endpoints[node.tag] = (host: node.server!, port: node.serverPort!);
      }
    }
    _nodes
      ..clear()
      ..addAll(
        group.nodes.map(
          (node) => ProxyNode(
            id: node.tag,
            country: '',
            flag: '•',
            name: node.tag,
            protocol: node.type,
            transport: '',
          ),
        ),
      );
    _selectedNodeId = _nodes.any((item) => item.id == group.selected)
        ? group.selected
        : _nodes.first.id;
  }

  Future<void> _applySelectionToRunningService() async {
    final group = _activeGroupTag;
    final node = _selectedNodeId;
    if (group == null || node == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    try {
      await _service.selectOutbound(groupTag: group, nodeTag: node);
    } catch (error) {
      _feedback = '应用预选节点失败：$error';
      notifyListeners();
    }
  }

  ProxyNode _nodeFromGroupItem(ClientGroupItem item) => ProxyNode(
    id: item.tag,
    country: '',
    flag: '•',
    name: item.tag,
    protocol: item.type,
    transport: '',
    latency: item.urlTestDelay > 0 ? item.urlTestDelay : null,
  );

  SubscriptionItem? _findProfile(String? id) {
    for (final item in _profiles) {
      if (item.id == id) return item;
    }
    return null;
  }

  ProxyNode? _findNode(String? id) {
    for (final item in _nodes) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> _runWithFeedback(
    Future<void> Function() action, {
    required String failurePrefix,
  }) async {
    try {
      await action();
    } catch (error) {
      _feedback = '$failurePrefix：$error';
    }
    notifyListeners();
  }

  void _startTimer() {
    _connectionTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _connectedFor += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  String _pluginMode(ProxyMode mode) => switch (mode) {
    ProxyMode.rule => ClashMode.rule,
    ProxyMode.global => ClashMode.global,
    ProxyMode.direct => ClashMode.direct,
  };

  String _connectionError(Object error) {
    final text = error.toString();
    if (text.contains('VPN_PERMISSION_DENIED')) return 'VPN 授权被拒绝';
    return '连接失败：$text';
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    _kernelTestTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
