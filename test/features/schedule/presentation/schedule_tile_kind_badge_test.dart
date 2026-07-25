import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';
import 'package:planroutine/features/schedule/presentation/widgets/schedule_tile.dart';

/// 검토 행의 종류 배지 — 무엇을 확정하는지 보여야 한다.
///
/// 업무(내가 처리할 일)와 학교일정(학교에서 일어나는 일)이 한 목록에 섞여 있어
/// 배지가 없으면 일괄 확정 전에 성격을 구분할 수 없다.
void main() {
  Widget host(Schedule schedule) {
    return MaterialApp(
      home: Scaffold(
        body: ScheduleTile(
          schedule: schedule,
          onConfirm: () {},
          onDelete: () {},
          onTap: () {},
        ),
      ),
    );
  }

  testWidgets('업무 행에는 업무 배지가 붙는다', (tester) async {
    await tester.pumpWidget(
      host(const Schedule(id: 1, title: '학급편성 결과 제출', scheduledDate: '2026-03-02')),
    );

    expect(find.text(EntryKind.task.label), findsOneWidget);
    expect(find.text(EntryKind.event.label), findsNothing);
  });

  testWidgets('학교일정 행에는 일정 배지가 붙는다', (tester) async {
    await tester.pumpWidget(
      host(const Schedule(
        id: 2,
        title: '과학의 달 행사',
        scheduledDate: '2026-04-10',
        kind: EntryKind.event,
      )),
    );

    expect(find.text(EntryKind.event.label), findsOneWidget);
    expect(find.text(EntryKind.task.label), findsNothing);
  });

  testWidgets('확정 배지와 종류 배지가 함께 보인다', (tester) async {
    await tester.pumpWidget(
      host(const Schedule(
        id: 3,
        title: '과학의 달 행사',
        scheduledDate: '2026-04-10',
        kind: EntryKind.event,
        status: ScheduleStatus.confirmed,
      )),
    );

    expect(find.text(EntryKind.event.label), findsOneWidget);
    expect(find.text('확정'), findsOneWidget);
  });
}
