// 시스템 바 스타일 — **Android 15+ edge-to-edge에서 내비게이션 바 버튼이 보여야 한다.**
//
// targetSdk 36이라 Android 15(API 35)부터 edge-to-edge가 강제되고, 그 모드에서는
// `systemNavigationBarColor`가 **무시된다**(`system_chrome.dart:722` 문서 주석).
// 그때까지 이 앱은 `SystemUiOverlayStyle.dark`/`.light`를 그대로 썼는데, 그 두 상수는
// **양쪽 다** `systemNavigationBarIconBrightness: Brightness.light`(흰 아이콘) +
// `systemNavigationBarColor: 검정`을 담고 있다(`system_chrome.dart:316-330`).
// 검정 바가 사라지자 흰 아이콘만 남았다.
//
// Android 16(API 36) 에뮬레이터 실측(2026-09-03):
//   3버튼·라이트 — 스트립 #FFFFFF + 버튼 #FFFFFF → **1.00:1, 통째로 안 보인다**
//   3버튼·다크   — 스트립 #D0D4DA + 버튼 #FFFFFF → **1.49:1, 거의 안 보인다**
//   제스처       — 핸들은 SystemUI가 뒤 화면을 샘플링해 자동 대비 → 양 테마 정상
// 제스처에서만 멀쩡했던 것이 이 결함이 오래 숨은 이유다.
//
// 다크의 #D0D4DA는 3버튼에 기본으로 깔리는 **80% 스크림**이다
// (`navigationBarContrastEnforced` 기본값 true). 그래서 아이콘 밝기만 뒤집으면
// 부족하다 — 스크림까지 꺼서 **내비게이션 바 영역이 탭바 색 그대로**가 되게 하고,
// 아이콘을 그 색과 대비시킨다. 그러면 API 24~36이 한 규칙으로 통일된다.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/app.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/core/theme/app_theme.dart';
import 'package:planroutine/core/theme/system_overlay_region.dart';

import '../../helpers/contrast.dart';

/// 아이콘 밝기가 실제로 그려지는 색 — **실측값이다.**
///
/// 순수 흑백으로 모델링하면 라이트에서 가드가 **3.7배 낙관적**이 된다
/// (검정 on 흰색 = 21.00:1인데 실제는 5.74:1). Android는 두 방향을 다르게 그린다:
/// 밝은 아이콘은 **불투명 흰색**, 어두운 아이콘은 **60% 검정**이다.
///
/// Android 16 에뮬레이터 실측(2026-09-03)과 계산이 소수점까지 맞는다:
///   라이트 — 어두운 아이콘이 흰 탭바 위에 `#666666`으로 그려져 **5.74:1**
///            (`alphaBlend(black 60%, #FFFFFF)` = `#666666`)
///   다크   — 밝은 아이콘이 네이비(`#142847`) 위에 `#FFFFFF`로 **14.74:1**
///
/// 그래서 라이트의 실제 여유는 4.5:1 위로 **1.28배뿐이다.** 탭바 `surface`를
/// 조금이라도 어둡게 옮기면 `#B4B4B4` 부근에서 AA가 깨지는데, 순수 검정 모델은
/// `#787878`까지도 통과시켜 그 순간을 놓친다 — 이 결함이 제스처 모드에서만
/// 멀쩡해 오래 숨었던 것과 같은 부류의 재발이다.
Color _iconColor(Brightness b) =>
    b == Brightness.light ? Colors.white : Colors.black.withValues(alpha: 0.6);

/// 내비게이션 바 영역에 실제로 깔리는 색 = 탭바 배경 = `AppColors.surface`
/// (`FloatingTabBar`가 `Container(color: surface) > SafeArea(top:false)`로
/// 인셋 영역까지 칠한다).
void _expectNavIconsReadable(SystemUiOverlayStyle style, String theme) {
  final iconBrightness = style.systemNavigationBarIconBrightness;
  expect(
    iconBrightness,
    isNotNull,
    reason: '$theme — 내비게이션 바 아이콘 밝기를 지정하지 않으면 플랫폼 기본값(흰 아이콘)이 남는다',
  );
  final ratio = contrastRatio(_iconColor(iconBrightness!), AppColors.surface);
  expect(
    ratio,
    greaterThanOrEqualTo(4.5),
    reason:
        '$theme — 내비게이션 바 아이콘이 탭바 색과 ${ratio.toStringAsFixed(2)}:1 이다. '
        'edge-to-edge에서는 이 영역에 탭바 색이 그대로 보이므로 '
        '아이콘 밝기를 그 색의 반대로 둬야 한다',
  );
}

