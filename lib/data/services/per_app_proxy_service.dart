import 'package:flutter_sing_box/flutter_sing_box.dart';

enum PerAppProxyMode { disabled, include, exclude }

class PerAppProxyService {
  static const _disabled = 0;
  static const _include = 1;
  static const _exclude = 2;

  final CsSettingsStorage _storage = CsSettingsStorage();

  PerAppProxyMode get mode => switch (_storage.getPerAppProxyMode()) {
    _include => PerAppProxyMode.include,
    _exclude => PerAppProxyMode.exclude,
    _ => PerAppProxyMode.disabled,
  };

  List<String> get selectedPackages {
    final current = mode;
    return current == PerAppProxyMode.disabled
        ? const []
        : packagesFor(current);
  }

  List<String> packagesFor(PerAppProxyMode mode) =>
      mode == PerAppProxyMode.disabled
      ? const []
      : _storage.getAppList(_storageMode(mode));

  void save({
    required PerAppProxyMode mode,
    required Iterable<String> packages,
  }) {
    final storageMode = _storageMode(mode);
    if (storageMode == _disabled) {
      _storage.setPerAppProxyMode(_disabled);
      return;
    }
    _storage.setAppList(packages.toSet().toList()..sort(), storageMode);
  }

  int _storageMode(PerAppProxyMode mode) => switch (mode) {
    PerAppProxyMode.disabled => _disabled,
    PerAppProxyMode.include => _include,
    PerAppProxyMode.exclude => _exclude,
  };
}
