import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/schoolbook/presentation/providers/schoolbook_providers.dart';
import 'package:planroutine/features/schoolbook/presentation/screens/schoolbook_settings_screen.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/schoolbook_connect_view.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/schoolbook_module_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_server.dart';
import 'schoolbook_screen_harness.dart';

const _otherCode = 'zyxwvutsrqp98';

Future<void> _pump(WidgetTester tester, {String? password}) async {
  SharedPreferences.setMockInitialValues({
    schoolbookSettingsPrefsKey: jsonEncode({
      'code': testCode,
      'schoolName': '옛학교',
      'lastRoomId': 1511,
      'booker': '5-1',
    }),
  });
  FlutterSecureStorage.setMockInitialValues({'schoolbook_password_v1': ?password});
  final server = FakeSchoolbook({
    'GET /api/accounts/login/$_otherCode/': (_) => fixtureResponse('login'),
  });
  await tester.pumpWidget(ProviderScope(
    overrides: [schoolbookApiClientProvider.overrideWithValue(server.client())],
    child: const MaterialApp(
      home: Column(
        children: [
          Material(child: SchoolbookModuleSummary()),
          Expanded(child: SchoolbookSettingsScreen()),
        ],
      ),
    ),
  ));
  await settle(tester);
}

Future<Map<String, dynamic>> _saved() async => jsonDecode(
      (await SharedPreferences.getInstance()).getString(schoolbookSettingsPrefsKey) ?? '{}',
    ) as Map<String, dynamic>;

void main() {
  testWidgets('연결된 학교 이름이 보인다', (tester) async {
    await _pump(tester);
    expect(find.text('옛학교'), findsNWidgets(2)); // 요약 + 화면
  });

  testWidgets('연결을 끊으면 요약이 안내로 바뀌고 연결 화면이 뜬다', (tester) async {
    await _pump(tester, password: '1234');
    await tester.tap(find.byKey(SchoolbookSettingsScreen.disconnectKey));
    await settle(tester);
    expect(find.text(SchoolbookStrings.summaryNotConnected), findsOneWidget);
    expect(find.byType(SchoolbookConnectView), findsOneWidget);
    expect(await const FlutterSecureStorage().read(key: 'schoolbook_password_v1'), isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('예약자 이름을 고친다', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byKey(SchoolbookSettingsScreen.bookerKey), '체육전담');
    await tester.pump();
    await tester.tap(find.byKey(SchoolbookSettingsScreen.saveBookerKey));
    await settle(tester);
    expect((await _saved())['booker'], '체육전담');
  });

  testWidgets('예약자 이름은 바뀌었을 때만 저장할 수 있고, 저장하면 알린다', (tester) async {
    await _pump(tester);
    TextButton save() =>
        tester.widget<TextButton>(find.byKey(SchoolbookSettingsScreen.saveBookerKey));
    expect(save().onPressed, isNull, reason: '저장값(5-1) 그대로면 꺼져 있다');
    await tester.enterText(find.byKey(SchoolbookSettingsScreen.bookerKey), '체육전담');
    await tester.pump();
    expect(save().onPressed, isNotNull);
    await tester.tap(find.byKey(SchoolbookSettingsScreen.saveBookerKey));
    await settle(tester);
    expect(find.text(SchoolbookStrings.bookerSaved), findsOneWidget);
    expect((await _saved())['booker'], '체육전담');
    expect(save().onPressed, isNull, reason: '저장한 뒤에는 다시 꺼진다');
  });

  testWidgets('저장한 비밀번호는 가려져 있다가 [보기]를 누르면 보인다', (tester) async {
    await _pump(tester, password: '4821');
    expect(find.text('4821'), findsNothing);
    expect(find.text('••••'), findsOneWidget);
    await tester.tap(find.byKey(SchoolbookSettingsScreen.revealPasswordKey));
    await tester.pumpAndSettle();
    expect(find.text('4821'), findsOneWidget);
    await tester.tap(find.byKey(SchoolbookSettingsScreen.revealPasswordKey));
    await tester.pumpAndSettle();
    expect(find.text('4821'), findsNothing);
  });

  testWidgets('저장한 비밀번호가 없으면 확인 줄이 없다', (tester) async {
    await _pump(tester);
    expect(find.byKey(SchoolbookSettingsScreen.revealPasswordKey), findsNothing);
  });

  testWidgets('예약 비밀번호를 저장하고 지운다', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byKey(SchoolbookSettingsScreen.passwordKey), '4321');
    await tester.pump();
    await tester.tap(find.byKey(SchoolbookSettingsScreen.savePasswordKey));
    await settle(tester);
    expect(await const FlutterSecureStorage().read(key: 'schoolbook_password_v1'), '4321');
    expect(find.text(SchoolbookStrings.passwordSaved), findsOneWidget);

    await tester.tap(find.byKey(SchoolbookSettingsScreen.clearPasswordKey));
    await settle(tester);
    expect(await const FlutterSecureStorage().read(key: 'schoolbook_password_v1'), isNull);
  });

  testWidgets('학교 링크를 바꾸면 새 학교로 연결하고 마지막 교실을 비운다', (tester) async {
    await _pump(tester);
    await tester.tap(find.text(SchoolbookStrings.changeLink));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(SchoolbookConnectView.fieldKey),
      'https://schoolbook.zzolab.com/$_otherCode',
    );
    await tester.tap(find.byKey(SchoolbookConnectView.connectKey));
    await settle(tester);
    final saved = await _saved();
    expect(saved['code'], _otherCode);
    expect(saved['schoolName'], '플랜테스트');
    expect(saved['lastRoomId'], isNull);
    expect(find.byType(SchoolbookConnectView), findsNothing);
  });
}
