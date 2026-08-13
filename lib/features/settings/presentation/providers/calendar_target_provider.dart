import 'dart:io';

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

/// Google 캘린더 연동을 이 플랫폼에서 제공하는지. **판정은 여기 한 곳뿐이다** —
/// 설정 선택지와 스와이프 분기가 같은 값을 봐야 "고를 수 없는데 스와이프는
/// 가는" 막다른 길이 생기지 않는다.
///
/// 안드로이드에서 감추는 이유: 안드로이드의 "기기 캘린더"는 `CalendarContract`이고
/// 그 안이 이미 동기화된 **구글 캘린더**다(실측 — 저장한 이벤트가
/// `account_type=com.google` 캘린더에 들어갔다). 즉 REST API 경로는 같은 곳에
/// 두 번 가는 중복인데, 값은 GCP Android OAuth 클라이언트 등록 + 동의 화면
/// 검증이다. 등록이 없으면 사용자에게는 `ApiException: 10`(DEVELOPER_ERROR)로만
/// 보인다(실측 2026-08-03).
///
/// iOS는 다르다 — EventKit은 iCloud/로컬이라 구글로 가는 **유일한 길**이 이 경로다.
///
/// ⚠️ `defaultTargetPlatform`이 아니라 `dart:io`의 `Platform.isAndroid`를 쓴다.
/// 전자는 `flutter test`에서 항상 android로 강제돼, macOS 호스트의 위젯 테스트
/// 전체가 안드로이드 분기를 타 버린다. `Platform.isAndroid`는 위젯 테스트로 직접
/// 못 밟으므로 **provider로 감싸 override 가능하게** 둔다.
final googleTargetSupportedProvider = Provider<bool>(
  (_) => !Platform.isAndroid,
);

/// 현재 선택된 캘린더 연동 대상. SharedPreferences에 영속.
final calendarTargetProvider =
    AsyncNotifierProvider<CalendarTargetNotifier, CalendarTarget>(
      CalendarTargetNotifier.new,
    );

class CalendarTargetNotifier extends AsyncNotifier<CalendarTarget> {
  @override
  Future<CalendarTarget> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = CalendarTarget.fromValue(prefs.getString(_prefKey));
    // 지원하지 않는 플랫폼에 남아 있는 선택은 none으로 낮춘다. 저장값을 지우지는
    // 않는다 — 값을 건드리지 않아도 이 한 줄이 설정 라벨과 스와이프 분기를 함께
    // 막고, 지원되는 플랫폼에서는 선택이 그대로 살아난다.
    if (stored == CalendarTarget.google &&
        !ref.read(googleTargetSupportedProvider)) {
      return CalendarTarget.none;
    }
    return stored;
  }

  /// 사용자 선택 변경 → SharedPreferences에 저장 + 상태 갱신.
  /// 동일 값이면 no-op (중복 SharedPreferences write 방지).
  Future<void> setTarget(CalendarTarget target) async {
    if (state.valueOrNull == target) return;
    state = AsyncData(target);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, target.prefValue);
  }
}
