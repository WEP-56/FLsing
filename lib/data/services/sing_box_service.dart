import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_sing_box/flutter_sing_box.dart';
import 'package:http/http.dart' as http;
import 'package:mmkv/mmkv.dart';

import 'app_settings.dart';
import 'rule_set_service.dart';
import 'subscription_parser.dart';

class SingBoxService {
  SingBoxService({FlutterSingBox? client})
    : _client = client ?? FlutterSingBox();

  final FlutterSingBox _client;
  final RuleSetService ruleSets = RuleSetService();
  bool _initialized = false;

  Stream<ProxyState> get proxyStateStream => _client.proxyStateStream;
  Stream<List<ClientGroup>> get groupStream => _client.groupStream;
  Stream<ClientClashMode> get clashModeStream => _client.clashModeStream;

  List<Profile> get profiles => ProfileStorage().getProfiles();
  Profile? get selectedProfile => ProfileStorage().getSelectedProfile();

  Future<void> initialize() async {
    if (_initialized || !io.Platform.isAndroid) return;
    await MMKV.initialize();
    await _client.init();
    // native 侧从 MMKV 读 using_config 目录且没有兜底（读到空字符串会报
    // EmptyConfiguration），这里把 Dart 侧的兜底目录显式写回去。
    final usingConfig = await ProfileStorage().getUsingConfig();
    ProfileStorage().setUsingConfig(usingConfig.parent.path);
    await ruleSets.ensureInstalled();
    // 已存在的 using_config 也补丁一次（本地规则集 + 默认模式）。
    await _patchUsingConfig();
    _initialized = true;
    final profile = selectedProfile;
    if (profile != null) await _activateProfile(profile);
  }

  Future<Profile> importSubscription({
    required Uri url,
    required String name,
  }) async {
    final response = await _fetchSubscription(url);
    final nodes = SubscriptionParser.parse(response.body);
    late final Profile profile;
    if (nodes != null) {
      // 分享链接类订阅（vmess/vless/ss 等）：插件转换器不支持，走自建管线。
      profile = await _saveParsedProfile(
        nodes: nodes,
        subscribeUrl: url,
        isLocal: false,
        name: name,
        headers: response.headers,
      );
    } else {
      // sing-box JSON / Clash YAML：交给插件处理。
      profile = await ProfileService().importProfile(
        subscribeLink: url,
        name: name,
      );
    }
    await _activateProfile(profile);
    return profile;
  }

  Future<Profile> importFile({
    required io.File file,
    required String name,
  }) async {
    final nodes = SubscriptionParser.parse(await file.readAsString());
    late final Profile profile;
    if (nodes != null) {
      profile = await _saveParsedProfile(
        nodes: nodes,
        subscribeUrl: Uri.file(file.path),
        isLocal: true,
        name: name,
      );
    } else {
      profile = await ProfileService().importProfile(
        subscribeLink: Uri.file(file.path),
        name: name,
      );
    }
    await _activateProfile(profile);
    return profile;
  }

  Future<Profile> refreshProfile(Profile profile) async {
    final link = Uri.tryParse(profile.typed.subscribeUrl ?? '');
    late final Profile updated;
    if (link != null && (link.scheme == 'http' || link.scheme == 'https')) {
      final response = await _fetchSubscription(link);
      final nodes = SubscriptionParser.parse(response.body);
      if (nodes != null) {
        updated = await _saveParsedProfile(
          nodes: nodes,
          subscribeUrl: link,
          isLocal: false,
          name: profile.name,
          headers: response.headers,
          existingId: profile.id,
        );
      } else {
        updated = await ProfileService().importProfile(id: profile.id);
      }
    } else {
      updated = await ProfileService().importProfile(id: profile.id);
    }
    if (selectedProfile?.id == updated.id) await _activateProfile(updated);
    return updated;
  }

  Future<Profile> updateProfile(
    Profile profile, {
    required String name,
    required Uri url,
  }) async {
    profile.name = name;
    profile.typed.subscribeUrl = url.toString();
    ProfileStorage().updateProfile(profile);
    return refreshProfile(profile);
  }

  Future<void> selectProfile(int id) async {
    final profile = ProfileStorage().getProfile(id);
    if (profile == null) throw StateError('找不到订阅配置');
    await _activateProfile(profile);
  }

  Future<void> deleteProfile(int id) async {
    final wasSelected = selectedProfile?.id == id;
    ProfileStorage().deleteProfile(id);
    if (wasSelected) {
      final next = selectedProfile;
      if (next != null) await _activateProfile(next);
    }
  }

