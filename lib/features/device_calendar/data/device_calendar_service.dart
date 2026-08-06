import 'package:device_calendar/device_calendar.dart';

import '../domain/default_calendar.dart';

/// 시스템 캘린더(iOS EventKit / Android CalendarContract) 통합 래퍼.
///
/// 단방향 동기화: 플랜루틴에서 만든 이벤트를 사용자 기기의 기본 캘린더로
/// **생성/갱신**한다. 양방향 동기화는 안 함.
class DeviceCalendarService {
  DeviceCalendarService() : _plugin = DeviceCalendarPlugin();

  final DeviceCalendarPlugin _plugin;

  /// 기본 쓰기 가능 캘린더 캐시. 사용자가 OS 설정에서 캘린더 추가/삭제하기
  /// 전엔 변하지 않으므로 lifetime 동안 한 번만 조회. 저장 실패 시
  /// 무효화돼 다음 호출에서 재조회.
  Calendar? _cachedCalendar;

  /// 캘린더 권한 보유 여부.
  Future<bool> hasPermissions() async {
    final result = await _plugin.hasPermissions();
    return result.data ?? false;
  }

  /// 권한 요청. 사용자가 거부하면 false 반환.
  Future<bool> requestPermissions() async {
    final result = await _plugin.requestPermissions();
    return result.data ?? false;
  }

  /// 이벤트 생성 또는 갱신. [existingId]가 있으면 update, 없으면 create.
  /// update 실패(이벤트가 OS에서 삭제됨)면 새로 create.
  ///
  /// 반환: device 측 event id(이후 update 용도로 보관) + **저장한 캘린더 이름**.
  /// 이름을 함께 돌려주는 이유는 화면이 그것을 사용자에게 보여주기 때문이다 —
  /// 앱이 캘린더를 대신 고르므로, 어디로 갔는지 말해주지 않으면 "저장했다는데
  /// 구글 캘린더에 없다"가 된다(실기기 2026-08-06).
  Future<({String eventId, String calendarName})> saveEvent({
    String? existingId,
    required String title,
    String? description,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    final calendar = await _resolveDefaultCalendar();
    final calendarId = calendar?.id;
    if (calendarId == null) {
      throw const DeviceCalendarException('writable 캘린더가 없습니다');
    }

    // allDay 이벤트는 startDate/endDate를 그 날의 정오(12:00)로 정규화한다.
    // DateTime.parse("YYYY-MM-DD")는 local 자정이라 timezone 변환 시 전날로
    // 밀리는 케이스가 있다. 정오로 옮기면 ±12시간 오차도 같은 달력 날짜를 유지.
    // end가 start와 같으면 EventKit이 0초 이벤트로 처리해 표시 위치가
    // 이상해지는 사례가 있어 +1분 차이를 둔다.
    DateTime noon(DateTime d) => DateTime(d.year, d.month, d.day, 12);
    final start = noon(startDate);
    final end = endDate != null
        ? noon(endDate).add(const Duration(minutes: 1))
        : start.add(const Duration(minutes: 1));

    final event = Event(
      calendarId,
      eventId: existingId,
      title: title,
      description: description,
      start: TZDateTime.from(start, local),
      end: TZDateTime.from(end, local),
      allDay: true,
    );

    final result = await _plugin.createOrUpdateEvent(event);
    if (result?.isSuccess != true || result?.data == null) {
      // existingId가 stale일 수 있으므로 한 번 더 (eventId 비우고) create 재시도
      if (existingId != null) {
        return saveEvent(
          existingId: null,
          title: title,
          description: description,
          startDate: startDate,
          endDate: endDate,
        );
      }
      // 캐시된 캘린더가 stale일 수 있으므로 무효화 → 다음 호출에서 재조회
      _cachedCalendar = null;
      throw DeviceCalendarException(
        result?.errors.map((e) => e.errorMessage).join(', ') ??
            '이벤트 저장 실패',
      );
    }
    return (
      eventId: result!.data!,
      calendarName: calendar!.name ?? calendar.accountName ?? '',
    );
  }

  /// 저장할 기본 캘린더. 캐시된 값이 있으면 재사용해 매 saveEvent마다
  /// platform channel round-trip을 피한다.
  ///
  /// 고르는 규칙 자체는 순수 함수 [pickDefaultCalendar]에 있다 — 플랫폼 호출과
  /// 분리해 두면 실기기 구성을 픽스처로 재현해 테스트할 수 있다.
  Future<Calendar?> _resolveDefaultCalendar() async {
    final cached = _cachedCalendar;
    if (cached != null) return cached;

    final result = await _plugin.retrieveCalendars();
    final calendars = result.data;
    if (calendars == null || calendars.isEmpty) return null;

    return _cachedCalendar = pickDefaultCalendar(calendars);
  }
}

class DeviceCalendarException implements Exception {
  const DeviceCalendarException(this.message);
  final String message;
  @override
  String toString() => 'DeviceCalendarException: $message';
}
