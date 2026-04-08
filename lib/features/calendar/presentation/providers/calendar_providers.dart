import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/calendar_repository.dart';
import '../../domain/calendar_event.dart';

/// 캘린더 저장소 프로바이더
final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository();
});

/// 선택된 날짜
final selectedDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

/// 현재 보고 있는 월의 이벤트
final selectedMonthEventsProvider =
    AsyncNotifierProvider<SelectedMonthEventsNotifier, List<CalendarEvent>>(
  SelectedMonthEventsNotifier.new,
);

/// 월 이벤트 관리 노티파이어
class SelectedMonthEventsNotifier extends AsyncNotifier<List<CalendarEvent>> {
  @override
  Future<List<CalendarEvent>> build() async {
    final selectedDate = ref.watch(selectedDateProvider);
    final repository = ref.watch(calendarRepositoryProvider);
    return repository.getEventsByMonth(selectedDate.year, selectedDate.month);
  }

  /// 이벤트 추가
  Future<void> addEvent(CalendarEvent event) async {
    final repository = ref.read(calendarRepositoryProvider);
    await repository.createEvent(event);
    ref.invalidateSelf();
  }

  /// 이벤트 수정
  Future<void> updateEvent(CalendarEvent event) async {
    final repository = ref.read(calendarRepositoryProvider);
    await repository.updateEvent(event);
    ref.invalidateSelf();
  }

  /// 이벤트 삭제
  Future<void> deleteEvent(int id) async {
    final repository = ref.read(calendarRepositoryProvider);
    await repository.deleteEvent(id);
    ref.invalidateSelf();
  }
}

/// 선택된 날짜의 이벤트 (월 이벤트에서 필터링)
final selectedDateEventsProvider = Provider<AsyncValue<List<CalendarEvent>>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final monthEvents = ref.watch(selectedMonthEventsProvider);

  return monthEvents.whenData((events) {
    final dateStr = _formatDate(selectedDate);
    return events.where((e) => e.eventDate == dateStr).toList();
  });
});

/// 월 이벤트를 날짜별 Map으로 변환
final monthEventsMapProvider =
    Provider<AsyncValue<Map<String, List<CalendarEvent>>>>((ref) {
  final monthEvents = ref.watch(selectedMonthEventsProvider);

  return monthEvents.whenData((events) {
    final map = <String, List<CalendarEvent>>{};
    for (final event in events) {
      map.putIfAbsent(event.eventDate, () => []).add(event);
    }
    return map;
  });
});

/// 현재 월의 이벤트를 날짜별로 그룹화하여 정렬된 리스트로 반환
final monthEventsGroupedProvider =
    Provider<AsyncValue<List<MapEntry<String, List<CalendarEvent>>>>>((ref) {
  final monthEvents = ref.watch(selectedMonthEventsProvider);

  return monthEvents.whenData((events) {
    final map = <String, List<CalendarEvent>>{};
    for (final event in events) {
      map.putIfAbsent(event.eventDate, () => []).add(event);
    }
    // 날짜순 정렬
    final sorted = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted;
  });
});

String _formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
