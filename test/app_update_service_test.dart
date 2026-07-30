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
}
