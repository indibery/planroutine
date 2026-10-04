import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/settings/presentation/screens/bus_settings_screen.dart';
import 'package:planroutine/features/settings/presentation/screens/settings_screen.dart';

import '../../helpers/text_glyph.dart';

/// 한 화면 안의 행 제목은 같은 세로선에서 시작한다(2026-10-04 디자인 점검).
///
/// `이미 찍은 도장 흐리게`는 아이콘이 없어 바로 위 `도장 모양`보다 왼쪽으로 붙었고, 알림의
/// `고급`은 혼자 더 들어가 있었고, 버스 설정의 `카드 모양`은 ListTile이 아니라 다른 여백을
/// 썼다. 캡처를 나란히 놓고 봐야 보이는 어긋남이라 측정으로 묶는다.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: '공직플랜',
      packageName: 'com.planroutine.app',
      version: '1.4.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(402, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: screen)));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('설정: 도장 흐리게·고급 행 제목이 위 행 제목과 같은 선에서 시작한다', (tester) async {
    await pump(tester, const SettingsScreen());
    final stampStart = glyphLeftX(
      tester,
      find.text(SettingsStrings.stampStyleLabel),
    );
    expect(
      glyphLeftX(tester, find.text(SettingsStrings.stampDimLabel)),
      moreOrLessEquals(stampStart, epsilon: 0.5),
    );
    expect(
      glyphLeftX(tester, find.text(NotificationStrings.advanced)),
      moreOrLessEquals(
        glyphLeftX(tester, find.text(NotificationStrings.master)),
        epsilon: 0.5,
      ),
    );
  });

  testWidgets('버스 설정: 카드 모양 행 제목이 정류장 행 제목과 같은 선에서 시작한다', (tester) async {
    await pump(tester, const BusSettingsScreen());
    expect(
      glyphLeftX(tester, find.text(BusStrings.cardStyle)),
      moreOrLessEquals(
        glyphLeftX(tester, find.text(BusStrings.slotDeparture)),
        epsilon: 0.5,
      ),
    );
  });

  // 결정 1(행 부제 14)의 회귀는 "행마다 12를 다시 붙이는 것"이다. 테마 테스트는 스타일 없는
  // ListTile만 보므로 실제 화면을 띄워 잰다(verifier가 짚었다, 2026-10-04).
  testWidgets('설정: 행 부제는 모두 14pt다', (tester) async {
    await pump(tester, const SettingsScreen());
    for (final text in [
      SettingsStrings.exportDescription,
      SettingsStrings.trashDescription,
      SettingsStrings.stampDimDescription,
    ]) {
      expect(textStyleOf(tester, find.text(text))?.fontSize, 14, reason: text);
    }
  });

  testWidgets('버스 설정: 행 부제는 14pt다', (tester) async {
    await pump(tester, const BusSettingsScreen());
    expect(textStyleOf(tester, find.text(BusStrings.cardStyleHint))?.fontSize, 14);
  });
}
