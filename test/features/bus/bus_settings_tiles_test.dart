import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/core/modules/app_module.dart';
import 'package:planroutine/core/theme/app_theme.dart';
import 'package:planroutine/features/bus/presentation/providers/bus_providers.dart';
import 'package:planroutine/features/settings/presentation/screens/modules_screen.dart';
import 'package:planroutine/features/settings/presentation/widgets/bus_settings_tiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(home: Scaffold(body: BusSettingsTiles())),
    ),
  );
  await tester.pumpAndSettle();
}

/// 팔레트와 전역 `switchTheme`을 실제로 적용한 채 **기능 관리**를 띄운다 — 색 검증 전용.
///
/// 버스를 켜는 스위치는 이제 기능 관리 행에 하나뿐이다. 그 스위치가 이 기능 전체를
/// 켜는 유일한 관문이라 색 가드(I12)도 그리로 옮긴다.
Future<void> _pumpModulesThemed(
  WidgetTester tester,
  Brightness brightness,
) async {
  AppColors.applyBrightness(brightness);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.of(brightness),
        home: const ModulesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('상세에는 켜짐 스위치가 없고 다섯 줄이 처음부터 보인다', (tester) async {
    // 상세 화면은 기능이 켜져 있을 때만 들어온다(기능 관리 행의 ›). 그래서 여기서
    // 다시 켜고 끌 이유가 없고, 줄을 감출 이유도 없다.
    await _pump(tester);

    expect(find.byType(Switch), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byKey(BusSettingsTiles.departureKey), findsOneWidget);
    expect(find.byKey(BusSettingsTiles.arrivalKey), findsOneWidget);
    expect(find.byKey(BusSettingsTiles.styleKey), findsOneWidget);
    expect(find.byKey(BusSettingsTiles.rangeToWorkKey), findsOneWidget);
    // 다섯째 줄도 검사한다 — 빠뜨리면 _rangeTile이 조건부로 새도 통과한다.
    expect(find.byKey(BusSettingsTiles.rangeToHomeKey), findsOneWidget);
  });

  testWidgets('켜짐 안내 문구가 없다 — 켜고 끄기는 기능 관리가 맡는다', (tester) async {
    await _pump(tester);

    expect(find.text('꺼져 있어 오늘 탭이 지금과 같습니다'), findsNothing);
    expect(find.text('지정한 시간대에만 펼쳐집니다'), findsNothing);
  });

  testWidgets('시간대 기본값이 라벨로 보인다', (tester) async {
    await _pump(tester);

    expect(find.text('07:00 – 08:30'), findsOneWidget);
    expect(find.text('16:00 – 18:00'), findsOneWidget);
  });

  testWidgets('슬롯이 비면 선택 안내가 보인다', (tester) async {
    await _pump(tester);
    expect(find.text('정류장 선택'), findsNWidgets(2));
  });

  group('버스 켜기 스위치(기능 관리) — 전역 switchTheme을 따른다 (I12)', () {
    // 팔레트는 전역이다 — 라이트로 바꾼 채 끝내면 뒤따르는 테스트가 오염된다.
    tearDown(() => AppColors.applyBrightness(Brightness.dark));

    for (final brightness in Brightness.values) {
      testWidgets('$brightness 에서 ON 썸이 트랙과 다른 색이다', (tester) async {
        await _pumpModulesThemed(tester, brightness);
        final finder = find.byKey(ModulesScreen.switchKey(ModuleIds.bus));
        await tester.tap(finder);
        await tester.pumpAndSettle();

        final sw = tester.widget<SwitchListTile>(finder);
        final theme = Theme.of(tester.element(finder));
        const selected = {WidgetState.selected};

        // Flutter의 해상 순서를 그대로 재현한다: 위젯의 `activeThumbColor`가
        // `switchTheme.thumbColor`를 밀어낸다(`switch.dart`의 `_widgetThumbColor`).
        final thumb =
            sw.activeThumbColor ??
            theme.switchTheme.thumbColor?.resolve(selected);
        final track =
            sw.activeTrackColor ??
            theme.switchTheme.trackColor?.resolve(selected);

        expect(thumb, isNotNull);
        expect(track, isNotNull);
        expect(
          thumb,
          isNot(track),
          reason:
              '썸과 트랙이 같은 색이면 ON이 썸 없는 단색 알약이 된다 — '
              'M3 스위치는 selected 그림자·외곽선이 없어 형태 단서도 없다',
        );
      });
    }

    testWidgets('켜면 실제로 켜진 상태로 그려진다', (tester) async {
      // 위 색 단정이 OFF 상태를 보고 통과하지 않도록 값 자체를 못박는다.
      await _pumpModulesThemed(tester, Brightness.dark);
      final finder = find.byKey(ModulesScreen.switchKey(ModuleIds.bus));
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(finder).value, isTrue);
    });
  });

  testWidgets('카드 모양 기본은 간단히이고 눌러 바꿀 수 있다', (tester) async {
    await _pump(tester);

    expect(find.text('간단히'), findsOneWidget);

    await tester.tap(find.text('시간 축'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BusSettingsTiles)),
    );
    expect(
      container.read(busSettingsProvider).requireValue.style.label,
      '시간 축',
    );
  });
}
