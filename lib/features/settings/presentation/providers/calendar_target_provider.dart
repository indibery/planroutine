import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 캘린더 외부 저장 대상.
enum CalendarTarget {
  none,
  google,
  device;

  String get prefValue => name;

  static CalendarTarget fromValue(String? v) {
    if (v == null || v.isEmpty) return CalendarTarget.none;
    return values.firstWhere(
      (t) => t.name == v,
      orElse: () => CalendarTarget.none,
    );
  }
}

/// SharedPreferences 키.
const _prefKey = 'calendar_target';

/// 현재 선택된 캘린더 연동 대상. SharedPreferences에 영속.
final calendarTargetProvider =
    AsyncNotifierProvider<CalendarTargetNotifier, CalendarTarget>(
  CalendarTargetNotifier.new,
);

class CalendarTargetNotifier extends AsyncNotifier<CalendarTarget> {
  @override
  Future<CalendarTarget> build() async {
    final prefs = await SharedPreferences.getInstance();
    return CalendarTarget.fromValue(prefs.getString(_prefKey));
  }

  /// 사용자 선택 변경 → SharedPreferences에 저장 + 상태 갱신.
  Future<void> setTarget(CalendarTarget target) async {
    state = AsyncData(target);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, target.prefValue);
  }
}
