import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';

void main() {
  group('ScheduleStatus', () {
    test('2개 상태값 존재', () {
      expect(ScheduleStatus.values.length, 2);
      expect(ScheduleStatus.values, contains(ScheduleStatus.pending));
      expect(ScheduleStatus.values, contains(ScheduleStatus.confirmed));
    });

    test('value 게터가 name과 동일', () {
      expect(ScheduleStatus.pending.value, 'pending');
      expect(ScheduleStatus.confirmed.value, 'confirmed');
    });

    test('fromValue로 문자열에서 상태 변환', () {
      expect(ScheduleStatus.fromValue('pending'), ScheduleStatus.pending);
      expect(ScheduleStatus.fromValue('confirmed'), ScheduleStatus.confirmed);
    });

    test('fromValue에 잘못된 값이면 pending 기본값 (기존 completed 포함)', () {
      expect(ScheduleStatus.fromValue('unknown'), ScheduleStatus.pending);
      expect(ScheduleStatus.fromValue(''), ScheduleStatus.pending);
      // 레거시 'completed' 값은 pending으로 폴백
      expect(ScheduleStatus.fromValue('completed'), ScheduleStatus.pending);
    });
  });

  group('Schedule', () {
    group('fromMap / toMap 라운드트립', () {
      test('모든 필드가 있는 경우 정상 변환', () {
        final map = {
          'id': 1,
          'title': '교육과정 운영 계획',
          'description': '2026학년도 교육과정 운영 계획서 작성',
          'scheduled_date': '2026-03-15',
          'category': '교육과정계획',
          'sub_category': '교육과정 운영',
          'source_id': 10,
          'status': 'confirmed',
          'created_at': '2026-03-01T09:00:00.000',
          'updated_at': '2026-03-10T14:00:00.000',
        };

        final schedule = Schedule.fromMap(map);
        final result = schedule.toMap();

        expect(result['id'], 1);
        expect(result['title'], '교육과정 운영 계획');
        expect(result['description'], '2026학년도 교육과정 운영 계획서 작성');
        expect(result['scheduled_date'], '2026-03-15');
        expect(result['category'], '교육과정계획');
        expect(result['sub_category'], '교육과정 운영');
        expect(result['source_id'], 10);
        expect(result['status'], 'confirmed');
        expect(result['created_at'], '2026-03-01T09:00:00.000');
        expect(result['updated_at'], '2026-03-10T14:00:00.000');
      });

      test('선택 필드가 null인 경우', () {
        final map = {
          'id': null,
          'title': '간단한 일정',
          'description': null,
          'scheduled_date': '2026-04-01',
          'category': null,
          'sub_category': null,
          'source_id': null,
          'status': 'pending',
          'created_at': '2026-04-01T10:00:00.000',
          'updated_at': '2026-04-01T10:00:00.000',
        };

        final schedule = Schedule.fromMap(map);

        expect(schedule.id, isNull);
        expect(schedule.title, '간단한 일정');
        expect(schedule.description, isNull);
        expect(schedule.category, isNull);
        expect(schedule.subCategory, isNull);
        expect(schedule.sourceId, isNull);
        expect(schedule.status, ScheduleStatus.pending);
      });

      test('status가 null이면 pending 기본값', () {
        final map = {
          'title': '상태 미지정 일정',
          'scheduled_date': '2026-04-01',
          'status': null,
          'created_at': '2026-04-01T10:00:00.000',
          'updated_at': '2026-04-01T10:00:00.000',
        };

        final schedule = Schedule.fromMap(map);
        expect(schedule.status, ScheduleStatus.pending);
      });
    });

    group('toMap id 처리', () {
      test('id가 null이면 map에 id 미포함', () {
        final schedule = Schedule(
          title: '새 일정',
          scheduledDate: '2026-04-01',
          createdAt: '2026-04-01T10:00:00.000',
          updatedAt: '2026-04-01T10:00:00.000',
        );

        final map = schedule.toMap();
        expect(map.containsKey('id'), false);
      });

      test('id가 있으면 map에 id 포함', () {
        final schedule = Schedule(
          id: 7,
          title: '기존 일정',
          scheduledDate: '2026-04-01',
          createdAt: '2026-04-01T10:00:00.000',
          updatedAt: '2026-04-01T10:00:00.000',
        );

        final map = schedule.toMap();
        expect(map['id'], 7);
      });
    });

    group('toMap 기본 시각 처리', () {
      test('createdAt/updatedAt이 null이면 현재 시각 자동 설정', () {
        final schedule = Schedule(
          title: '시각 테스트',
          scheduledDate: '2026-04-01',
        );

        final map = schedule.toMap();
        expect(map['created_at'], isNotNull);
        expect(map['updated_at'], isNotNull);
        expect(map['created_at'], isA<String>());
        expect(map['updated_at'], isA<String>());
      });

      test('createdAt/updatedAt이 있으면 해당 값 유지', () {
        final schedule = Schedule(
          title: '시각 테스트',
          scheduledDate: '2026-04-01',
          createdAt: '2026-01-01T00:00:00.000',
          updatedAt: '2026-02-01T00:00:00.000',
        );

        final map = schedule.toMap();
        expect(map['created_at'], '2026-01-01T00:00:00.000');
        expect(map['updated_at'], '2026-02-01T00:00:00.000');
      });
    });

    group('기본 상태값', () {
      test('상태 미지정 시 pending 기본값', () {
        final schedule = Schedule(
          title: '기본 상태 테스트',
          scheduledDate: '2026-04-01',
        );

        expect(schedule.status, ScheduleStatus.pending);
      });

      test('상태를 confirmed로 지정', () {
        final schedule = Schedule(
          title: '확정 일정',
          scheduledDate: '2026-04-01',
          status: ScheduleStatus.confirmed,
        );

        expect(schedule.status, ScheduleStatus.confirmed);
        expect(schedule.toMap()['status'], 'confirmed');
      });

    });
  });
}