/// `SystemChrome.latestStyle`는 전역 static이고, 화면에 annotated region이
/// **하나도 없으면** 프레임워크(`view.dart:443`)가 조용히 이전 값을 유지한다.
/// 그래서 먼저 틀린 값으로 오염시켜 두지 않으면 배선이 빠져도 통과한다.
Future<void> poisonStyle(WidgetTester tester) async {
  await tester.pumpWidget(
    const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: true,
      ),
      child: SizedBox.expand(),
    ),
  );
  await tester.pump();
  expect(
    SystemChrome.latestStyle?.systemNavigationBarIconBrightness,
    Brightness.light,
    reason: '오염 단계가 실패하면 이어지는 검사가 무의미하다',
  );
}

void main() {
  group('AppTheme.systemOverlayStyle', () {
    test('라이트 — 내비게이션 바 아이콘이 탭바 색과 대비된다', () {
      AppColors.applyBrightness(Brightness.light);
      _expectNavIconsReadable(
        AppTheme.systemOverlayStyle(Brightness.light),
        '라이트',
      );
    });

    test('다크 — 내비게이션 바 아이콘이 탭바 색과 대비된다', () {
      AppColors.applyBrightness(Brightness.dark);
      _expectNavIconsReadable(
        AppTheme.systemOverlayStyle(Brightness.dark),
        '다크',
      );
    });

    test('내비게이션 바 스크림을 끈다 — 켜지면 탭바 색 가정이 깨진다', () {
      for (final brightness in Brightness.values) {
        expect(
          AppTheme.systemOverlayStyle(
            brightness,
          ).systemNavigationBarContrastEnforced,
          isFalse,
          reason:
              '$brightness — 3버튼 내비게이션에는 80% 스크림이 기본으로 깔린다. '
              '켜두면 내비게이션 바 영역이 탭바 색이 아니게 되어 '
              '위 대비 계산의 전제가 무너진다(실측 다크 #D0D4DA)',
        );
      }
    });

    test('내비게이션 바 색은 투명이다 — 구버전에 검정 바가 남으면 어두운 아이콘이 안 보인다', () {
      for (final brightness in Brightness.values) {
        expect(
          AppTheme.systemOverlayStyle(brightness).systemNavigationBarColor,
          Colors.transparent,
          reason:
              '$brightness — API 35+는 이 값을 무시하지만 minSdk 24라 '
              'Android 7~14에서는 아직 칠해진다. 검정으로 두면 라이트 테마의 '
              '어두운 아이콘이 검정 바 위에 놓여 구버전이 깨진다',
        );
      }
    });

    test('상태바 아이콘 밝기는 기존 동작 그대로다', () {
      // 상태바는 실측에서 양 테마 모두 정상이었다. 내비게이션 바를 고치면서
      // 같이 뒤집히지 않게 잠근다.
      expect(
        AppTheme.systemOverlayStyle(Brightness.light).statusBarIconBrightness,
        Brightness.dark,
        reason: '라이트 배경 위에는 어두운 상태바 아이콘',
      );
      expect(
        AppTheme.systemOverlayStyle(Brightness.dark).statusBarIconBrightness,
        Brightness.light,
        reason: '다크 배경 위에는 밝은 상태바 아이콘',
      );
    });

    test('AppBar 테마가 같은 함수를 쓴다 — 두 곳에 값을 박으면 어긋난다', () {
      for (final brightness in Brightness.values) {
        AppColors.applyBrightness(brightness);
        expect(
          AppTheme.of(brightness).appBarTheme.systemOverlayStyle,
          AppTheme.systemOverlayStyle(brightness),
          reason: '$brightness — AppBarTheme의 스타일이 단일 출처에서 나와야 한다',
        );
      }
    });
  });

  group('SystemOverlayRegion', () {
    /// 프로덕션과 같은 조립 — `app.dart`가 `MaterialApp`의 `builder`에서 감싼다.
    Widget app(Brightness brightness, {required Widget home}) => MaterialApp(
      theme: AppTheme.of(brightness),
      builder: (context, child) =>
          SystemOverlayRegion(brightness: brightness, child: child!),
      home: home,
    );

    testWidgets('AppBar가 없는 화면도 내비게이션 바 스타일을 받는다', (tester) async {
      // 온보딩이 이 경우다 — AppBar가 없어 annotated region이 한 곳도 없었다.
      AppColors.applyBrightness(Brightness.light);
      await poisonStyle(tester);

      await tester.pumpWidget(
        app(
          Brightness.light,
          home: Scaffold(
            backgroundColor: AppColors.background,
            body: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();

      _expectNavIconsReadable(SystemChrome.latestStyle!, '라이트(AppBar 없음)');
    });

    testWidgets('AppBar가 있으면 상태바는 AppBar, 내비게이션 바는 루트 리전에서 온다', (
      tester,
    ) async {
      // 프레임워크는 위/아래 리전을 따로 샘플링한다(`view.dart:452`). 아래 리전이
      // 없던 동안 **AppBar 하나가 내비게이션 바 색까지 정하고 있었다** —
      // 그것이 이 결함의 뿌리다.
      //
      // ⚠️ **두 리전에 서로 다른 밝기를 준다.** 같은 밝기를 주면
      // `appBarTheme.systemOverlayStyle`이 같은 함수를 쓰므로 위·아래 값이
      // 동일해지고, 루트 리전을 지워도 `view.dart:466`의 폴백이 같은 값을 채워
      // **이 테스트가 자기 제목을 관찰하지 못한다**(실증: `builder:`를 지워도 green).
      // 밝기를 어긋나게 두면 각 속성이 어느 리전에서 왔는지가 값으로 갈린다.
      AppColors.applyBrightness(Brightness.dark);
      await poisonStyle(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.of(Brightness.dark), // AppBar → 밝은 상태바 아이콘
          builder: (context, child) => SystemOverlayRegion(
            brightness: Brightness.light, // 루트 → 어두운 내비게이션 아이콘
            child: child!,
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('제목')),
            body: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();

      final style = SystemChrome.latestStyle!;
      expect(
        style.statusBarIconBrightness,
        Brightness.light,
        reason: '상태바는 **AppBar**(다크 테마)에서 와야 한다',
      );
      expect(
        style.systemNavigationBarIconBrightness,
        Brightness.dark,
        reason:
            '내비게이션 바는 **루트 리전**(라이트)에서 와야 한다. '
            'Brightness.light가 나오면 AppBar 값이 아래까지 채운 것이고, '
            '곧 루트 리전이 없다는 뜻이다',
      );
      expect(
        style.systemNavigationBarContrastEnforced,
        isFalse,
        reason: '스크림 해제가 루트 리전에서 실제로 플랫폼까지 도달해야 한다',
      );
    });
  });

  testWidgets('실제 앱이 루트 리전을 심는다 — 위 조립은 흉내였다', (tester) async {
    // 위 두 위젯 테스트는 프로덕션 **조립을 흉내낸다**. 실제 `PlanRoutineApp`이
    // 그렇게 조립하는지는 앱을 띄워야 알 수 있다.
    //
    // 예전에는 `lib/app.dart`에 `SystemOverlayRegion` 문자열이 있는지 grep했다.
    // 그 방식은 이 리포가 네 번 밟은 함정이다 — **스캐너는 언급과 사용을 구별하지
    // 못한다.** 더 중요한 것은 **자리를 못 본다**: 리전을 `builder`에서 `home`
    // 안이나 라우트 하위로 옮기면 grep은 계속 통과하는데 AppBar 없는 화면
    // (온보딩)이 다시 새어나간다 — 그것이 이 결함의 원래 모습이었다.
    // ⚠️ **온보딩으로 띄워야 한다.** 기본 라우트(`/today`)에는 `AppBar`가 있고,
    // 아래 리전이 없으면 프레임워크가 편의상 위쪽(AppBar) 값으로 내비게이션 바
    // 속성까지 채운다(`view.dart:466`) — `appBarTheme`도 같은 함수를 쓰므로
    // **루트 리전을 빼도 값이 똑같아 통과한다**(실측: 배선을 지우고도 green).
    // `AppBar`가 없는 화면만이 루트 리전의 존재를 증명한다.
    SharedPreferences.setMockInitialValues({});
    AppColors.applyBrightness(Brightness.light);
    await poisonStyle(tester);

    await tester.pumpWidget(
      const ProviderScope(child: PlanRoutineApp(onboardingDone: false)),
    );
    await tester.pumpAndSettle();

    final style = SystemChrome.latestStyle;
    expect(
      style?.systemNavigationBarContrastEnforced,
      isFalse,
      reason:
          '실제 앱에서 내비게이션 바 스타일이 플랫폼까지 도달하지 않았다 — '
          '`MaterialApp`의 `builder`에 `SystemOverlayRegion`이 있는지 확인할 것',
    );
    expect(
      style?.systemNavigationBarColor,
      Colors.transparent,
      reason: '루트 리전이 아니라 AppBar의 리전만 잡히고 있다',
    );
  });
}
