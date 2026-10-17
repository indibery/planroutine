import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/schoolbook/presentation/providers/schoolbook_providers.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/period_row_tile.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/room_chips.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/schoolbook_connect_view.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/week_strip.dart';
import 'package:planroutine/shared/widgets/pill_chip.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_server.dart';
import 'schoolbook_screen_harness.dart';

bool _chipSelected(WidgetTester tester, int roomId) =>
    tester.widget<PillChip>(find.byKey(RoomChips.chipKey(roomId))).selected;

DateTime _shownDay(WidgetTester tester) => tester.widget<WeekStrip>(find.byType(WeekStrip)).day;

Finder _mine(String booker) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == SchoolbookStrings.mine(booker),
    );

Finder _inRow(String period, String text) =>
    find.descendant(of: find.byKey(PeriodRowTile.rowKey(period)), matching: find.text(text));

void main() {
  group('교실 고르기', () {
    testWidgets('기억한 교실이 열린다', (tester) async {
      await pumpSchoolbook(tester, lastRoomId: 1511);
      expect(_chipSelected(tester, 1511), isTrue);
    });

    testWidgets('기억한 교실이 없으면 첫 교실', (tester) async {
      await pumpSchoolbook(tester, lastRoomId: 999);
      expect(_chipSelected(tester, 1513), isTrue);
    });

    testWidgets('교실 칩에서 과학실을 고르면 과학실 하루가 뜨고 기억한다', (tester) async {
      await pumpSchoolbook(tester, lastRoomId: 1511);
      // 최근 순서로 체육관이 앞에 오고 과학실은 긴 이름 칩 뒤 — 밀어서 누른다
      await tester.ensureVisible(find.byKey(RoomChips.chipKey(1512)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(RoomChips.chipKey(1512)));
      await settle(tester);
      expect(_chipSelected(tester, 1512), isTrue);
      expect(_inRow('3교시', '6-2'), findsOneWidget);
      final raw = (await SharedPreferences.getInstance()).getString(schoolbookSettingsPrefsKey);
      expect((jsonDecode(raw ?? '{}') as Map)['lastRoomId'], 1512);
    });
  });

  group('주간 날짜 띠', () {
    testWidgets('토요일에 열면 다음 월요일', (tester) async {
      await pumpSchoolbook(tester, lastRoomId: 1511, now: DateTime(2026, 10, 24, 9));
      expect(_shownDay(tester), DateTime(2026, 10, 26));
    });

    testWidgets('마지막 예약 가능 주에서는 ▶를 누를 수 없다', (tester) async {
      // 10월 20일에 열면 마지막 예약 가능일은 2027-02-28(일) — 마지막 주는 2/22~26
      await pumpSchoolbook(tester, lastRoomId: 1511);
      for (var i = 0; i < 40; i++) {
        if (tester.widget<WeekStrip>(find.byType(WeekStrip)).onNextWeek == null) break;
        await tester.tap(find.byKey(WeekStrip.nextWeekKey));
        await tester.pump();
      }
      expect(_shownDay(tester), DateTime(2027, 2, 23));
      expect(tester.widget<WeekStrip>(find.byType(WeekStrip)).onNextWeek, isNull);
    });

    testWidgets('띠에서 요일을 누르면 그날로', (tester) async {
      final server = await pumpSchoolbook(tester, lastRoomId: 1511);
      await tester.tap(find.byKey(WeekStrip.dayKey(DateTime(2026, 10, 22))));
      await settle(tester);
      expect(_shownDay(tester), DateTime(2026, 10, 22));
      expect(
        server.requests.any((r) => r.url.query == 'date=2026-10-22'),
        isTrue,
      );
    });

    testWidgets('지난 날짜는 예약할 수 없다', (tester) async {
      await pumpSchoolbook(tester, lastRoomId: 1512);
      await tester.tap(find.byKey(WeekStrip.dayKey(DateTime(2026, 10, 19))));
      await settle(tester);
      expect(_shownDay(tester), DateTime(2026, 10, 19));
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('체육관 하루', () {
    testWidgets('고정으로 찬 1교시는 버튼이 없고 고정 표시', (tester) async {
      await pumpSchoolbook(tester, lastRoomId: 1511);
      expect(find.byKey(PeriodRowTile.bookKey('1교시')), findsNothing);
      expect(find.byKey(PeriodRowTile.cancelKey('1교시')), findsNothing);
      expect(_inRow('1교시', SchoolbookStrings.fixedPerson('3-2')), findsOneWidget);
    });

    testWidgets('빈 교시마다 예약 버튼이 있다', (tester) async {
      await pumpSchoolbook(tester, lastRoomId: 1511);
      expect(find.byKey(PeriodRowTile.bookKey('2교시')), findsOneWidget);
      expect(find.byKey(PeriodRowTile.bookKey('4교시')), findsOneWidget);
    });

    testWidgets('빈 교시는 비어 있음', (tester) async {
      await pumpSchoolbook(tester, lastRoomId: 1511);
      expect(_inRow('2교시', SchoolbookStrings.free), findsOneWidget);
    });
  });

  group('내 예약 — 저장한 예약자 이름과 같은 예약', () {
    testWidgets('내 예약은 강조되고 그 줄 버튼이 취소다', (tester) async {
      await pumpSchoolbook(tester, lastRoomId: 1511, booker: '5-1');
      expect(_mine('5-1'), findsOneWidget);
      expect(find.byKey(PeriodRowTile.cancelKey('3교시')), findsOneWidget);
      expect(find.byKey(PeriodRowTile.bookKey('3교시')), findsNothing);
    });

    testWidgets('다른 반 예약에는 버튼이 없다', (tester) async {
      await pumpSchoolbook(tester, lastRoomId: 1511, booker: '5-1');
      // 5교시는 6-3 — 정원 1이 다 찼다
      expect(find.byKey(PeriodRowTile.cancelKey('5교시')), findsNothing);
      expect(find.byKey(PeriodRowTile.bookKey('5교시')), findsNothing);
    });
  });

  group('과학실 하루 — 정원 2', () {
    testWidgets('한 교시의 두 반이 모두 보이고 다 차면 남은 자리를 적지 않는다', (tester) async {
      await pumpSchoolbook(tester, lastRoomId: 1512);
      expect(_inRow('3교시', '5-1'), findsOneWidget);
      expect(_inRow('3교시', '6-2'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(PeriodRowTile.rowKey('3교시')),
          matching: find.textContaining('자리 남음'),
        ),
        findsNothing,
      );
    });

    testWidgets('설정 때문에 취소된 예약은 보이지 않고 남은 자리를 적는다', (tester) async {
      await pumpSchoolbook(tester, lastRoomId: 1512);
      expect(_inRow('4교시', '4-2'), findsNothing);
      expect(_inRow('4교시', '4-1'), findsOneWidget);
      expect(_inRow('4교시', SchoolbookStrings.remaining(1)), findsOneWidget);
      expect(find.byKey(PeriodRowTile.bookKey('4교시')), findsOneWidget);
    });
  });

  group('오류 · 빈 상태', () {
    testWidgets('교실 목록을 못 불러오면 다시 시도', (tester) async {
      var fail = true;
      final routes = defaultRoutes()
        ..['GET /api/rooms/'] = (_) => fail ? http.Response('x', 500) : fixtureResponse('rooms');
      await pumpSchoolbook(tester, routes: routes, lastRoomId: 1511);
      expect(find.text(SchoolbookStrings.loadFailed), findsOneWidget);
      fail = false;
      await tester.tap(find.text(SchoolbookStrings.retry));
      await settle(tester);
      expect(_chipSelected(tester, 1511), isTrue);
    });

    testWidgets('학교 코드가 안 맞으면 다시 연결', (tester) async {
      final routes = defaultRoutes()
        ..['GET /api/rooms/'] = (_) => fixtureResponse('login_unknown');
      await pumpSchoolbook(tester, routes: routes);
      expect(find.text(SchoolbookStrings.disconnectedTitle), findsOneWidget);
      await tester.tap(find.text(SchoolbookStrings.reconnect));
      await settle(tester);
      expect(find.byType(SchoolbookConnectView), findsOneWidget);
    });

    testWidgets('교시를 등록하지 않은 학교', (tester) async {
      final routes = defaultRoutes()..['GET /api/rooms/'] = (_) => http.Response('{}', 403);
      await pumpSchoolbook(tester, routes: routes);
      expect(find.text(SchoolbookStrings.noPeriods), findsOneWidget);
    });

    testWidgets('교실이 하나도 없는 학교', (tester) async {
      final routes = defaultRoutes()..['GET /api/rooms/'] = (_) => jsonResponse([]);
      await pumpSchoolbook(tester, routes: routes);
      expect(find.text(SchoolbookStrings.noRooms), findsOneWidget);
    });

    testWidgets('보던 교실이 지워졌으면 목록을 다시 불러 첫 교실로', (tester) async {
      final routes = defaultRoutes()..remove('GET /api/rooms/1511/bookings/');
      final server = await pumpSchoolbook(tester, routes: routes, lastRoomId: 1511);
      expect(_chipSelected(tester, 1513), isTrue);
      expect(server.count('GET', '/api/rooms/') - server.count('GET', '/api/rooms/15'), 2);
    });

    testWidgets('그날 교시가 없으면 안내', (tester) async {
      final routes = defaultRoutes()
        ..['GET /api/rooms/1511/bookings/'] =
            (_) => jsonResponse({'date': '2026-10-20', 'periods': []});
      await pumpSchoolbook(tester, routes: routes, lastRoomId: 1511);
      expect(find.text(SchoolbookStrings.noSlots), findsOneWidget);
    });

    testWidgets('하루 예약을 못 불러오면 다시 시도', (tester) async {
      final routes = defaultRoutes()
        ..['GET /api/rooms/1511/bookings/'] = (_) => http.Response('x', 502);
      await pumpSchoolbook(tester, routes: routes, lastRoomId: 1511);
      expect(find.text(SchoolbookStrings.loadFailed), findsOneWidget);
      expect(_chipSelected(tester, 1511), isTrue);
    });
  });
}
