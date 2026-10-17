import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/schoolbook/data/schoolbook_password_store.dart';
import 'package:planroutine/features/schoolbook/presentation/providers/schoolbook_providers.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/week_strip.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/book_sheet.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/period_row_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_server.dart';
import 'schoolbook_screen_harness.dart';

const _post = 'POST /api/rooms/1511/bookings/';

/// 실기기의 보안 저장소처럼 읽기가 몇 프레임 걸린다.
class _SlowStore extends SchoolbookPasswordStore {
  const _SlowStore();
  @override
  Future<String?> read() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return '1234';
  }
}

Future<void> _tapBook(WidgetTester tester, String period) async {
  await tester.tap(find.byKey(PeriodRowTile.bookKey(period)));
  await tester.pump();
}

String _field(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key)).controller?.text ?? '';

Future<void> _submitSheet(WidgetTester tester) async {
  await tester.pump(); // 입력 뒤 버튼 활성 상태를 그린다
  await tester.tap(find.byKey(BookSheet.submitKey));
  await settle(tester);
}

void main() {
  group('예약자와 비밀번호가 저장돼 있으면 — 바로 예약', () {
    testWidgets('[예약]을 누르면 시트 없이 바로 잡히고 알린다', (tester) async {
      final routes = defaultRoutes()..[_post] = (_) => fixtureResponse('book_ok');
      final server = await pumpSchoolbook(tester,
          routes: routes, lastRoomId: 1511, booker: '체육전담', password: '1234');
      final daysBefore = server.count('GET', '/api/rooms/1511/bookings/');
      await _tapBook(tester, '2교시');
      expect(find.byType(BookSheet), findsNothing);
      await settle(tester);
      final body = jsonDecode(server.requests.lastWhere((r) => r.method == 'POST').body);
      expect(body['booker'], '체육전담');
      expect(body['password'], '1234');
      expect(body['period_ids'], [1603]);
      expect(find.text(SchoolbookStrings.booked('체육관', fixtureDay, ['2교시'])), findsOneWidget);
      expect(server.count('GET', '/api/rooms/1511/bookings/'), greaterThan(daysBefore));
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('요청 중에는 그 줄에 예약 중…이 뜨고 다시 눌리지 않는다', (tester) async {
      final gate = Completer<http.Response>();
      final routes = defaultRoutes()..[_post] = (_) => gate.future;
      final server = await pumpSchoolbook(tester,
          routes: routes, lastRoomId: 1511, booker: '체육전담', password: '1234');
      await _tapBook(tester, '2교시');
      await tester.pump();
      expect(find.byKey(PeriodRowTile.bookKey('2교시')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(PeriodRowTile.rowKey('2교시')),
          matching: find.text(SchoolbookStrings.booking),
        ),
        findsOneWidget,
      );
      expect(server.count('POST', '/api/rooms/'), 1);
      gate.complete(fixtureResponse('book_ok'));
      await settle(tester);
    });

    testWidgets('비밀번호를 읽는 사이에 두 번 눌러도 한 번만 보낸다', (tester) async {
      final routes = defaultRoutes()..[_post] = (_) => fixtureResponse('book_ok');
      final server = await pumpSchoolbook(tester,
          routes: routes, lastRoomId: 1511, booker: '체육전담', passwordStore: const _SlowStore());
      await tester.tap(find.byKey(PeriodRowTile.bookKey('2교시')));
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byKey(PeriodRowTile.bookKey('2교시')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(PeriodRowTile.bookKey('2교시')));
      }
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(server.count('POST', '/api/rooms/'), 1);
    });

    testWidgets('예약 뒤 목록을 다시 부르는 동안에는 그 교시를 다시 누를 수 없다', (tester) async {
      Completer<http.Response>? reload;
      var booked = false;
      final routes = defaultRoutes()
        ..[_post] = ((_) {
          booked = true;
          return fixtureResponse('book_ok');
        })
        ..['GET /api/rooms/1511/bookings/'] = ((_) {
          if (!booked) return fixtureResponse('day_gym');
          reload = Completer<http.Response>();
          return reload!.future;
        });
      final server = await pumpSchoolbook(tester,
          routes: routes, lastRoomId: 1511, booker: '체육전담', password: '1234');
      await _tapBook(tester, '2교시');
      for (var i = 0; i < 20 && reload == null; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
      expect(reload, isNotNull, reason: '예약 뒤 목록을 다시 부른다');
      expect(find.byKey(PeriodRowTile.bookKey('2교시')).hitTestable(), findsNothing);
      reload?.complete(fixtureResponse('day_gym'));
      await settle(tester);
      expect(server.count('POST', '/api/rooms/'), 1);
    });

    testWidgets('요청 중 다른 날로 가도 그날 같은 교시는 잠기지 않고, 알림은 예약한 날을 말한다', (tester) async {
      final gate = Completer<http.Response>();
      final routes = defaultRoutes()..[_post] = (_) => gate.future;
      await pumpSchoolbook(tester,
          routes: routes, lastRoomId: 1511, booker: '체육전담', password: '1234');
      await _tapBook(tester, '2교시');
      await tester.pump();
      await tester.tap(find.byKey(WeekStrip.dayKey(DateTime(2026, 10, 21))));
      await settle(tester);
      expect(find.byKey(PeriodRowTile.bookKey('2교시')), findsOneWidget);
      gate.complete(fixtureResponse('book_ok'));
      await settle(tester);
      expect(find.textContaining('10월 20일'), findsOneWidget);
    });

    testWidgets('알림이 떠 있는 동안에도 다른 교시 예약을 누를 수 있다', (tester) async {
      final routes = defaultRoutes()..[_post] = (_) => fixtureResponse('book_ok');
      final server = await pumpSchoolbook(tester,
          routes: routes, lastRoomId: 1511, booker: '체육전담', password: '1234');
      await _tapBook(tester, '2교시');
      await settle(tester);
      expect(find.text(SchoolbookStrings.booked('체육관', fixtureDay, ['2교시'])), findsOneWidget);
      expect(find.byKey(PeriodRowTile.bookKey('4교시')).hitTestable(), findsOneWidget);
      await _tapBook(tester, '4교시');
      await settle(tester);
      expect(server.count('POST', '/api/rooms/'), 2);
    });

    testWidgets('자리가 없으면 서버 문구를 알리고 목록을 다시 부른다', (tester) async {
      final routes = defaultRoutes()..[_post] = (_) => fixtureResponse('book_full');
      final server = await pumpSchoolbook(tester,
          routes: routes, lastRoomId: 1511, booker: '체육전담', password: '1234');
      final daysBefore = server.count('GET', '/api/rooms/1511/bookings/');
      await _tapBook(tester, '2교시');
      await settle(tester);
      expect(find.text('3교시의 남은 자리가 없습니다.'), findsOneWidget);
      expect(server.count('GET', '/api/rooms/1511/bookings/'), greaterThan(daysBefore));
    });

    testWidgets('응답을 못 받으면 목록을 확인하라고 한다', (tester) async {
      final routes = defaultRoutes()..[_post] = (_) => http.Response('x', 502);
      await pumpSchoolbook(tester,
          routes: routes, lastRoomId: 1511, booker: '체육전담', password: '1234');
      await _tapBook(tester, '2교시');
      await settle(tester);
      expect(find.text(SchoolbookStrings.resultUnknown), findsOneWidget);
    });
  });

  group('저장된 값이 없으면 — 입력 시트', () {
    testWidgets('처음 넣은 예약자와 비밀번호는 성공하면 기억한다', (tester) async {
      final routes = defaultRoutes()..[_post] = (_) => fixtureResponse('book_ok');
      await pumpSchoolbook(tester, routes: routes, lastRoomId: 1511);
      await _tapBook(tester, '2교시');
      await tester.pumpAndSettle();
      expect(find.text('체육관 · 10월 20일 (화) 2교시'), findsOneWidget);
      expect(_field(tester, BookSheet.passwordKey), isEmpty);
      await tester.enterText(find.byKey(BookSheet.bookerKey), '6-3');
      await tester.enterText(find.byKey(BookSheet.passwordKey), '5678');
      await _submitSheet(tester);
      expect(await const FlutterSecureStorage().read(key: 'schoolbook_password_v1'), '5678');
      final raw = (await SharedPreferences.getInstance()).getString(schoolbookSettingsPrefsKey);
      expect((jsonDecode(raw ?? '{}') as Map)['booker'], '6-3');
      expect(find.text(SchoolbookStrings.booked('체육관', fixtureDay, ['2교시'])), findsOneWidget);
    });

    testWidgets('요청 중에는 바깥을 눌러도 시트가 닫히지 않고, 끝나면 결과를 알린다', (tester) async {
      final gate = Completer<http.Response>();
      final routes = defaultRoutes()..[_post] = (_) => gate.future;
      await pumpSchoolbook(tester, routes: routes, lastRoomId: 1511, booker: '체육전담');
      await _tapBook(tester, '2교시');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(BookSheet.passwordKey), '1234');
      await tester.pump();
      await tester.tap(find.byKey(BookSheet.submitKey));
      await tester.pump();
      await tester.tapAt(const Offset(200, 40)); // 시트 바깥(어두운 막)
      await tester.pumpAndSettle();
      expect(find.byType(BookSheet), findsOneWidget);
      gate.complete(fixtureResponse('book_ok'));
      await settle(tester);
      expect(find.byType(BookSheet), findsNothing);
      expect(find.text(SchoolbookStrings.booked('체육관', fixtureDay, ['2교시'])), findsOneWidget);
    });

    testWidgets('비밀번호가 4자리가 아니면 예약하지 않는다', (tester) async {
      final routes = defaultRoutes()..[_post] = (_) => fixtureResponse('book_ok');
      final server =
          await pumpSchoolbook(tester, routes: routes, lastRoomId: 1511, booker: '5-1');
      await _tapBook(tester, '2교시');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(BookSheet.passwordKey), '123');
      await _submitSheet(tester);
      expect(server.count('POST', '/api/rooms/'), 0);
      expect(find.byType(BookSheet), findsOneWidget);
    });
  });
}
