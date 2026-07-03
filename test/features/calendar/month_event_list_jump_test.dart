import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/widgets/month_event_list.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  // 화면 밖까지 밀리도록 여러 날짜 섹션 생성 (2일 간격 15개 → 마지막은 한참 아래).
  List<MapEntry<String, List<CalendarEvent>>> buildEntries() {
    final entries = <MapEntry<String, List<CalendarEvent>>>[];
    for (var i = 0; i < 15; i++) {
      final day = 1 + i * 2; // 1,3,5,...,29
      final key = '2026-07-${day.toString().padLeft(2, '0')}';
      entries.add(MapEntry(key, [
        CalendarEvent(id: i, title: '이벤트 $day일', eventDate: key),
      ]));
    }
    return entries;
  }

  Widget harness(DateTime selectedDate) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: MonthEventList(
            groupedEntries: buildEntries(),
            selectedDate: selectedDate,
            onEventTap: (_) {},
            onEventSaveToGoogle: null,
            onEventToggleCompleted: (_) {},
            onEventBumpYear: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('늦은 날짜를 선택하면 그 섹션이 화면 안으로 스크롤된다', (tester) async {
    // 초기: 첫 날짜 선택 → 목록 상단
    await tester.pumpWidget(harness(DateTime(2026, 7, 1)));
    await tester.pumpAndSettle();

    // 마지막 날짜(29일)는 초기엔 화면 밖 → 상단에 있지 않다.
    // 선택 날짜를 29일로 바꿔 리빌드 → 점프.
    await tester.pumpWidget(harness(DateTime(2026, 7, 29)));
    await tester.pumpAndSettle();

    // 29일 이벤트가 뷰포트(높이 600) 안으로 들어와야 한다.
    final finder = find.text('이벤트 29일');
    expect(finder, findsOneWidget);
    final top = tester.getTopLeft(finder).dy;
    expect(top, greaterThanOrEqualTo(0));
    expect(top, lessThan(600));
  });

  testWidgets('이벤트 없는 날짜를 선택하면 다음 가까운 섹션으로 스크롤', (tester) async {
    await tester.pumpWidget(harness(DateTime(2026, 7, 1)));
    await tester.pumpAndSettle();

    // 28일엔 이벤트 없음 → 다음 가까운 29일 섹션으로.
    await tester.pumpWidget(harness(DateTime(2026, 7, 28)));
    await tester.pumpAndSettle();

    final finder = find.text('이벤트 29일');
    expect(finder, findsOneWidget);
    expect(tester.getTopLeft(finder).dy, lessThan(600));
  });
}
