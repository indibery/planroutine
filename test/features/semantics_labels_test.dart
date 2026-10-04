import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_logic.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/domain/participant.dart';
import 'package:planroutine/features/guidance/presentation/widgets/guidance_record_tile.dart';
import 'package:planroutine/features/today/presentation/widgets/today_event_row.dart';

/// 화면 내용을 이어 붙여 만드는 버튼 이름 — 시뮬레이터 자동화와 스크린리더가 읽는다.
///
/// 이름이 화면과 어긋나면 자동화가 엉뚱한 행을 누른다. 그래서 **화면에 보이는 순서**를
/// 지키는지 본다(2026-10-04, `ButtonSemantics`로 21곳을 정리하면서 추가).
void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));

  group('todayRowSemanticsLabel', () {
    test('제목만', () {
      expect(
        todayRowSemanticsLabel(
          const CalendarEvent(id: 1, title: '학부모 상담', eventDate: '2026-10-04'),
          null,
        ),
        '학부모 상담',
      );
    });

    test('중요 · 제목 · 부제 · 완료됨', () {
      expect(
        todayRowSemanticsLabel(
          const CalendarEvent(
            id: 1,
            title: '교육계획 제출',
            eventDate: '2026-10-01',
            isImportant: true,
          ),
          '10월 1일',
        ),
        '${CalendarStrings.importantBadge}, 교육계획 제출, 10월 1일',
      );
      expect(
        todayRowSemanticsLabel(
          const CalendarEvent(
            id: 2,
            title: '교육계획 제출',
            eventDate: '2026-10-01',
            isImportant: true,
            completedAt: '2026-10-04T09:00:00',
          ),
          null,
        ),
        '교육계획 제출, ${CalendarStrings.eventDone}',
      );
    });
  });

  group('guidanceRecordSemanticsLabel', () {
    final now = DateTime(2026, 10, 4, 12);
    GuidanceRecord record(GuidanceContent content) => GuidanceRecord(
      id: 1,
      createdAt: '2026-10-04T09:00:00.000',
      latest: GuidanceRevision(
        recordId: 1,
        revisionNo: 1,
        savedAt: '2026-10-04T09:00:00.000',
        content: content,
      ),
    );

    test('사건 시각 · 구분 · 제목', () {
      final c = GuidanceContent(
        title: '복도 다툼',
        kind: GuidanceKind.guidance,
        precision: OccurredPrecision.exact,
        occurredAt: DateTime(2026, 10, 4, 10, 30),
      );
      expect(
        guidanceRecordSemanticsLabel(record(c), now: now),
        '${formatOccurred(c, now: now)}, ${GuidanceKind.guidance.label}, 복도 다툼',
      );
    });

    test('진행 중이 아니면 상태를, 관련인이 있으면 이름을 붙인다', () {
      final c = GuidanceContent(
        title: '수업 방해',
        kind: GuidanceKind.infringement,
        status: GuidanceStatus.transferred,
        precision: OccurredPrecision.exact,
        occurredAt: DateTime(2026, 10, 4, 10, 30),
        participants: const [
          Participant(name: '김민준'),
          Participant(name: '이서윤'),
        ],
      );
      expect(
        guidanceRecordSemanticsLabel(record(c), now: now),
        '${formatOccurred(c, now: now)}, ${GuidanceKind.infringement.label}, '
        '${GuidanceStatus.transferred.label}, 수업 방해, 김민준 · 이서윤',
      );
    });
  });

  testWidgets('오늘 행의 체크 원은 켜짐 상태를 가진 버튼, 제목은 따로 된 버튼이다', (tester) async {
    final handle = tester.ensureSemantics();
    var toggled = 0;
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodayEventRow(
            event: const CalendarEvent(
              id: 1,
              title: '학부모 상담',
              eventDate: '2026-10-04',
              completedAt: '2026-10-04T09:00:00',
            ),
            onToggle: () => toggled++,
            onTap: () => opened++,
          ),
        ),
      ),
    );

    final check = tester.getSemantics(
      find.bySemanticsLabel('학부모 상담, ${CalendarStrings.markComplete}'),
    );
    expect(
      check,
      isSemantics(isButton: true, isChecked: true, hasCheckedState: true),
    );

    final titleLabel = '학부모 상담, ${CalendarStrings.eventDone}';
    expect(
      tester.getSemantics(find.bySemanticsLabel(titleLabel)),
      isSemantics(isButton: true, hasTapAction: true),
    );
    tester.semantics.tap(find.semantics.byLabel(titleLabel));
    expect(opened, 1);
    expect(toggled, 0);
    handle.dispose();
  });
}
