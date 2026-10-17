import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/cancel_sheet.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/day_nav.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/period_row_tile.dart';

import '../fake_server.dart';
import 'schoolbook_screen_harness.dart';

// 체육관 D 3교시의 5-1(예약 번호 223116)
const _delete = 'DELETE /api/rooms/1511/bookings/223116/';

Finder _person(String period, String text) => find.descendant(
      of: find.byKey(PeriodRowTile.rowKey(period)),
      matching: find.text(text),
    );

void main() {
  testWidgets('예약 이름을 누르면 빈 비밀번호 칸으로 취소 시트가 뜬다', (tester) async {
    final routes = defaultRoutes()..[_delete] = (_) => http.Response('', 204);
    final server = await pumpSchoolbook(tester,
        routes: routes, lastRoomId: 1511, booker: '체육전담', password: '1234');
    await tester.tap(_person('3교시', '5-1'));
    await tester.pumpAndSettle();
    expect(find.text(SchoolbookStrings.cancelSheetTitle('5-1', '3교시')), findsOneWidget);
    // 저장한 비밀번호를 채우지 않는다 — 취소는 매번 묻는다(사용자 결정)
    expect(
      tester.widget<TextField>(find.byKey(CancelSheet.passwordKey)).controller?.text,
      isEmpty,
    );

    await tester.enterText(find.byKey(CancelSheet.passwordKey), '1234');
    await tester.pump();
    await tester.tap(find.byKey(CancelSheet.submitKey));
    await settle(tester);
    final req = server.requests.lastWhere((r) => r.method == 'DELETE');
    expect(jsonDecode(req.body), {'password': '1234'});
    expect(find.byType(CancelSheet), findsNothing);
    expect(find.text(SchoolbookStrings.canceled), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('비밀번호가 틀리면 시트에 서버 문구', (tester) async {
    final routes = defaultRoutes()..[_delete] = (_) => fixtureResponse('cancel_wrong_password');
    await pumpSchoolbook(tester, routes: routes, lastRoomId: 1511);
    await tester.tap(_person('3교시', '5-1'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(CancelSheet.passwordKey), '0000');
    await tester.pump();
    await tester.tap(find.byKey(CancelSheet.submitKey));
    await settle(tester);
    expect(find.byType(CancelSheet), findsOneWidget);
    expect(find.text('비밀번호가 맞지 않습니다.'), findsOneWidget);
  });

  testWidgets('남이 먼저 지운 예약이면 이미 취소됐다고 하고 교실은 그대로', (tester) async {
    final routes = defaultRoutes()..[_delete] = (_) => fixtureResponse('cancel_not_found');
    await pumpSchoolbook(tester, routes: routes, lastRoomId: 1511);
    await tester.tap(_person('3교시', '5-1'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(CancelSheet.passwordKey), '1234');
    await tester.pump();
    await tester.tap(find.byKey(CancelSheet.submitKey));
    await settle(tester);
    expect(find.text(SchoolbookStrings.alreadyCanceled), findsOneWidget);
    expect(find.text('체육관'), findsOneWidget);
  });

  testWidgets('고정 예약은 눌러도 시트가 뜨지 않는다', (tester) async {
    await pumpSchoolbook(tester, lastRoomId: 1511);
    await tester.tap(_person('1교시', SchoolbookStrings.fixedPerson('3-2')));
    await tester.pumpAndSettle();
    expect(find.byType(CancelSheet), findsNothing);
  });

  testWidgets('지난 날 예약은 눌러도 시트가 뜨지 않는다', (tester) async {
    await pumpSchoolbook(tester, lastRoomId: 1511);
    await tester.tap(find.byKey(DayNav.previousKey));
    await settle(tester);
    await tester.tap(_person('3교시', '5-1'));
    await tester.pumpAndSettle();
    expect(find.byType(CancelSheet), findsNothing);
  });
}
