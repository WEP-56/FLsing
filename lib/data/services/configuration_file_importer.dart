import 'package:flutter/services.dart';

class ConfigurationFileImporter {
  static const _channel = MethodChannel('flsing/configuration_file');

  Future<String?> pickFile() => _channel.invokeMethod<String>('pickFile');
}
