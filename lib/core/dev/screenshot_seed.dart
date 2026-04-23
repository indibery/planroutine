// ignore_for_file: avoid_print
//
// 스크린샷 촬영용 seed 데이터 삽입.
//
// `--dart-define=SCREENSHOT_MODE=true` 로 실행한 빌드에서만 호출된다.
// main.dart의 `if (kScreenshotMode) await seedScreenshotData(container);`
// 조건부 진입점을 통해 앱 시작 시 1회 데이터를 주입한다. 일반 실행·릴리즈
// 빌드(해당 flag 없음)에서는 tree-shake로 제거된다.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/calendar/domain/calendar_event.dart';
import '../../features/calendar/presentation/providers/calendar_providers.dart';
import '../../features/schedule/domain/schedule.dart';
import '../../features/schedule/presentation/providers/schedule_providers.dart';

Future<void> seedScreenshotData(ProviderContainer container) async {
  final scheduleRepo = container.read(scheduleRepositoryProvider);
  final calendarRepo = container.read(calendarRepositoryProvider);

  final existing = await scheduleRepo.getSchedules();
  if (existing.isNotEmpty) return;

  final now = DateTime.now();

  // ── 일정 검토 탭용 — 2026년 분 20개 (확정 3 / 대기 17) ──
  final schedules = <Schedule>[
    _s('2025학년도 연현초등학교 1차 학급편성 결과 제출', '2026-01-03', '학생학적',
        ScheduleStatus.confirmed),
    _s('2025학년도 연현초등학교 교육과정 운영 계획', '2026-01-15', '교육과정계획',
        ScheduleStatus.confirmed),
    _s('교직원 회의 계획', '2026-02-05', '조직통계', ScheduleStatus.confirmed),
    _s('학부모 총회 안내장', '2026-02-18', '일과운영관리'),
    _s('연간 교육계획 협의회', '2026-02-25', '교육과정계획'),
    _s('임시공휴일(6.3)에 따른 2025학년도 초등특수 통합교육 계획', '2026-03-02', '일과운영관리'),
    _s('교과서 신청 및 수령', '2026-03-10', '일과운영관리'),
    _s('학년 학급 편성 결과 보고', '2026-03-15', '학생학적'),
    _s('2025학년도 위임전결 규정 개정', '2026-03-20', '조직통계'),
    _s('봄 현장 체험학습 계획', '2026-04-05', '교육과정계획'),
    _s('교내 환경 정비 안내', '2026-04-10', '일과운영관리'),
    _s('분기별 예산 집행 보고', '2026-04-18', '조직통계'),
    _s('학부모 상담 주간 안내', '2026-05-03', '일과운영관리'),
    _s('스승의날 행사 운영', '2026-05-12', '일과운영관리'),
    _s('운동회 안전 계획', '2026-05-20', '교육과정계획'),
    _s('여름방학 전 학생 안전교육', '2026-07-10', '일과운영관리'),
    _s('1학기 학업성취도 보고', '2026-07-15', '학생학적'),
    _s('방학 중 교직원 연수', '2026-07-25', '조직통계'),
    _s('2학기 개학 준비', '2026-08-20', '교육과정계획'),
    _s('9월 생활지도 계획', '2026-09-02', '일과운영관리'),
  ];
  for (final s in schedules) {
    await scheduleRepo.insertConfirmedOrPending(s);
  }

  // ── 캘린더 탭용 — 현재 월 중심의 이벤트 5건 ──
  final events = <CalendarEvent>[
    _e('교직원 회의', now, color: '#E0B96A'),
    _e('학급편성 결과 제출', now.add(const Duration(days: 2)), color: '#7FD4A5'),
    _e('학부모 총회 안내장 발송', now.add(const Duration(days: 5)), color: '#8BA8D4'),
    _e('교과서 주문 마감', now.add(const Duration(days: 9)),
        color: '#E08978',
        description: '교과서 수량 확정 및 주문 제출'),
    _e('분기 예산 협의', now.add(const Duration(days: 14)), color: '#B89AE0'),
  ];
  for (final e in events) {
    await calendarRepo.createEvent(e);
  }

  // 캘린더 프로바이더 새로고침
  container.invalidate(selectedMonthEventsProvider);

  print('[screenshot_seed] seeded ${schedules.length} schedules + '
      '${events.length} events');
  return;
}

Schedule _s(String title, String date, String category,
        [ScheduleStatus status = ScheduleStatus.pending]) =>
    Schedule(
      title: title,
      scheduledDate: date,
      category: category,
      status: status,
    );

CalendarEvent _e(String title, DateTime date,
        {String? color, String? description}) =>
    CalendarEvent(
      title: title,
      eventDate: '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      isAllDay: true,
      color: color,
      description: description,
    );
