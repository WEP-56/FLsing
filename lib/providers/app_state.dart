import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_sing_box/flutter_sing_box.dart';

import '../data/services/app_settings.dart';
import '../data/services/ip_service.dart';
import '../data/services/sing_box_service.dart';
import '../models/app_models.dart';

class AppState extends ChangeNotifier {
  AppState({SingBoxService? service, IpService? ipService})
    : _service = service ?? SingBoxService(),
      _ipService = ipService ?? IpService();

  final SingBoxService _service;
  final IpService _ipService;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final List<SubscriptionItem> _profiles = [];
  final List<ProxyNode> _nodes = [];
  final List<ClientLog> _logs = [];
  // tag → 节点服务器地址端口，供 TCP 直连测速使用（从配置文件解析）。
  final Map<String, ({String host, int port})> _endpoints = {};

  static const _tcpProbeTimeout = Duration(seconds: 5);
  static const _tcpProbeConcurrency = 8;
  static const _maxRetainedLogs = 600;
  static const _reconnectDelays = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 32),
  ];

  bool _testingAll = false;
  Timer? _kernelTestTimer;
  Timer? _kernelResultSettleTimer;
  bool _kernelTesting = false;
  bool _tcpTesting = false;
  int _kernelTestStartedAt = 0;
  final Map<String, int> _kernelTestTimes = {};
  final Map<String, int> _kernelTestBaseline = {};
  ClientGroup? _pendingKernelResult;
  Completer<void>? _kernelTestCompleter;

  IpInfo? _ipInfo;
  bool _ipFetching = false;
  int _ipRequestSeq = 0;

  ConnectionPhase _phase = ConnectionPhase.disconnected;
  ProxyMode _mode = ProxyMode.rule;
  Duration _connectedFor = Duration.zero;
  Timer? _connectionTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _connectionRequested = false;
  String? _lastError;
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

  IpInfo? get ipInfo => _ipInfo;
  List<ClientLog> get logs => List.unmodifiable(_logs);
  String? get lastError => _lastError;
  bool get reconnectPending => _reconnectTimer?.isActive ?? false;

  /// 还没有任何 IP 结果时的初始加载态（IpChip 显示骨架条）。
  bool get ipLoading => _ipFetching && _ipInfo == null;

  /// 已有结果、正在重新检测（IpChip 刷新按钮旋转）。
  bool get ipRefreshing => _ipFetching && _ipInfo != null;

  /// 重新检测当前出口 / 本地 IP。
  ///
  /// 连接状态切换后系统路由需要一点时间收敛，[settleDelay] 用来错开这段时间。
  Future<void> refreshIpInfo({Duration settleDelay = Duration.zero}) async {
    final seq = ++_ipRequestSeq;
    if (settleDelay > Duration.zero) {
      await Future<void>.delayed(settleDelay);
      if (seq != _ipRequestSeq) return;
    }
    _ipFetching = true;
    notifyListeners();
    final result = await _ipService.fetch();
    if (seq != _ipRequestSeq) return;
    _ipFetching = false;
    if (result != null) {
      _ipInfo = IpInfo(
        ip: result.ip,
        region: result.region,
        isExit: isConnected && _mode != ProxyMode.direct,
      );
    }
    notifyListeners();
  }

  String? takeFeedback() {
    final message = _feedback;
    _feedback = null;
    return message;
  }

  Future<String> singBoxVersion() => _service.singBoxVersion();

  void setAutoReconnect(bool value) {
    AppSettings().autoReconnect = value;
    if (!value) _cancelReconnect();
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  Future<String> buildDiagnosticReport() async {
    String coreVersion;
    try {
      coreVersion = await _service.singBoxVersion();
    } catch (_) {
      coreVersion = 'unavailable';
    }
    final ruleSetUpdatedAt = AppSettings().ruleSetUpdatedAt;
    final ruleSetTime = ruleSetUpdatedAt == 0
        ? 'built-in'
        : DateTime.fromMillisecondsSinceEpoch(
            ruleSetUpdatedAt,
          ).toIso8601String();
    return <String>[
      'FLsing diagnostic report',
      'Generated: ${DateTime.now().toIso8601String()}',
      'VPN state: ${_phase.name}',
      'Proxy mode: ${_mode.name}',
      'sing-box: $coreVersion',
      'Active subscription: ${activeSubscription?.name ?? 'none'}',
      'Selected node: ${selectedNode?.name ?? 'none'}',
      'Exit IP: ${_ipInfo?.ip ?? 'unavailable'}',
      'Rule sets: $ruleSetTime',
      'Auto reconnect: ${AppSettings().autoReconnect}',
      'Last error: ${_lastError ?? 'none'}',
    ].join('\n');
  }

  String buildSanitizedLogReport() => <String>[
    'FLsing logs',
    ..._logs.map(
      (log) => '[${_logLevelName(log.level)}] ${_sanitizeLog(log.message)}',
    ),
  ].join('\n');

  String sanitizedLogMessage(String message) => _sanitizeLog(message);

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
      unawaited(refreshIpInfo());
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
        _connectionRequested = false;
        _cancelReconnect();
        _phase = ConnectionPhase.disconnecting;
        notifyListeners();
        await _service.stopVpn();
      } else {
        _connectionRequested = true;
        _cancelReconnect();
        _phase = ConnectionPhase.connecting;
        notifyListeners();
        await _service.startVpn();
      }
    } catch (error) {
      _phase = ConnectionPhase.disconnected;
      _lastError = _connectionError(error);
      _feedback = _connectionError(error);
      if (_canRetryConnectionError(error)) _scheduleReconnect();
      notifyListeners();
    }
  }

  Future<void> selectMode(ProxyMode mode) async {
    final previous = _mode;
    _mode = mode;
    notifyListeners();
    try {
      await _service.setMode(_pluginMode(mode), connected: isConnected);
      if (isConnected) unawaited(refreshIpInfo());
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

  /// 测速链接等设置变更后，重新对使用中的配置打补丁。
  Future<void> applySettingsPatch() async {
    try {
      await _service.applySettingsPatch();
    } catch (error) {
      _feedback = '应用设置失败：$error';
      notifyListeners();
    }
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
    _kernelTesting = true;
    _testingAll = true;
    _kernelTestStartedAt = DateTime.now().millisecondsSinceEpoch;
    _kernelTestBaseline
      ..clear()
      ..addAll(_kernelTestTimes);
    _pendingKernelResult = null;
    final completion = Completer<void>();
    _kernelTestCompleter = completion;
    _markNodesTesting(
      _nodes.map((node) => node.id),
      testing: true,
      clearLatency: true,
    );
    notifyListeners();
    // groupStream 不保证回包（如测速全部超时），兜底解除加载态。
    _kernelTestTimer?.cancel();
    _kernelResultSettleTimer?.cancel();
    _kernelTestTimer = Timer(const Duration(seconds: 25), _finishKernelTest);
    try {
      await _service.testGroup(_activeGroupTag!);
      await completion.future;
    } catch (error) {
      _feedback = '测速失败：$error';
      _pendingKernelResult = null;
      _finishKernelTest();
    }
  }

  void _finishKernelTest() {
    _kernelTestTimer?.cancel();
    _kernelTestTimer = null;
    _kernelResultSettleTimer?.cancel();
    _kernelResultSettleTimer = null;
    if (!_kernelTesting) return;
    final result = _pendingKernelResult;
    if (result != null) {
      _applyKernelTestResult(result);
    } else {
      _markNodesTesting(_nodes.map((node) => node.id), testing: false);
    }
    _kernelTesting = false;
    _testingAll = false;
    _pendingKernelResult = null;
    _kernelTestBaseline.clear();
    notifyListeners();
    final completion = _kernelTestCompleter;
    _kernelTestCompleter = null;
    if (completion != null && !completion.isCompleted) completion.complete();
  }

  /// TCP 直连测速：设备直接握手节点端口，无需开启 VPN。
  Future<void> _tcpTest(List<String> ids) async {
    final targets = ids.where(_endpoints.containsKey).toList();
    if (targets.isEmpty) {
      _feedback = '当前节点缺少地址信息，请更新订阅后再试';
      notifyListeners();
      return;
    }
    _tcpTesting = true;
    _testingAll = true;
    _markNodesTesting(ids, testing: true, clearLatency: true);
    notifyListeners();
    try {
      final results = <String, int?>{for (final id in ids) id: null};
      for (var i = 0; i < targets.length; i += _tcpProbeConcurrency) {
        final batch = await Future.wait(
          targets.skip(i).take(_tcpProbeConcurrency).map((id) async {
            return (id: id, latency: await _tcpProbe(id));
          }),
        );
        for (final result in batch) {
          results[result.id] = result.latency;
        }
      }
      for (final entry in results.entries) {
        _replaceNode(
          entry.key,
          latency: entry.value,
          testing: false,
          clearLatency: true,
        );
      }
    } finally {
      _markNodesTesting(ids, testing: false);
      _tcpTesting = false;
      _testingAll = false;
      notifyListeners();
    }
  }

  Future<int?> _tcpProbe(String id) async {
    final endpoint = _endpoints[id]!;
    final watch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        endpoint.host,
        endpoint.port,
        timeout: _tcpProbeTimeout,
      );
      final latency = watch.elapsedMilliseconds;
      socket.destroy();
      return latency;
    } catch (_) {
      return null;
    }
  }

  void _markNodesTesting(
    Iterable<String> ids, {
    required bool testing,
    bool clearLatency = false,
  }) {
    for (final id in ids.toList()) {
      _replaceNode(id, testing: testing, clearLatency: clearLatency);
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
    _subscriptions.add(
      _service.logStream.listen(_onLogs, onError: _onNativeError),
    );
  }

  void _onProxyState(ProxyState state) {
    final previous = _phase;
    switch (state) {
      case ProxyState.starting:
        _phase = ConnectionPhase.connecting;
      case ProxyState.started:
        _phase = ConnectionPhase.connected;
        _lastError = null;
        _reconnectAttempt = 0;
        _cancelReconnect();
        _startTimer();
        unawaited(_applySelectionToRunningService());
        // 隧道建立后路由需要片刻收敛，稍等再检测出口 IP。
        unawaited(
          refreshIpInfo(settleDelay: const Duration(milliseconds: 1200)),
        );
      case ProxyState.stopping:
        _phase = ConnectionPhase.disconnecting;
      case ProxyState.stopped:
      case ProxyState.unknown:
        _connectionTimer?.cancel();
        _connectedFor = Duration.zero;
        _phase = ConnectionPhase.disconnected;
        if (previous == ConnectionPhase.connected ||
            previous == ConnectionPhase.disconnecting) {
          unawaited(
            refreshIpInfo(settleDelay: const Duration(milliseconds: 800)),
          );
        }
        _scheduleReconnect();
    }
    notifyListeners();
  }

  void _onGroups(List<ClientGroup> groups) {
    final activeGroup = _activeGroupTag == null
        ? null
        : groups
              .where(
                (item) =>
                    item.tag == _activeGroupTag &&
                    (item.items?.isNotEmpty ?? false),
              )
              .firstOrNull;
    final group =
        activeGroup ??
        groups
            .where(
              (item) => item.selectable && (item.items?.isNotEmpty ?? false),
            )
            .firstOrNull;
    if (group == null) return;
    _activeGroupTag = group.tag;
    _selectedNodeId = group.selected;

    // TCP 测速的数据源是设备 Socket，内核事件不能覆盖这一批前端状态。
    if (_tcpTesting) return;

    if (_kernelTesting) {
      if (_hasFreshKernelResult(group)) {
        _pendingKernelResult = group;
        _kernelResultSettleTimer?.cancel();
        // groupStream 可能分多次推送同一批结果，等事件短暂静默后再统一提交。
        _kernelResultSettleTimer = Timer(
          const Duration(milliseconds: 350),
          _finishKernelTest,
        );
      }
      return;
    }

    _rememberKernelTestTimes(group);
    _nodes
      ..clear()
      ..addAll(group.items!.map(_nodeFromGroupItem));
    notifyListeners();
  }

  bool _hasFreshKernelResult(ClientGroup group) =>
      group.items!.any((item) => _isFreshKernelItem(item));

  bool _isFreshKernelItem(ClientGroupItem item) {
    if (item.urlTestTime <= 0) return false;
    final baseline = _kernelTestBaseline[item.tag];
    if (baseline != null) return item.urlTestTime > baseline;

    // libbox 版本间可能使用秒、毫秒、微秒或纳秒时间戳。
    var requestTime = _kernelTestStartedAt;
    if (item.urlTestTime < 100000000000) {
      requestTime ~/= 1000;
    } else if (item.urlTestTime >= 100000000000000000) {
      requestTime *= 1000000;
    } else if (item.urlTestTime >= 100000000000000) {
      requestTime *= 1000;
    }
    return item.urlTestTime >= requestTime;
  }

  void _applyKernelTestResult(ClientGroup group) {
    _rememberKernelTestTimes(group);
    _nodes
      ..clear()
      ..addAll(
        group.items!.map((item) {
          final fresh = _isFreshKernelItem(item);
          return _nodeFromGroupItem(
            item,
            latency: fresh && item.urlTestDelay > 0 ? item.urlTestDelay : null,
            overrideLatency: true,
          );
        }),
      );
  }

  void _rememberKernelTestTimes(ClientGroup group) {
    _kernelTestTimes
      ..clear()
      ..addEntries(
        group.items!.map((item) => MapEntry(item.tag, item.urlTestTime)),
      );
  }

  void _onClashMode(ClientClashMode mode) {
    _mode = _modeFromPlugin(mode.currentMode);
    notifyListeners();
  }

  void _onLogs(List<ClientLog> entries) {
    if (entries.isEmpty) return;
    _logs.addAll(entries);
    if (_logs.length > _maxRetainedLogs) {
      _logs.removeRange(0, _logs.length - _maxRetainedLogs);
    }
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
    _lastError = 'sing-box service error: $error';
    _scheduleReconnect();
    _feedback = 'sing-box 服务异常：$error';
    notifyListeners();
  }

  void _scheduleReconnect() {
    if (!_connectionRequested ||
        !AppSettings().autoReconnect ||
        !hasSubscription ||
        _reconnectTimer?.isActive == true) {
      return;
    }
    final delay =
        _reconnectDelays[_reconnectAttempt.clamp(
          0,
          _reconnectDelays.length - 1,
        )];
    _reconnectAttempt = (_reconnectAttempt + 1).clamp(
      0,
      _reconnectDelays.length - 1,
    );
    _reconnectTimer = Timer(delay, () async {
      if (!_connectionRequested || !AppSettings().autoReconnect) return;
      _phase = ConnectionPhase.connecting;
      notifyListeners();
      try {
        await _service.startVpn();
      } catch (error) {
        _phase = ConnectionPhase.disconnected;
        _lastError = _connectionError(error);
        if (_canRetryConnectionError(error)) _scheduleReconnect();
        notifyListeners();
      }
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
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
            uploadBytes: profile.userInfo?.upload,
            downloadBytes: profile.userInfo?.download,
            totalBytes: profile.userInfo?.total,
            expireAt: profile.userInfo?.expire == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    profile.userInfo!.expire! * 1000,
                  ),
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
    _kernelTestTimes.clear();
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

  ProxyNode _nodeFromGroupItem(
    ClientGroupItem item, {
    int? latency,
    bool overrideLatency = false,
  }) => ProxyNode(
    id: item.tag,
    country: '',
    flag: '•',
    name: item.tag,
    protocol: item.type,
    transport: '',
    latency: overrideLatency
        ? latency
        : (item.urlTestDelay > 0 ? item.urlTestDelay : null),
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

  bool _canRetryConnectionError(Object error) =>
      !error.toString().contains('VPN_PERMISSION_DENIED');

  String _logLevelName(int level) => switch (level) {
    0 => 'panic',
    1 => 'fatal',
    2 => 'error',
    3 => 'warn',
    4 => 'info',
    5 => 'debug',
    _ => 'trace',
  };

  String _sanitizeLog(String message) => message
      .replaceAll(RegExp(r'https?://[^\\s]+', caseSensitive: false), '<url>')
      .replaceAll(
        RegExp(r'(token|secret|password)=([^\\s&]+)', caseSensitive: false),
        r'$1=<redacted>',
      );

  @override
  void dispose() {
    _connectionTimer?.cancel();
    _reconnectTimer?.cancel();
    _kernelTestTimer?.cancel();
    _kernelResultSettleTimer?.cancel();
    final completion = _kernelTestCompleter;
    if (completion != null && !completion.isCompleted) completion.complete();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
