import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/utils/date_utils.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/today/domain/stamp_settings.dart';
import 'package:planroutine/features/today/domain/today_view.dart';
import 'package:planroutine/features/today/presentation/widgets/completion_seal.dart';
import 'package:planroutine/features/today/presentation/widgets/today_body.dart';

final _today = DateTime(2026, 7, 25);

CalendarEvent _event({
  required int id,
  DateTime? date,
  String title = '현장체험학습 안전교육 실시',
  bool completed = false,
  bool important = false,
}) {
  return CalendarEvent(
    id: id,
    title: title,
    eventDate: formatDate(date ?? _today),
    completedAt: completed ? '2026-07-25T09:00:00.000' : null,
    isImportant: important,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  Future<CalendarEvent?> pumpBody(WidgetTester tester, TodayView view) async {
    CalendarEvent? toggled;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodayBody(
            view: view,
            today: _today,
            onToggle: (e) => toggled = e,
            onEventTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return toggled;
  }

  TodayView viewOf(List<CalendarEvent> events) =>
      buildTodayView(events: events, today: _today);

  group('오늘 탭 — 목록 렌더', () {
    testWidgets('오늘 항목의 제목이 보인다', (tester) async {
      await pumpBody(tester, viewOf([_event(id: 1, title: '급식 만족도 조사 정리')]));

      expect(find.text('급식 만족도 조사 정리'), findsOneWidget);
    });

    testWidgets('완료된 항목의 제목에는 취소선이 그어진다', (tester) async {
      await pumpBody(
        tester,
        viewOf([_event(id: 1, title: '출결 마감 확인', completed: true)]),
      );

      final title = tester.widget<Text>(find.text('출결 마감 확인'));
      expect(title.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('미완료 항목의 제목에는 취소선이 없다', (tester) async {
      await pumpBody(tester, viewOf([_event(id: 1, title: '출결 마감 확인')]));

      final title = tester.widget<Text>(find.text('출결 마감 확인'));
      expect(title.style?.decoration, TextDecoration.none);
    });
  });

  group('오늘 탭 — 완료 체크', () {
    testWidgets('체크 원을 탭하면 해당 이벤트로 onToggle이 호출된다', (tester) async {
      CalendarEvent? toggled;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TodayBody(
              view: viewOf([_event(id: 7)]),
              today: _today,
              onToggle: (e) => toggled = e,
              onEventTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('today_check_7')));
      await tester.pumpAndSettle();

      expect(toggled?.id, 7);
    });

    testWidgets('체크 원의 탭 영역은 44x44 이상이다', (tester) async {
      await pumpBody(tester, viewOf([_event(id: 1)]));

      final size = tester.getSize(find.byKey(const Key('today_check_1')));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('완료된 항목에는 완료 도장이 보인다', (tester) async {
      await pumpBody(tester, viewOf([_event(id: 3, completed: true)]));

      expect(find.byKey(const Key('today_seal_3')), findsOneWidget);
      expect(find.text(TodayStrings.sealComplete), findsOneWidget);
    });

    testWidgets('완료 도장은 화면 오른쪽에 최소 12의 여백을 남긴다', (tester) async {
      await pumpBody(tester, viewOf([_event(id: 3, completed: true)]));

      final seal = tester.getRect(find.byKey(const Key('today_seal_3')));
      final bodyWidth = tester.getSize(find.byType(TodayBody)).width;

      expect(bodyWidth - seal.right, greaterThanOrEqualTo(12));
    });

    testWidgets('미완료 항목에는 완료 도장이 없다', (tester) async {
      await pumpBody(tester, viewOf([_event(id: 3)]));

      expect(find.byKey(const Key('today_seal_3')), findsNothing);
    });
  });

  group('오늘 탭 — 도장 설정', () {
    double sealOpacity(WidgetTester tester) {
      return tester
          .widget<Opacity>(
            find.descendant(
              of: find.byType(CompletionSeal),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;
    }

    testWidgets('설정한 도장 모양이 행에 그려진다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TodayBody(
              view: viewOf([_event(id: 1, completed: true)]),
              today: _today,
              stampSettings: const StampSettings(style: SealStyle.approve),
              onToggle: (_) {},
              onEventTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(TodayStrings.sealApprove), findsOneWidget);
    });

    testWidgets('흐리게 옵션이 켜지면 진입 시 이미 완료된 도장은 옅게 찍힌다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TodayBody(
              view: viewOf([_event(id: 1, completed: true)]),
              today: _today,
              stampSettings: const StampSettings(dimPreviousStamps: true),
              onToggle: (_) {},
              onEventTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(sealOpacity(tester), lessThan(0.5));
    });

    testWidgets('흐리게 옵션이 꺼지면 진입 시 완료된 도장도 진하게 찍힌다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TodayBody(
              view: viewOf([_event(id: 1, completed: true)]),
              today: _today,
              stampSettings: const StampSettings(dimPreviousStamps: false),
              onToggle: (_) {},
              onEventTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(sealOpacity(tester), greaterThan(0.5));
    });

    testWidgets('흐리게 옵션이 켜져 있어도 화면에서 방금 찍은 도장은 진하다', (tester) async {
      var view = viewOf([_event(id: 1)]);

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: TodayBody(
                  view: view,
                  today: _today,
                  stampSettings: const StampSettings(dimPreviousStamps: true),
                  onToggle: (_) => setState(() {
                    view = view.withToggled(1, '2026-07-25T10:00:00.000');
                  }),
                  onEventTap: (_) {},
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('today_check_1')));
      await tester.pumpAndSettle();

      expect(sealOpacity(tester), greaterThan(0.5));
    });
  });

  group('오늘 탭 — 진행도 문안', () {
    testWidgets('남은 건수가 문안으로 표시된다', (tester) async {
      await pumpBody(
        tester,
        viewOf([_event(id: 1, completed: true), _event(id: 2), _event(id: 3)]),
      );

      expect(find.text(TodayStrings.remaining(2)), findsOneWidget);
    });

    testWidgets('오늘 항목을 모두 완료하면 완주 문안으로 바뀐다', (tester) async {
      await pumpBody(
        tester,
        viewOf([
          _event(id: 1, completed: true),
          _event(id: 2, completed: true),
        ]),
      );

      expect(find.text(TodayStrings.allDone), findsOneWidget);
    });

    testWidgets('오늘 일정이 없으면 빈 상태 문안이 보이고 링은 없다', (tester) async {
      await pumpBody(
        tester,
        viewOf([_event(id: 1, date: _today.subtract(const Duration(days: 2)))]),
      );

      expect(find.text(TodayStrings.emptyToday), findsOneWidget);
      expect(find.byKey(const Key('today_progress_ring')), findsNothing);
    });

    testWidgets('오늘 일정이 있으면 진행도 링이 보인다', (tester) async {
      await pumpBody(tester, viewOf([_event(id: 1)]));

      expect(find.byKey(const Key('today_progress_ring')), findsOneWidget);
    });
  });

  group('오늘 탭 — 기한이 지난 섹션', () {
    TodayView overdueView() => viewOf([
      _event(
        id: 1,
        date: _today.subtract(const Duration(days: 3)),
        title: '교육과정 운영위원회 회의록 작성',
      ),
      _event(id: 2, title: '오늘 업무'),
    ]);

    testWidgets('기본으로 접혀 있어 지난 항목 제목이 보이지 않는다', (tester) async {
      await pumpBody(tester, overdueView());

      expect(find.text(TodayStrings.overdueSection), findsOneWidget);
      expect(find.text('교육과정 운영위원회 회의록 작성'), findsNothing);
    });

    testWidgets('접힌 상태에서 지난 항목 개수가 보인다', (tester) async {
      await pumpBody(tester, overdueView());

      expect(find.text(TodayStrings.overdueCount(1)), findsOneWidget);
    });

    testWidgets('헤더를 탭하면 지난 항목이 펼쳐진다', (tester) async {
      await pumpBody(tester, overdueView());

      await tester.tap(find.byKey(const Key('today_overdue_header')));
      await tester.pumpAndSettle();

      expect(find.text('교육과정 운영위원회 회의록 작성'), findsOneWidget);
    });

    testWidgets('지난 항목이 없으면 섹션 자체가 없다', (tester) async {
      await pumpBody(tester, viewOf([_event(id: 1)]));

      expect(find.text(TodayStrings.overdueSection), findsNothing);
    });
  });
}
