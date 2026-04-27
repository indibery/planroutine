import 'package:device_calendar/device_calendar.dart';

/// 시스템 캘린더(iOS EventKit / Android CalendarContract) 통합 래퍼.
///
/// 단방향 동기화: 플랜루틴에서 만든 이벤트를 사용자 기기의 기본 캘린더로
/// **생성/갱신**한다. 양방향 동기화는 안 함.
class DeviceCalendarService {
  DeviceCalendarService() : _plugin = DeviceCalendarPlugin();

  final DeviceCalendarPlugin _plugin;

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
  /// 반환: device 측 event id (이후 update 용도로 보관).
  Future<String> saveEvent({
    String? existingId,
    required String title,
    String? description,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    final calendarId = await _resolveDefaultCalendarId();
    if (calendarId == null) {
      throw const DeviceCalendarException('writable 캘린더가 없습니다');
    }

    final event = Event(
      calendarId,
      eventId: existingId,
      title: title,
      description: description,
      start: TZDateTime.from(startDate, local),
      end: TZDateTime.from(endDate ?? startDate, local),
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
      throw DeviceCalendarException(
        result?.errors.map((e) => e.errorMessage).join(', ') ??
            '이벤트 저장 실패',
      );
    }
    return result!.data!;
  }

  /// 기본 쓰기 가능 캘린더 id. isDefault==true 우선, 없으면 첫 번째 writable.
  Future<String?> _resolveDefaultCalendarId() async {
    final result = await _plugin.retrieveCalendars();
    final calendars = result.data;
    if (calendars == null || calendars.isEmpty) return null;

    final writable = calendars.where((c) => c.isReadOnly == false).toList();
    if (writable.isEmpty) return null;

    return writable.firstWhere(
      (c) => c.isDefault == true,
      orElse: () => writable.first,
    ).id;
  }
}

class DeviceCalendarException implements Exception {
  const DeviceCalendarException(this.message);
  final String message;
  @override
  String toString() => 'DeviceCalendarException: $message';
}
