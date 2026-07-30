import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'app_settings.dart';

/// 管理 sing-box 规则集：首次运行释放内置版本，之后可从远程拉取更新。
class RuleSetService {
  static const _remoteBase = {
    'geoip-cn':
        'https://testingcf.jsdelivr.net/gh/SagerNet/sing-geoip@rule-set/geoip-cn.srs',
    'geosite-cn':
        'https://testingcf.jsdelivr.net/gh/SagerNet/sing-geosite@rule-set/geosite-cn.srs',
  };

  final Map<String, String> _localPaths = {};

  /// tag → 本地 .srs 文件路径，仅在 [ensureInstalled] 之后可用。
  Map<String, String> get localPaths => Map.unmodifiable(_localPaths);

  /// 释放内置规则集到文档目录（已存在则跳过），返回本地路径表。
  Future<void> ensureInstalled() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/rule_sets');
    if (!await dir.exists()) await dir.create(recursive: true);
    for (final tag in _remoteBase.keys) {
      final file = File('${dir.path}/$tag.srs');
      if (!await file.exists()) {
        final data = await rootBundle.load('assets/rule_sets/$tag.srs');
        await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
      _localPaths[tag] = file.path;
    }
  }

  /// 从远程拉取最新规则集覆盖本地文件。任何一个失败则整体抛异常。
  Future<void> update() async {
    if (_localPaths.isEmpty) await ensureInstalled();
    for (final entry in _remoteBase.entries) {
      final response = await http
          .get(Uri.parse(entry.value))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception('下载 ${entry.key} 失败（HTTP ${response.statusCode}）');
      }
      // 先写临时文件再替换，避免下载中断留下损坏的规则集。
      final target = File(_localPaths[entry.key]!);
      final temp = File('${target.path}.tmp');
      await temp.writeAsBytes(response.bodyBytes, flush: true);
      await temp.rename(target.path);
    }
    AppSettings().ruleSetUpdatedAt = DateTime.now().millisecondsSinceEpoch;
  }
}
