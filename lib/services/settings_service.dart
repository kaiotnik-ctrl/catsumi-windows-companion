import 'dart:convert';
import 'dart:io';

import '../models/pet_settings.dart';

class SettingsService {
  File get _file {
    final appData = Platform.environment['APPDATA'];
    final base = appData == null || appData.isEmpty
        ? Directory.systemTemp.path
        : appData;
    return File(
      '$base${Platform.pathSeparator}Catsumi${Platform.pathSeparator}settings.json',
    );
  }

  Future<PetSettings> load() async {
    try {
      if (!await _file.exists()) return const PetSettings();
      final json =
          jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      return PetSettings.fromJson(json);
    } catch (_) {
      return const PetSettings();
    }
  }

  Future<void> save(PetSettings settings) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
    );
  }
}
