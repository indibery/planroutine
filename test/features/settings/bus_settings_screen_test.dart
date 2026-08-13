import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/settings/presentation/screens/bus_settings_screen.dart';
import 'package:planroutine/features/settings/presentation/widgets/bus_settings_tiles.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: BusSettingsScreen())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('화면이 설정 타일을 담는다', (tester) async {
    await pump(tester);

    expect(find.byType(BusSettingsTiles), findsOneWidget);
    expect(find.byKey(BusSettingsTiles.switchKey), findsOneWidget);
  });

  testWidgets('섹션 부제였던 기능 설명이 화면 안에 남아 있다', (tester) async {
    // 설정 탭에서 섹션을 요약 한 줄로 줄이면서 잃을 뻔한 문장이다 —
    // 처음 쓰는 사람에게 이 한 줄이 기능 소개다.
    await pump(tester);

    expect(find.text(BusStrings.sectionDescription), findsOneWidget);
  });

  testWidgets('제목이 버스 도착이다', (tester) async {
    await pump(tester);

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(BusStrings.section),
      ),
      findsOneWidget,
    );
  });
}
