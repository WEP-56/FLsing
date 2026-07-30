import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateService {
  static const _latestReleaseUri =
      'https://api.github.com/repos/WEP-56/FLsing/releases/latest';
  static const _installerChannel = MethodChannel('flsing/app_update');

  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  Future<UpdateCheckResult> checkForUpdate() async {
    final current = await currentVersion();
    final response = await http.get(
      Uri.parse(_latestReleaseUri),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'FLsing-Android',
      },
    );
    if (response.statusCode != HttpStatus.ok) {
      throw UpdateException('检查更新失败（HTTP ${response.statusCode}）');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const UpdateException('GitHub 返回了无效的更新信息');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const UpdateException('GitHub 返回了无效的更新信息');
    }

    final tag = decoded['tag_name'] as String?;
    final assets = decoded['assets'];
    if (tag == null || assets is! List) {
      throw const UpdateException('Release 缺少版本号或安装包');
    }
    final apk = _selectApk(assets);
    if (apk == null) {
      throw const UpdateException('最新 Release 中没有可下载的 APK');
    }

    final release = UpdateRelease(
      version: normalizeVersion(tag),
      tag: tag,
      apkName: apk.$1,
      apkUri: apk.$2,
      apkSize: apk.$3,
    );
    return UpdateCheckResult(
      currentVersion: current,
      release: release,
      hasUpdate: compareVersions(release.version, current) > 0,
    );
  }

  Future<File> downloadApk(
    UpdateRelease release, {
    required void Function(int received, int? total) onProgress,
  }) async {
    final client = http.Client();
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}updates',
    );
    await directory.create(recursive: true);
    final safeName = release.apkName.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    final target = File('${directory.path}${Platform.pathSeparator}$safeName');
    final partial = File('${target.path}.download');
    if (await partial.exists()) await partial.delete();

    IOSink? sink;
    try {
      final request = http.Request('GET', release.apkUri)
        ..headers['Accept'] = 'application/octet-stream'
        ..headers['User-Agent'] = 'FLsing-Android';
      final response = await client.send(request);
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateException('下载安装包失败（HTTP ${response.statusCode}）');
      }

      final total =
          response.contentLength ??
          (release.apkSize > 0 ? release.apkSize : null);
      var received = 0;
      sink = partial.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (total != null && received != total) {
        throw const UpdateException('安装包下载不完整，请重试');
      }
      if (await target.exists()) await target.delete();
      return partial.rename(target.path);
    } finally {
      await sink?.close();
      client.close();
      if (await partial.exists()) await partial.delete();
    }
  }

  Future<void> installApk(File apk) async {
    if (!Platform.isAndroid) {
      throw const UpdateException('当前平台不支持应用内安装');
    }
    await _installerChannel.invokeMethod<void>('installApk', apk.path);
  }

  static (String, Uri, int)? _selectApk(List<dynamic> assets) {
    final apks = <(String, Uri, int)>[];
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = asset['name'] as String?;
      final url = asset['browser_download_url'] as String?;
      final uri = url == null ? null : Uri.tryParse(url);
      if (name == null ||
          !name.toLowerCase().endsWith('.apk') ||
          uri == null ||
          uri.scheme != 'https') {
        continue;
      }
      apks.add((name, uri, (asset['size'] as num?)?.toInt() ?? 0));
    }
    if (apks.isEmpty) return null;
    return apks.firstWhere(
      (asset) => asset.$1.toLowerCase().contains('universal'),
      orElse: () => apks.first,
    );
  }

  static String normalizeVersion(String value) {
    final match = RegExp(r'^[vV]?(\d+(?:\.\d+){0,3})').firstMatch(value.trim());
    if (match == null) throw UpdateException('无法识别版本号：$value');
    return match.group(1)!;
  }

  static int compareVersions(String left, String right) {
    final a = normalizeVersion(left).split('.').map(int.parse).toList();
    final b = normalizeVersion(right).split('.').map(int.parse).toList();
    for (var index = 0; index < 4; index++) {
      final av = index < a.length ? a[index] : 0;
      final bv = index < b.length ? b[index] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.release,
    required this.hasUpdate,
  });

  final String currentVersion;
  final UpdateRelease release;
  final bool hasUpdate;
}

class UpdateRelease {
  const UpdateRelease({
    required this.version,
    required this.tag,
    required this.apkName,
    required this.apkUri,
    required this.apkSize,
  });

  final String version;
  final String tag;
  final String apkName;
  final Uri apkUri;
  final int apkSize;
}

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
