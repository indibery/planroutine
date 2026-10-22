import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/schoolbook/domain/schoolbook_link.dart';
import 'package:planroutine/features/schoolbook/presentation/providers/schoolbook_providers.dart';
import 'package:planroutine/features/schoolbook/presentation/screens/schoolbook_screen.dart';
import 'package:planroutine/features/schoolbook/presentation/screens/schoolbook_settings_screen.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/schoolbook_credit_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_server.dart';
import 'schoolbook_screen_harness.dart';

// 스쿨북 안내 · 사이트 링크 · 제작자 감사(사용자 결정 2026-10-23, 호칭 `CODER 승쨩`).

Future<List<String>> _pumpWith(WidgetTester tester, Widget home, {bool fail = false}) async {
  final opened = <String>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      schoolbookApiClientProvider.overrideWithValue(FakeSchoolbook({}).client()),
      schoolbookUrlOpenerProvider.overrideWithValue((url) async {
        opened.add(url);
        if (fail) throw Exception('열기 실패');
      }),
    ],
    child: MaterialApp(home: home),
  ));
  await settle(tester);
  return opened;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('사이트 주소와 학교 주소', () {
    expect(schoolbookSiteUrl, 'https://schoolbook.zzolab.com');
    expect(schoolbookSchoolUrl('abc'), 'https://schoolbook.zzolab.com/abc');
  });

  group('연결 화면', () {
    testWidgets('스쿨북 소개와 제작자를 보여 주고 사이트를 연다', (tester) async {
      final opened = await _pumpWith(tester, const SchoolbookScreen());
      expect(find.text(SchoolbookStrings.intro), findsOneWidget);
      expect(SchoolbookStrings.intro, contains('CODER 승쨩'));
      await tester.tap(find.text(SchoolbookStrings.openSite));
      await tester.pump();
      expect(opened, [schoolbookSiteUrl]);
    });

    testWidgets('학교가 아직 안 쓰면 가입 길을 알려 준다', (tester) async {
      final opened = await _pumpWith(tester, const SchoolbookScreen());
      expect(find.text(SchoolbookStrings.joinPrompt), findsOneWidget);
      await tester.ensureVisible(find.text(SchoolbookStrings.joinAction));
      await tester.tap(find.text(SchoolbookStrings.joinAction));
      await tester.pump();
      expect(opened, [schoolbookSiteUrl]);
    });

    testWidgets('열지 못하면 알린다', (tester) async {
      await _pumpWith(tester, const SchoolbookScreen(), fail: true);
      await tester.tap(find.text(SchoolbookStrings.openSite));
      await tester.pump();
      expect(find.text(SchoolbookStrings.openFailed), findsOneWidget);
    });
  });

  testWidgets('상세 설정의 웹에서 열기는 연결한 학교 링크를 연다', (tester) async {
    SharedPreferences.setMockInitialValues({
      schoolbookSettingsPrefsKey: jsonEncode({'code': testCode, 'schoolName': '플랜테스트'}),
    });
    final opened = await _pumpWith(tester, const SchoolbookSettingsScreen());
    await tester.ensureVisible(find.byKey(SchoolbookSettingsScreen.openWebKey));
    await tester.tap(find.byKey(SchoolbookSettingsScreen.openWebKey));
    await tester.pump();
    expect(opened, [schoolbookSchoolUrl(testCode)]);
  });

  group('설정 › 함께 만든 서비스', () {
    testWidgets('행에 서비스와 제작자가 보이고, 누르면 감사 시트가 열린다', (tester) async {
      final opened = await _pumpWith(
        tester,
        const Scaffold(body: SchoolbookCreditTile()),
      );
      expect(find.text(SchoolbookStrings.creditTitle), findsOneWidget);
      expect(find.text(SchoolbookStrings.creditSubtitle), findsOneWidget);

      await tester.tap(find.text(SchoolbookStrings.creditTitle));
      await tester.pumpAndSettle();
      expect(find.text(SchoolbookStrings.creditThanks), findsOneWidget);
      expect(SchoolbookStrings.creditThanks, contains('CODER 승쨩'));
      expect(find.text(SchoolbookStrings.creditMaker), findsOneWidget);
      expect(find.text(SchoolbookStrings.creditContact), findsOneWidget);

      await tester.tap(find.byKey(SchoolbookCreditTile.openSiteKey));
      await tester.pump();
      expect(opened, [schoolbookSiteUrl]);
    });
  });
}
