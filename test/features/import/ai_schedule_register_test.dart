import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/import/data/ai_schedule_parser.dart';
import 'package:planroutine/features/import/data/ai_schedule_register.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';

import '../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);

  late DatabaseHelper db;
  late ScheduleRepository repo;

  setUp(() {
    db = freshDatabaseHelper();
    repo = ScheduleRepository(dbHelper: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('registerAiSchedules', () {
    test('파싱된 행사를 검토 대기(pending) 일정으로 등록', () async {
      final result = await registerAiSchedules(repo, const [
        AiScheduleItem(title: '입학식', date: '2026-03-02'),
        AiScheduleItem(title: '봄 현장체험학습', date: '2026-04-24', description: '4-6학년'),
      ]);
      expect(result.created, 2);
      expect(result.skipped, 0);

      final schedules = await repo.getSchedules();
      expect(schedules.length, 2);
      expect(schedules.every((s) => s.status == ScheduleStatus.pending), true);
      final trip = schedules.firstWhere((s) => s.title == '봄 현장체험학습');
      expect(trip.description, '4-6학년');
    });

    test('동일 title+date 기존 일정이 있으면 스킵 (재붙여넣기 안전)', () async {
      await registerAiSchedules(repo, const [
        AiScheduleItem(title: '입학식', date: '2026-03-02'),
      ]);
      final second = await registerAiSchedules(repo, const [
        AiScheduleItem(title: '입학식', date: '2026-03-02'),
        AiScheduleItem(title: '여름방학식', date: '2026-07-17'),
      ]);
      expect(second.created, 1);
      expect(second.skipped, 1);

      final schedules = await repo.getSchedules();
      expect(schedules.length, 2);
    });
  });
}
