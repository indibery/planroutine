import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/schoolbook/presentation/providers/schoolbook_providers.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/day_nav.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/period_row_tile.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/room_bar.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/schoolbook_connect_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_server.dart';
import 'schoolbook_screen_harness.dart';

Finder _roomName(String name) =>
    find.descendant(of: find.byType(RoomBar), matching: find.text(name));

Finder _checkbox(String period) =>
    find.descendant(of: find.byKey(PeriodRowTile.rowKey(period)), matching: find.byType(Checkbox));

Finder _inRow(String period, String text) =>
    find.descendant(of: find.byKey(PeriodRowTile.rowKey(period)), matching: find.text(text));

void main() {
  group('교실 고르기', () {
    testWidgets('기억한 교실이 열린다', (tester) async {
      await pumpSchoolbook(tester, lastRoomId: 1511);
      expect(_roomName('체육관'), findsOneWidget);
    });

    testWidgets('기억한 교실이 없으면 첫 교실', (tester) async {
      await pumpSchoolbook(tester, lastRoomId: 999);
      expect(_roomName('3층 다목적실 겸 방과후 돌봄교실'), findsOneWidget);
    });

    testWidgets('교실 시트에서 과학실을 고르면 과학실 하루가 뜨고 기억한다', (tester) async {
      await pumpSchoolbook(tester, lastRoomId: 1511);
      await tester.tap(find.byType(RoomBar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('과학실').last);
      await settle(tester);
      expect(_roomName('과학실'), findsOneWidget);
      expect(_inRow('3교시', '6-2'), findsOneWidget);
      final raw = (await SharedPreferences.getInstance()).getString(schoolbookSettingsPrefsKey);
      expect((jsonDecode(raw ?? '{}') as Map)['lastRoomId'], 1512);
    });
  });

  group('날짜 넘기기', () {
    testWidgets('토요일에 열면 다음 월요일', (tester) async {
      await pumpSchoolbook(tester, lastRoomId: 1511, now: DateTime(2026, 10, 24, 9));
      expect(find.text('10월 26일 (월)'), findsOneWidget);
    });

    testWidgets('마지막 예약 가능일에서는 ▶를 누를 수 없다', (tester) async {
      // 10월 20일에 열면 마지막 예약 가능일은 2027-02-26(금, 2월 말일 전 평일)
      await pumpSchoolbook(tester, lastRoomId: 1511);
      for (var i = 0; i < 200; i++) {
        if (tester.widget<DayNav>(find.byType(DayNav)).onNext == null) break;
        await tester.tap(find.byKey(DayNav.nextKey));
        await tester.pump();
      }
      expect(find.text('2월 26일 (금)'), findsOneWidget);
      expect(tester.widget<DayNav>(find.byType(DayNav)).onNext, isNull);
    });

    testWidgets('지난 날짜는 체크할 수 없다', (tester) async {
      await pumpSchoolbook(tester, lastRoomId: 1512);
      await tester.tap(find.byKey(DayNav.previousKey));
      await settle(tester);
      expect(find.text('10월 19일 (월)'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    });
  });

  group('체육관 하루', () {
    testWidgets('고정으로 찬 1교시는 체크칸이 없고 고정 표시', (tester) async {
      await pumpSchoolbook(tester, lastRoomId: 1511);
      expect(_checkbox('1교시'), findsNothing);
      expect(_inRow('1교시', SchoolbookStrings.fixedPerson('3-2')), findsOneWidget);
    });

    testWidgets('2·4교시를 체크하면 예약 버튼, 날짜를 넘기면 풀린다', (tester) async {
      await pumpSchoolbook(tester, lastRoomId: 1511);
      expect(find.text(SchoolbookStrings.bookButton(['2교시', '4교시'])), findsNothing);
      await tester.tap(_checkbox('2교시'));
      await tester.tap(_checkbox('4교시'));
      await tester.pumpAndSettle();
      expect(find.text(SchoolbookStrings.bookButton(['2교시', '4교시'])), findsOneWidget);

      await tester.tap(find.byKey(DayNav.nextKey));
      await settle(tester);
      expect(find.textContaining('예약하기'), findsNothing);
    });

    testWidgets('빈 교시는 비어 있음', (tester) async {
      await pumpSchoolbook(tester, lastRoomId: 1511);
      expect(_inRow('2교시', SchoolbookStrings.free), findsOneWidget);
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
      expect(_roomName('체육관'), findsOneWidget);
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
      expect(_roomName('3층 다목적실 겸 방과후 돌봄교실'), findsOneWidget);
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
      expect(_roomName('체육관'), findsOneWidget);
    });
  });
}
