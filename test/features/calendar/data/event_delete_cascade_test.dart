import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';

import '../../../helpers/test_database.dart';

/// 캘린더에서 지운 일정의 **원본 행까지 함께** 휴지통으로 보내는 연쇄 삭제 가드.
///
/// 이것이 없으면 사용자가 캘린더에서 지운 행사를 다시 넣을 수 없다 —
/// 중복 판정(`title + scheduled_date`)이 살아남은 원본 행에 걸려 조용히 스킵된다.
/// 실기기 신고(2026-09-11): "캘린더에서 지웠는데 중복이라며 안 들어간다".
void main() {
  setUpAll(setUpFfiForTests);

  late DatabaseHelper db;
  late CalendarRepository calendarRepo;
  late ScheduleRepository scheduleRepo;

  setUp(() {
    db = freshDatabaseHelper();
    calendarRepo = CalendarRepository(dbHelper: db);
    scheduleRepo = ScheduleRepository(dbHelper: db);
  });

  tearDown(() async {
    await db.close();
  });

  /// 사진 AI로 넣고 확정하는 실제 흐름을 그대로 태운다.
  /// 반환: (원본 일정 id, 캘린더 이벤트 id)
  Future<({int scheduleId, int eventId})> registerAndConfirm({
    String title = '가을 운동회',
    String date = '2026-10-15',
  }) async {
    final now = DateTime.now().toIso8601String();
    final scheduleId = await scheduleRepo.insertConfirmedOrPending(
      Schedule(
        title: title,
        scheduledDate: date,
        status: ScheduleStatus.pending,
        kind: EntryKind.event,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await scheduleRepo.updateStatus(scheduleId, ScheduleStatus.confirmed);
    final eventId = await calendarRepo.createFromSchedule(scheduleId);
    return (scheduleId: scheduleId, eventId: eventId);
  }

  group('deleteEvent 연쇄', () {
    test('캘린더 이벤트를 지우면 연결된 원본 일정도 휴지통으로 간다', () async {
      final ids = await registerAndConfirm();

      await calendarRepo.deleteEvent(ids.eventId);

      final active = await scheduleRepo.getSchedules();
      expect(active, isEmpty, reason: '원본 일정이 활성 목록에 남으면 안 된다');
      final trashed = await scheduleRepo.getDeletedSchedules();
      expect(trashed.map((s) => s.id), contains(ids.scheduleId));
    });

    test('캘린더에서 지운 행사를 같은 제목·날짜로 다시 등록할 수 있다', () async {
      final ids = await registerAndConfirm();
      await calendarRepo.deleteEvent(ids.eventId);

      final now = DateTime.now().toIso8601String();
      final retry = await scheduleRepo.insertConfirmedOrPending(
        Schedule(
          title: '가을 운동회',
          scheduledDate: '2026-10-15',
          status: ScheduleStatus.pending,
          kind: EntryKind.event,
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(retry, greaterThan(0), reason: '-1이면 중복으로 막힌 것');
    });

    test('원본이 없는 손입력 이벤트를 지워도 다른 일정은 건드리지 않는다', () async {
      final now = DateTime.now().toIso8601String();
      final keepId = await scheduleRepo.insertConfirmedOrPending(
        Schedule(
          title: '남아 있어야 하는 일정',
          scheduledDate: '2026-10-20',
          status: ScheduleStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final eventId = await calendarRepo.createEvent(
        const CalendarEvent(title: '손으로 만든 이벤트', eventDate: '2026-10-15'),
      );

      await calendarRepo.deleteEvent(eventId);

      final active = await scheduleRepo.getSchedules();
      expect(active.map((s) => s.id), contains(keepId));
    });
  });

  group('restoreEvent 연쇄', () {
    test('이벤트를 복구하면 원본 일정도 함께 되살아난다', () async {
      final ids = await registerAndConfirm();
      await calendarRepo.deleteEvent(ids.eventId);
      // 전제를 먼저 고정한다 — 삭제 연쇄가 없으면 이 아래 검사가 우연히 통과한다.
      expect(await scheduleRepo.getSchedules(), isEmpty);

      await calendarRepo.restoreEvent(ids.eventId);

      final active = await scheduleRepo.getSchedules();
      expect(active.map((s) => s.id), contains(ids.scheduleId));
    });
  });

  group('permanentDeleteEvent 연쇄', () {
    test('이벤트를 영구 삭제하면 원본 일정도 함께 사라진다', () async {
      final ids = await registerAndConfirm();
      await calendarRepo.deleteEvent(ids.eventId);
      // 전제: 원본이 실제로 휴지통에 내려가 있어야 이 검사에 의미가 생긴다.
      expect(
        (await scheduleRepo.getDeletedSchedules()).map((s) => s.id),
        contains(ids.scheduleId),
      );

      await calendarRepo.permanentDeleteEvent(ids.eventId);

      final trashed = await scheduleRepo.getDeletedSchedules();
      expect(
        trashed.map((s) => s.id),
        isNot(contains(ids.scheduleId)),
        reason: '짝이 사라지면 원본만 휴지통에 고아로 남는다',
      );
    });
  });
}
