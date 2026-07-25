import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../today/domain/stamp_settings.dart';

const _prefsKey = 'stamp_settings_v1';

/// 완료 도장 설정 — 오늘 탭이 소비하고 설정 탭이 변경한다. SharedPreferences 저장.
final stampSettingsProvider =
    AsyncNotifierProvider<StampSettingsNotifier, StampSettings>(
  StampSettingsNotifier.new,
);

class StampSettingsNotifier extends AsyncNotifier<StampSettings> {
  @override
  Future<StampSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return StampSettings.defaults;
    try {
      return StampSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // 손상된 값이면 기본 도장으로
      return StampSettings.defaults;
    }
  }

  Future<void> setStyle(SealStyle style) =>
      _save(_current.copyWith(style: style));

  Future<void> setDimPreviousStamps(bool value) =>
      _save(_current.copyWith(dimPreviousStamps: value));

  StampSettings get _current => state.valueOrNull ?? StampSettings.defaults;

  Future<void> _save(StampSettings next) async {
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(next.toJson()));
  }
}
