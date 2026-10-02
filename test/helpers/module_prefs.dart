import 'dart:convert';

import 'package:planroutine/core/modules/installed_modules_provider.dart';
import 'package:planroutine/features/bus/domain/bus_settings.dart';
import 'package:planroutine/features/bus/presentation/providers/bus_providers.dart';

/// `SharedPreferences.setMockInitialValues`에 넘길 값.
///
/// [installed]는 고정 탭을 뺀 선택 기능 id만 적어도 된다 — `resolveModules`가
/// 고정 탭을 채운다. 키를 **항상** 넣어 이전 로직이 끼어들지 않게 한다.
Map<String, Object> modulePrefs({
  List<String> installed = const [],
  BusSettings? bus,
}) => {
  installedModulesPrefsKey: jsonEncode(installed),
  if (bus != null) busSettingsPrefsKey: jsonEncode(bus.toJson()),
};
