import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/cancel_sheet.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/period_row_tile.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/room_chips.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/week_strip.dart';
import 'package:planroutine/shared/widgets/pill_chip.dart';

import '../fake_server.dart';
import 'schoolbook_screen_harness.dart';

// 체육관 D 3교시의 5-1(예약 번호 223116). 저장한 예약자를 5-1로 두면 내 예약이다.
const _delete = 'DELETE /api/rooms/1511/bookings/223116/';

Finder _mine(String booker) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == SchoolbookStrings.mine(booker),
    );

Future<void> _openCancel(WidgetTester tester) async {
  await tester.tap(find.byKey(PeriodRowTile.cancelKey('3교시')));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester, String password) async {
  await tester.enterText(find.byKey(CancelSheet.passwordKey), password);
  await tester.pump();
  await tester.tap(find.byKey(CancelSheet.submitKey));
}

void main() {
  testWidgets('저장한 비밀번호가 있으면 [취소]를 누르는 즉시 시트 없이 취소된다', (tester) async {
    final routes = defaultRoutes()..[_delete] = (_) => http.Response('', 204);
    final server = await pumpSchoolbook(tester,
        routes: routes, lastRoomId: 1511, booker: '5-1', password: '1234');
    await tester.tap(find.byKey(PeriodRowTile.cancelKey('3교시')));
    await settle(tester);
    expect(find.byType(CancelSheet), findsNothing);
    final req = server.requests.lastWhere((r) => r.method == 'DELETE');
    expect(jsonDecode(req.body), {'password': '1234'});
    expect(find.text(SchoolbookStrings.canceled), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('바로 취소하는 동안 그 줄은 `취소 중…`이고 DELETE는 한 번만 나간다', (tester) async {
    final gate = Completer<http.Response>();
    final routes = defaultRoutes()..[_delete] = (_) => gate.future;
    final server = await pumpSchoolbook(tester,
        routes: routes, lastRoomId: 1511, booker: '5-1', password: '1234');
    await tester.tap(find.byKey(PeriodRowTile.cancelKey('3교시')));
    await tester.pump();
    await tester.pump();
    expect(find.text(SchoolbookStrings.canceling), findsOneWidget);
    expect(find.byKey(PeriodRowTile.cancelKey('3교시')), findsNothing);
    gate.complete(http.Response('', 204));
    await settle(tester);
    expect(server.requests.where((r) => r.method == 'DELETE'), hasLength(1));
    expect(find.text(SchoolbookStrings.canceled), findsOneWidget);
  });

  testWidgets('저장한 비밀번호가 틀리면 빈 칸 시트에 서버 문구를 띄운다', (tester) async {
    final routes = defaultRoutes()..[_delete] = (_) => fixtureResponse('cancel_wrong_password');
    await pumpSchoolbook(tester,
        routes: routes, lastRoomId: 1511, booker: '5-1', password: '9999');
    await tester.tap(find.byKey(PeriodRowTile.cancelKey('3교시')));
    await settle(tester);
    expect(find.byType(CancelSheet), findsOneWidget);
    expect(find.text('비밀번호가 맞지 않습니다.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(CancelSheet.passwordKey)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('저장한 비밀번호가 없으면 빈 칸 시트로 묻고, 성공하면 기억한다', (tester) async {
    final routes = defaultRoutes()..[_delete] = (_) => http.Response('', 204);
    final server = await pumpSchoolbook(tester, routes: routes, lastRoomId: 1511, booker: '5-1');
    await _openCancel(tester);
    expect(find.text(SchoolbookStrings.cancelSheetTitle('5-1', '3교시')), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(CancelSheet.passwordKey)).controller?.text,
      isEmpty,
    );
    await _submit(tester, '1234');
    await settle(tester);
    final req = server.requests.lastWhere((r) => r.method == 'DELETE');
    expect(jsonDecode(req.body), {'password': '1234'});
    expect(find.byType(CancelSheet), findsNothing);
    expect(find.text(SchoolbookStrings.canceled), findsOneWidget);
    expect(await const FlutterSecureStorage().read(key: 'schoolbook_password_v1'), '1234');
  });

  testWidgets('시트를 열면 떠 있던 알림을 닫는다 — 시트 안 오류 문구를 가리지 않게', (tester) async {
    final routes = defaultRoutes()
      ..['POST /api/rooms/1511/bookings/'] = ((_) => fixtureResponse('book_ok'))
      ..[_delete] = (_) => fixtureResponse('cancel_wrong_password');
    await pumpSchoolbook(tester,
        routes: routes, lastRoomId: 1511, booker: '5-1', password: '1234');
    await tester.tap(find.byKey(PeriodRowTile.bookKey('2교시')));
    await settle(tester);
    expect(find.byType(SnackBar), findsOneWidget);
    // 저장한 비밀번호가 틀려 시트로 넘어간다
    await tester.tap(find.byKey(PeriodRowTile.cancelKey('3교시')));
    await settle(tester);
    expect(find.byType(CancelSheet), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('취소 요청 중에는 바깥을 눌러도 시트가 닫히지 않는다', (tester) async {
    final gate = Completer<http.Response>();
    final routes = defaultRoutes()..[_delete] = (_) => gate.future;
    await pumpSchoolbook(tester, routes: routes, lastRoomId: 1511, booker: '5-1');
    await _openCancel(tester);
    await _submit(tester, '1234');
    await tester.pump();
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(find.byType(CancelSheet), findsOneWidget);
    gate.complete(http.Response('', 204));
    await settle(tester);
    expect(find.text(SchoolbookStrings.canceled), findsOneWidget);
  });

  testWidgets('비밀번호가 틀리면 시트에 서버 문구', (tester) async {
    final routes = defaultRoutes()..[_delete] = (_) => fixtureResponse('cancel_wrong_password');
    await pumpSchoolbook(tester, routes: routes, lastRoomId: 1511, booker: '5-1');
    await _openCancel(tester);
    await _submit(tester, '0000');
    await settle(tester);
    expect(find.byType(CancelSheet), findsOneWidget);
    expect(find.text('비밀번호가 맞지 않습니다.'), findsOneWidget);
  });

  testWidgets('남이 먼저 지운 예약이면 이미 취소됐다고 하고 교실은 그대로', (tester) async {
    final routes = defaultRoutes()..[_delete] = (_) => fixtureResponse('cancel_not_found');
    await pumpSchoolbook(tester, routes: routes, lastRoomId: 1511, booker: '5-1');
    await _openCancel(tester);
    await _submit(tester, '1234');
    await settle(tester);
    expect(find.text(SchoolbookStrings.alreadyCanceled), findsOneWidget);
    expect(tester.widget<PillChip>(find.byKey(RoomChips.chipKey(1511))).selected, isTrue);
  });

  testWidgets('고정 예약과 다른 반 예약에는 취소 버튼이 없다', (tester) async {
    await pumpSchoolbook(tester, lastRoomId: 1511, booker: '체육전담');
    expect(find.byKey(PeriodRowTile.cancelKey('1교시')), findsNothing);
    expect(find.byKey(PeriodRowTile.cancelKey('3교시')), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('지난 날의 내 예약에는 취소 버튼이 없다', (tester) async {
    await pumpSchoolbook(tester, lastRoomId: 1511, booker: '5-1');
    await tester.tap(find.byKey(WeekStrip.dayKey(DateTime(2026, 10, 19))));
    await settle(tester);
    expect(_mine('5-1'), findsOneWidget);
    expect(find.byKey(PeriodRowTile.cancelKey('3교시')), findsNothing);
  });
}
