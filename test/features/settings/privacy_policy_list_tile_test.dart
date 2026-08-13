import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/settings/presentation/widgets/privacy_policy_list_tile.dart';

void main() {
  testWidgets('방침 행이 보이고 탭하면 URL을 연다', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivacyPolicyListTile(onOpen: (url) async => opened.add(url)),
        ),
      ),
    );

    expect(find.text(SettingsStrings.privacyPolicyTitle), findsOneWidget);

    await tester.tap(find.text(SettingsStrings.privacyPolicyTitle));
    await tester.pumpAndSettle();
    expect(opened, [SettingsStrings.privacyPolicyUrl]);
  });

  testWidgets('열기에 실패하면 스낵바로 알린다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivacyPolicyListTile(
            onOpen: (_) async => throw Exception('no browser'),
          ),
        ),
      ),
    );

    await tester.tap(find.text(SettingsStrings.privacyPolicyTitle));
    await tester.pumpAndSettle();
    expect(find.text(SettingsStrings.privacyPolicyFailed), findsOneWidget);
  });
}
