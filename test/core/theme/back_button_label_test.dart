import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/theme/app_theme.dart';

/// AppBar 뒤로 가기 버튼의 이름이 **아이콘에** 있어야 한다.
///
/// Flutter 기본 `BackButton`은 이름을 말풍선(`tooltip`, `뒤로`)으로만 준다. `snapshot_ui`는
/// 그것을 읽지만 mobile MCP는 읽지 않아, push로 연 화면마다 뒤로 가기가 이름 없는
/// `Button`으로 나왔다(2026-10-04 실측). 화면마다 `leading`을 바꾸지 않고 테마의
/// `actionIconTheme` 한 곳에서 아이콘에 이름을 붙인다.
void main() {
  Future<void> pumpPushed(
    WidgetTester tester, {
    bool fullscreen = false,
  }) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        theme: AppTheme.of(Brightness.light),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ko', 'KR')],
        locale: const Locale('ko', 'KR'),
        home: const Scaffold(body: Text('첫 화면')),
      ),
    );
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        fullscreenDialog: fullscreen,
        builder: (_) => Scaffold(appBar: AppBar(title: const Text('휴지통'))),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('iOS에서도 뒤로 가기 아이콘이 현지화된 이름을 가진다', (tester) async {
    // Flutter 기본값은 **Android에서만** 아이콘에 이름을 주고 iOS는 tooltip뿐이다
    // (`action_buttons.dart`). `flutter test`는 플랫폼을 android로 강제하므로 iOS로 바꿔야
    // 그 차이가 보인다 — 바꾸지 않으면 고치기 전에도 통과한다(실제로 그랬다).
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await pumpPushed(tester);

    final context = tester.element(find.byType(BackButton));
    final icon = tester.widget<Icon>(
      find.descendant(of: find.byType(BackButton), matching: find.byType(Icon)),
    );
    expect(
      icon.semanticLabel,
      MaterialLocalizations.of(context).backButtonTooltip,
    );
    expect(icon.semanticLabel, '뒤로');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('아이콘 모양은 플랫폼 기본값을 따른다', (tester) async {
    await pumpPushed(tester);

    // 테스트는 macOS 호스트에서 돈다(`Platform.isAndroid` false) → iOS 모양.
    final icon = tester.widget<Icon>(
      find.descendant(of: find.byType(BackButton), matching: find.byType(Icon)),
    );
    expect(icon.icon, Icons.arrow_back_ios_new_rounded);
  });

  testWidgets('iOS에서도 전체 화면 창의 닫기(X) 아이콘이 현지화된 이름을 가진다', (tester) async {
    // 사진 전체 보기·녹음 화면이 `fullscreenDialog`라 AppBar가 뒤로 가기 대신 닫기 버튼을 쓴다.
    // 이름이 tooltip에만 있으면 mobile MCP가 이름 없는 버튼으로 읽는다(verifier 2026-10-04).
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await pumpPushed(tester, fullscreen: true);

    final context = tester.element(find.byType(CloseButton));
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(CloseButton),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.icon, Icons.close);
    expect(
      icon.semanticLabel,
      MaterialLocalizations.of(context).closeButtonTooltip,
    );
    debugDefaultTargetPlatformOverride = null;
  });
}
