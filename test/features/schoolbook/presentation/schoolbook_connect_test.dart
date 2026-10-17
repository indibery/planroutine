import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/schoolbook/presentation/providers/schoolbook_providers.dart';
import 'package:planroutine/features/schoolbook/presentation/screens/schoolbook_screen.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/schoolbook_connect_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_server.dart';

const _code = 'abcdefghijk12';
const _loginPath = 'GET /api/accounts/login/$_code/';

Future<FakeSchoolbook> _pump(
  WidgetTester tester,
  Map<String, FutureOr<http.Response> Function(http.Request)> routes,
) async {
  final server = FakeSchoolbook(routes);
  await tester.pumpWidget(ProviderScope(
    overrides: [schoolbookApiClientProvider.overrideWithValue(server.client())],
    child: const MaterialApp(home: SchoolbookScreen()),
  ));
  await tester.pumpAndSettle();
  return server;
}

Future<void> _connect(WidgetTester tester, String input) async {
  await tester.enterText(find.byKey(SchoolbookConnectView.fieldKey), input);
  await tester.tap(find.byKey(SchoolbookConnectView.connectKey));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('연결 전에는 연결 화면이 뜬다', (tester) async {
    await _pump(tester, {});
    expect(find.text(SchoolbookStrings.connectTitle), findsOneWidget);
    expect(find.text(SchoolbookStrings.connectHint), findsOneWidget);
  });

  testWidgets('링크를 붙여 넣고 연결하면 저장하고 학교 이름을 알린다', (tester) async {
    await _pump(tester, {_loginPath: (_) => fixtureResponse('login')});
    await _connect(tester, ' https://schoolbook.zzolab.com/$_code/room/3 ');

    final raw = (await SharedPreferences.getInstance()).getString(schoolbookSettingsPrefsKey);
    final json = jsonDecode(raw ?? '{}') as Map<String, dynamic>;
    // 픽스처의 코드는 가려져 있어 저장값은 응답이 아니라 입력에서 온다
    expect(json['code'], _code);
    expect(json['schoolName'], '플랜테스트');
    expect(find.text(SchoolbookStrings.connected('플랜테스트')), findsOneWidget);
    expect(find.byType(SchoolbookConnectView), findsNothing);
  });

  testWidgets('없는 학교면 안내하고 저장하지 않는다', (tester) async {
    await _pump(tester, {_loginPath: (_) => fixtureResponse('login_unknown')});
    await _connect(tester, _code);
    expect(find.text(SchoolbookStrings.connectNotFound), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString(schoolbookSettingsPrefsKey),
      isNull,
    );
  });

  testWidgets('코드가 아닌 글이면 요청 없이 같은 안내', (tester) async {
    final server = await _pump(tester, {});
    await _connect(tester, 'https://example.com/hello');
    expect(find.text(SchoolbookStrings.connectNotFound), findsOneWidget);
    expect(server.requests, isEmpty);
  });

  testWidgets('교시가 없는 학교면 스쿨북에서 먼저 등록하라고 한다', (tester) async {
    await _pump(tester, {
      _loginPath: (_) => jsonResponse({'name': '새학교', 'code': _code, 'periods': [], 'notices': []}),
    });
    await _connect(tester, _code);
    expect(find.text(SchoolbookStrings.noPeriods), findsOneWidget);
  });

  testWidgets('요청 중에는 연결 버튼이 다시 눌리지 않는다', (tester) async {
    final gate = Completer<http.Response>();
    final server = await _pump(tester, {_loginPath: (_) => gate.future});
    await tester.enterText(find.byKey(SchoolbookConnectView.fieldKey), _code);
    await tester.tap(find.byKey(SchoolbookConnectView.connectKey));
    await tester.pump();
    await tester.tap(find.byKey(SchoolbookConnectView.connectKey));
    await tester.pump();
    expect(server.requests, hasLength(1));
    gate.complete(fixtureResponse('login_unknown'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  });
}
