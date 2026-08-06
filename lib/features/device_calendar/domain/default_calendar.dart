import 'package:device_calendar/device_calendar.dart';

/// 저장할 기본 캘린더를 고른다. **순수 함수** — 플랫폼 호출 없이 테스트한다
/// (`buildTodayView`·`busPollIntervalFor`와 같은 자리).
///
/// 규칙은 셋이고 순서가 곧 우선순위다.
///
/// 1. **쓸 수 있어야 한다** — 읽기 전용(공휴일·생일 등)은 후보가 아니다.
/// 2. **계정 캘린더를 로컬보다 먼저 본다.** 삼성의 `My calendar`처럼 기기 전용인
///    캘린더는 동기화되지 않아 PC에서 안 보이고 기기를 바꾸면 사라진다 —
///    "캘린더로 보낸다"고 할 때 기대하는 것과 정반대다. 로컬을 **금지**하는 것이
///    아니라 **후순위**로 둔다: 계정이 없는 기기에서는 로컬이 유일한 정답이다.
/// 3. 남은 후보가 여럿이면 `isDefault`를 본다.
///
/// ⚠️ **`isDefault`를 1순위로 쓰면 안 된다.** Galaxy A34 실측(2026-08-06)에서
/// 캘린더 여섯 개가 **전부** `isPrimary=1`로 왔다. 그 값이 아무것도 구분해주지
/// 못하니 판정이 커서 순서 첫 번째로 떨어졌고, 그게 로컬이라 저장한 일정이
/// 구글 캘린더에 나타나지 않았다.
Calendar? pickDefaultCalendar(List<Calendar> calendars) {
  final writable = calendars.where((c) => c.isReadOnly == false).toList();
  if (writable.isEmpty) return null;

  final accountBacked = writable.where((c) => !_isLocal(c)).toList();
  final pool = accountBacked.isNotEmpty ? accountBacked : writable;

  return pool.firstWhere((c) => c.isDefault == true, orElse: () => pool.first);
}

/// 기기 전용 캘린더인지. Android는 `LOCAL`, iOS(EventKit)는 `Local`로 온다 —
/// 대소문자가 달라 그대로 비교하면 한쪽을 놓친다.
bool _isLocal(Calendar c) => (c.accountType ?? '').toLowerCase() == 'local';