  Future<void> startVpn() => _client.startVpn();
  Future<void> stopVpn() => _client.stopVpn();
  Future<void> reloadService() => _client.serviceReload();
  Future<void> selectOutbound({
    required String groupTag,
    required String nodeTag,
  }) => _client.selectOutbound(groupTag: groupTag, outboundTag: nodeTag);
  Future<void> testGroup(String groupTag) =>
      _client.urlTest(groupTag: groupTag);

  Future<String> singBoxVersion() => _client.getSingBoxVersion();

  /// 持久化的代理模式（ClashMode 常量值）。
  String get preferredMode => AppSettings().clashMode;

  /// 切换代理模式。未连接时 native 侧没有模式列表会直接报错，
  /// 所以只持久化并写进配置文件，等连接时生效。
  Future<void> setMode(String mode, {required bool connected}) async {
    AppSettings().clashMode = mode;
    if (connected) {
      await _client.setClashMode(mode);
    } else {
      await _patchUsingConfig();
    }
  }

  /// 拉取最新规则集并让运行中的服务立即生效。
  Future<void> updateRuleSets({required bool connected}) async {
    await ruleSets.update();
    if (connected) await _client.serviceReload();
  }

  Future<void> _activateProfile(Profile profile) async {
    ProfileStorage().setSelectedProfile(profile.id);
    final config = await ProfileStorage().getUsingConfig();
    await io.File(profile.typed.path).copy(config.path);
    await _patchUsingConfig();
  }

  /// 对即将使用的配置做本地化修正：
  /// - 远程规则集改为内置/已下载的本地文件（远端地址在国内直连拉不动）；
  /// - 未识别的远程规则集下载改走代理；
  /// - 写入持久化的默认代理模式。
  Future<void> _patchUsingConfig() async {
    final file = await ProfileStorage().getUsingConfig();
    if (!await file.exists()) return;
    final dynamic config = jsonDecode(await file.readAsString());
    if (config is! Map<String, dynamic>) return;

    final experimental =
        (config['experimental'] as Map<String, dynamic>?) ?? {};
    final clashApi = (experimental['clash_api'] as Map<String, dynamic>?) ?? {};
    clashApi['default_mode'] = preferredMode;
    experimental['clash_api'] = clashApi;
    config['experimental'] = experimental;

    final route = config['route'];
    if (route is Map<String, dynamic> && route['rule_set'] is List) {
      for (final ruleSet
          in (route['rule_set'] as List).whereType<Map<String, dynamic>>()) {
        final localPath = ruleSets.localPaths[ruleSet['tag']];
        if (localPath != null) {
          ruleSet
            ..remove('url')
            ..remove('download_detour')
            ..remove('update_interval')
            ..['type'] = 'local'
            ..['path'] = localPath;
        } else if (ruleSet['type'] == 'remote') {
          ruleSet['download_detour'] = FlutterSingBoxConstants.defaultGroup;
        }
      }
    }
    await file.writeAsString(jsonEncode(config));
  }

