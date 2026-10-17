import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/schoolbook/presentation/providers/schoolbook_providers.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/book_sheet.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/period_row_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_server.dart';
import 'schoolbook_screen_harness.dart';

const _post = 'POST /api/rooms/1511/bookings/';

Future<void> _openSheet(WidgetTester tester) async {
  for (final p in ['2교시', '4교시']) {
    await tester.tap(find.descendant(
      of: find.byKey(PeriodRowTile.rowKey(p)),
      matching: find.byType(Checkbox),
    ));
  }
  await tester.pumpAndSettle();
  await tester.tap(find.text(SchoolbookStrings.bookButton(['2교시', '4교시'])));
  await tester.pumpAndSettle();
}

String _field(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key)).controller?.text ?? '';

Future<void> _submit(WidgetTester tester) async {
  await tester.pump(); // 입력 뒤 버튼 활성 상태를 그린다
  await tester.tap(find.byKey(BookSheet.submitKey));
  await settle(tester);
}

void main() {
  testWidgets('예약자와 저장한 비밀번호가 미리 채워져 있어 예약만 누르면 된다', (tester) async {
    final routes = defaultRoutes()..[_post] = (_) => fixtureResponse('book_ok');
    final server = await pumpSchoolbook(tester,
        routes: routes, lastRoomId: 1511, booker: '체육전담', password: '1234');
    await _openSheet(tester);
    expect(find.text('체육관 · 10월 20일 (화) 2·4교시'), findsOneWidget);
    expect(_field(tester, BookSheet.bookerKey), '체육전담');
    expect(_field(tester, BookSheet.passwordKey), '1234');

    final daysBefore = server.count('GET', '/api/rooms/1511/bookings/');
    await _submit(tester);
    final body = jsonDecode(server.requests.lastWhere((r) => r.method == 'POST').body);
    expect(body['booker'], '체육전담');
    expect(body['password'], '1234');
    expect(body['period_ids'], [1603, 1605]);
    expect(find.text(SchoolbookStrings.booked(['2교시', '4교시'])), findsOneWidget);
    expect(find.byType(BookSheet), findsNothing);
    expect(server.count('GET', '/api/rooms/1511/bookings/'), greaterThan(daysBefore));
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('예약 알림이 떠 있는 동안에도 다음 예약 버튼을 누를 수 있다', (tester) async {
    final routes = defaultRoutes()..[_post] = (_) => fixtureResponse('book_ok');
    await pumpSchoolbook(tester,
        routes: routes, lastRoomId: 1511, booker: '체육전담', password: '1234');
    await _openSheet(tester);
    await _submit(tester);
    await tester.tap(find.descendant(
      of: find.byKey(PeriodRowTile.rowKey('6교시')),
      matching: find.byType(Checkbox),
    ));
    await tester.pump();
    expect(find.text(SchoolbookStrings.booked(['2교시', '4교시'])), findsOneWidget);
    expect(find.text(SchoolbookStrings.bookButton(['6교시'])).hitTestable(), findsOneWidget);
  });

  testWidgets('처음 넣은 예약자와 비밀번호는 성공하면 기억한다', (tester) async {
    final routes = defaultRoutes()..[_post] = (_) => fixtureResponse('book_ok');
    await pumpSchoolbook(tester, routes: routes, lastRoomId: 1511);
    await _openSheet(tester);
    await tester.enterText(find.byKey(BookSheet.bookerKey), '6-3');
    await tester.enterText(find.byKey(BookSheet.passwordKey), '5678');
    await _submit(tester);
    expect(await const FlutterSecureStorage().read(key: 'schoolbook_password_v1'), '5678');
    final raw = (await SharedPreferences.getInstance()).getString(schoolbookSettingsPrefsKey);
    expect((jsonDecode(raw ?? '{}') as Map)['booker'], '6-3');
  });

  testWidgets('예약 버튼은 요청 중에 다시 눌리지 않는다', (tester) async {
    final gate = Completer<http.Response>();
    final routes = defaultRoutes()..[_post] = (_) => gate.future;
    final server = await pumpSchoolbook(tester,
        routes: routes, lastRoomId: 1511, booker: '체육전담', password: '1234');
    await _openSheet(tester);
    await tester.tap(find.byKey(BookSheet.submitKey));
    await tester.pump();
    await tester.tap(find.byKey(BookSheet.submitKey));
    await tester.pump();
    expect(server.count('POST', '/api/rooms/'), 1);
    gate.complete(fixtureResponse('book_ok'));
    await settle(tester);
  });

  testWidgets('자리가 없으면 시트가 남고 서버 문구를 보인다', (tester) async {
    final routes = defaultRoutes()..[_post] = (_) => fixtureResponse('book_full');
    final server = await pumpSchoolbook(tester,
        routes: routes, lastRoomId: 1511, booker: '체육전담', password: '1234');
    await _openSheet(tester);
    final daysBefore = server.count('GET', '/api/rooms/1511/bookings/');
    await _submit(tester);
    expect(find.byType(BookSheet), findsOneWidget);
    expect(find.text('3교시의 남은 자리가 없습니다.'), findsOneWidget);
    expect(server.count('GET', '/api/rooms/1511/bookings/'), greaterThan(daysBefore));
  });

  testWidgets('비밀번호가 4자리가 아니면 예약하지 않는다', (tester) async {
    final routes = defaultRoutes()..[_post] = (_) => fixtureResponse('book_ok');
    final server = await pumpSchoolbook(tester, routes: routes, lastRoomId: 1511, booker: '5-1');
    await _openSheet(tester);
    await tester.enterText(find.byKey(BookSheet.passwordKey), '123');
    await _submit(tester);
    expect(server.count('POST', '/api/rooms/'), 0);
    expect(find.byType(BookSheet), findsOneWidget);
  });

  testWidgets('응답을 못 받으면 시트를 닫고 목록을 확인하라고 한다', (tester) async {
    final routes = defaultRoutes()..[_post] = (_) => http.Response('x', 502);
    await pumpSchoolbook(tester,
        routes: routes, lastRoomId: 1511, booker: '체육전담', password: '1234');
    await _openSheet(tester);
    await _submit(tester);
    expect(find.byType(BookSheet), findsNothing);
    expect(find.text(SchoolbookStrings.resultUnknown), findsOneWidget);
  });
}
