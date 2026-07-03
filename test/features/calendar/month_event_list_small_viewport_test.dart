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

  // 실제 이벤트 분포와 비슷하게 몇 개만 (16,17,22,23,25,27) — 스크린샷 재현.
  List<MapEntry<String, List<CalendarEvent>>> buildEntries() {
    const days = [16, 17, 22, 23, 25, 27];
    return [
      for (var i = 0; i < days.length; i++)
        MapEntry('2026-07-${days[i]}', [
          CalendarEvent(id: i, title: '이벤트 ${days[i]}일', eventDate: '2026-07-${days[i]}'),
        ]),
    ];
  }

  // 실제 화면: 위쪽에 캘린더(≈500px)가 자리하고, 목록은 아래 좁은 영역(≈3개)만 보임.
  Widget harness(DateTime selectedDate, {double listHeight = 280}) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Container(height: 500, color: const Color(0xFF101010)), // 캘린더 자리
              SizedBox(
                height: listHeight,
                child: MonthEventList(
                  groupedEntries: buildEntries(),
                  selectedDate: selectedDate,
                  onEventTap: (_) {},
                  onEventSaveToGoogle: null,
                  onEventToggleCompleted: (_) {},
                  onEventBumpYear: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('좁은 뷰포트에서 마지막 근처 날짜(27일)를 선택하면 보인다', (tester) async {
    // 폰 크기로 설정
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness(DateTime(2026, 7, 16)));
    await tester.pumpAndSettle();

    // 27일 선택
    await tester.pumpWidget(harness(DateTime(2026, 7, 27)));
    await tester.pumpAndSettle();

    final finder = find.text('이벤트 27일');
    expect(finder, findsOneWidget);
    // 목록 영역은 화면 y=500~780. 27일이 그 안에 들어와야 한다.
    final rect = tester.getRect(finder);
    expect(rect.top, greaterThanOrEqualTo(500),
        reason: '목록 뷰포트 위(캘린더 영역)로 넘어가면 안 됨');
    expect(rect.top, lessThan(780), reason: '목록 뷰포트 안에 보여야 함 (현재: ${rect.top})');
  });
}
