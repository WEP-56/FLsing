import 'package:flutter_test/flutter_test.dart';

import 'package:flsing/data/services/app_update_service.dart';

void main() {
  group('AppUpdateService version comparison', () {
    test('accepts GitHub tags with a v prefix', () {
      expect(AppUpdateService.normalizeVersion('v1.0.1'), '1.0.1');
    });

    test('detects a newer patch release', () {
      expect(
        AppUpdateService.compareVersions('v1.0.1', '1.0.0'),
        greaterThan(0),
      );
    });

    test('treats missing version parts as zero', () {
      expect(AppUpdateService.compareVersions('1.0', '1.0.0'), 0);
    });

    test('does not downgrade to an older release', () {
      expect(AppUpdateService.compareVersions('v0.9.9', '1.0.0'), lessThan(0));
    });
  });

  group('AppUpdateService APK selection', () {
    const assets = [
      'FLsing-1.0.1-arm64-v8a.apk',
      'FLsing-1.0.1-armeabi-v7a.apk',
      'FLsing-1.0.1-universal.apk',
      'FLsing-1.0.1-x86_64.apk',
    ];

    test('prefers the primary device ABI over universal', () {
      expect(
        AppUpdateService.selectApkNameForAbis(assets, const [
          'arm64-v8a',
          'armeabi-v7a',
        ]),
        'FLsing-1.0.1-arm64-v8a.apk',
      );
    });

    test('selects x86_64 without confusing it with another ABI', () {
      expect(
        AppUpdateService.selectApkNameForAbis(assets, const ['x86_64']),
        'FLsing-1.0.1-x86_64.apk',
      );
    });

    test('does not match x86 to x86_64', () {
      expect(
        AppUpdateService.selectApkNameForAbis(assets, const ['x86']),
        'FLsing-1.0.1-universal.apk',
      );
    });

    test('falls back to universal for an unavailable ABI', () {
      expect(
        AppUpdateService.selectApkNameForAbis(assets, const ['riscv64']),
        'FLsing-1.0.1-universal.apk',
      );
    });
  });
}
