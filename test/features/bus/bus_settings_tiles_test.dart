import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/presentation/providers/bus_providers.dart';
import 'package:planroutine/features/settings/presentation/widgets/bus_settings_tiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(
    child: MaterialApp(home: Scaffold(body: BusSettingsTiles())),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('기본은 꺼짐이고 나머지 줄이 감춰져 있다', (tester) async {
    await _pump(tester);

    expect(find.byKey(BusSettingsTiles.switchKey), findsOneWidget);
    expect(find.text('꺼져 있어 오늘 탭이 지금과 같습니다'), findsOneWidget);

    expect(find.byKey(BusSettingsTiles.departureKey), findsNothing);
    expect(find.byKey(BusSettingsTiles.arrivalKey), findsNothing);
    expect(find.byKey(BusSettingsTiles.styleKey), findsNothing);
    expect(find.byKey(BusSettingsTiles.rangeToWorkKey), findsNothing);
    // 다섯째 줄도 검사한다 — 빠뜨리면 _rangeTile이 enabled 블록 밖으로 새도 통과한다.
    expect(find.byKey(BusSettingsTiles.rangeToHomeKey), findsNothing);
  });

  testWidgets('켜면 다섯 줄이 나타난다', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(BusSettingsTiles.switchKey));
    await tester.pumpAndSettle();

    expect(find.text('지정한 시간대에만 펼쳐집니다'), findsOneWidget);
    expect(find.byKey(BusSettingsTiles.departureKey), findsOneWidget);
    expect(find.byKey(BusSettingsTiles.arrivalKey), findsOneWidget);
    expect(find.byKey(BusSettingsTiles.styleKey), findsOneWidget);
    expect(find.byKey(BusSettingsTiles.rangeToWorkKey), findsOneWidget);
    expect(find.byKey(BusSettingsTiles.rangeToHomeKey), findsOneWidget);
  });

  testWidgets('시간대 기본값이 라벨로 보인다', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(BusSettingsTiles.switchKey));
    await tester.pumpAndSettle();

    expect(find.text('07:00 – 08:30'), findsOneWidget);
    expect(find.text('16:00 – 18:00'), findsOneWidget);
  });

  testWidgets('슬롯이 비면 선택 안내가 보인다', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(BusSettingsTiles.switchKey));
    await tester.pumpAndSettle();
    expect(find.text('정류장 선택'), findsNWidgets(2));
  });

  testWidgets('카드 모양 기본은 간단히이고 눌러 바꿀 수 있다', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(BusSettingsTiles.switchKey));
    await tester.pumpAndSettle();

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