  Future<http.Response> _fetchSubscription(Uri url) async {
    final response = await http
        .get(
          url,
          headers: const {
            'Accept':
                'application/json, application/yaml;q=0.9, text/plain;q=0.8',
            'User-Agent': 'FLsing/1.0',
          },
        )
        .timeout(const Duration(seconds: 20));
    // 很多订阅服务器把 Content-Type 标成 text/html，只能根据正文判断是否真的是网页。
    final content = response.body.trimLeft().toLowerCase();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SubscriptionImportException('订阅服务器返回 HTTP ${response.statusCode}');
    }
    if (content.startsWith('<!doctype html') || content.startsWith('<html')) {
      throw SubscriptionImportException(
        '订阅服务器返回了网页，可能需要调整代理线路或关闭 Cloudflare 人机验证',
      );
    }
    if (content.isEmpty) throw SubscriptionImportException('订阅服务器返回了空内容');
    return response;
  }

  /// 用插件自带的模板配置 + 解析出的节点组装完整 sing-box 配置并落盘。
  Future<Profile> _saveParsedProfile({
    required List<Map<String, dynamic>> nodes,
    required Uri subscribeUrl,
    required bool isLocal,
    String? name,
    Map<String, String> headers = const {},
    int? existingId,
  }) async {
    if (nodes.isEmpty) {
      throw const SubscriptionImportException('订阅中没有可识别的节点');
    }
    final template =
        jsonDecode(
              await rootBundle.loadString(
                FlutterSingBoxConstants.templateConfig,
              ),
            )
            as Map<String, dynamic>;
    final tags = nodes.map((node) => node['tag'] as String).toList();
    template['outbounds'] = [
      {
        'tag': FlutterSingBoxConstants.defaultGroup,
        'type': OutboundType.selector,
        'outbounds': ['auto', ...tags],
        'default': 'auto',
      },
      {
        'tag': 'auto',
        'type': OutboundType.urltest,
        'outbounds': tags,
        'url': FlutterSingBoxConstants.defaultTestUrl,
        'interval': FlutterSingBoxConstants.defaultUrlTestInterval,
        'tolerance': FlutterSingBoxConstants.defaultUrlTestTolerance,
      },
      ...nodes,
      {'tag': OutboundType.direct, 'type': OutboundType.direct},
    ];
    final storage = ProfileStorage();
    final id = existingId ?? storage.generateProfileId;
    final path = await storage.getProfilePath(id);
    await io.File(path).writeAsString(jsonEncode(template));
    final existing = existingId == null ? null : storage.getProfile(id);
    final resolvedName = (name?.trim().isNotEmpty ?? false)
        ? name!.trim()
        : _nameFromHeaders(headers) ?? subscribeUrl.host;
    final profile = Profile(
      id: id,
      order: existing?.order ?? id,
      name: resolvedName,
      outboundsCount: nodes.length,
      typed: TypedProfile(
        type: isLocal ? ProfileType.local : ProfileType.remote,
        path: path,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
        subscribeUrl: subscribeUrl.toString(),
        webPageUrl: headers['profile-web-page-url'] ?? subscribeUrl.host,
      ),
      userInfo: _userInfoFromHeaders(headers),
    );
    storage.updateProfile(profile);
    if (storage.getSelectedProfile() == null) storage.setSelectedProfile(id);
    return profile;
  }

  String? _nameFromHeaders(Map<String, String> headers) {
    try {
      final disposition = headers['content-disposition'];
      if (disposition != null) {
        const marker = "''";
        final index = disposition.lastIndexOf(marker);
        if (index != -1) {
          return Uri.decodeFull(disposition.substring(index + marker.length));
        }
      }
      final title = headers['profile-title'];
      if (title != null) {
        const prefix = 'base64:';
        if (title.startsWith(prefix)) {
          return utf8.decode(base64Decode(title.substring(prefix.length)));
        }
        return title;
      }
    } catch (_) {}
    return null;
  }

  UserInfo? _userInfoFromHeaders(Map<String, String> headers) {
    final raw = headers['subscription-userinfo'];
    if (raw == null) return null;
    final values = <String, int>{};
    for (final pair in raw.split(';')) {
      final parts = pair.trim().split('=');
      if (parts.length != 2) continue;
      final value = int.tryParse(parts[1]);
      if (value != null) values[parts[0].toLowerCase()] = value;
    }
    if (values.isEmpty) return null;
    return UserInfo(
      upload: values['upload'],
      download: values['download'],
      total: values['total'],
      expire: values['expire'],
    );
  }

  Future<ConfiguredNodeGroup?> configuredNodeGroup(Profile profile) async {
    final value = jsonDecode(await io.File(profile.typed.path).readAsString());
    if (value is! Map<String, dynamic> || value['outbounds'] is! List) {
      return null;
    }
    final outbounds = (value['outbounds'] as List)
        .whereType<Map<String, dynamic>>()
        .toList();
    final byTag = <String, Map<String, dynamic>>{
      for (final outbound in outbounds)
        if (outbound['tag'] is String) outbound['tag'] as String: outbound,
    };
    for (final outbound in outbounds) {
      final tags = outbound['outbounds'];
      if (outbound['tag'] is! String || tags is! List || tags.isEmpty) continue;
      final nodes = tags.whereType<String>().map((tag) {
        final item = byTag[tag];
        return ConfiguredNode(
          tag: tag,
          type: item?['type'] as String? ?? 'proxy',
          server: item?['server'] as String?,
          serverPort: (item?['server_port'] as num?)?.toInt(),
        );
      }).toList();
      if (nodes.isNotEmpty) {
        return ConfiguredNodeGroup(
          tag: outbound['tag'] as String,
          selected: outbound['default'] as String? ?? nodes.first.tag,
          nodes: nodes,
        );
      }
    }
    return null;
  }
}

class ConfiguredNodeGroup {
  const ConfiguredNodeGroup({
    required this.tag,
    required this.selected,
    required this.nodes,
  });

  final String tag;
  final String selected;
  final List<ConfiguredNode> nodes;
}

class ConfiguredNode {
  const ConfiguredNode({
    required this.tag,
    required this.type,
    this.server,
    this.serverPort,
  });

  final String tag;
  final String type;
  final String? server;
  final int? serverPort;
}

class SubscriptionImportException implements Exception {
  const SubscriptionImportException(this.message);

  final String message;

  @override
  String toString() => message;
}
