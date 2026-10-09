import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/bus/domain/bus_settings.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';
import 'package:planroutine/features/bus/presentation/providers/bus_providers.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_module_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/module_prefs.dart';

const _stop = BusStop(
  nodeId: 'GGB201000156',
  nodeNm: '서울역버스환승센터',
  nodeNo: '2004',
  cityCode: 0,
);

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(home: Scaffold(body: BusModuleSummary())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('정류장이 없으면 등록 안내가 보인다', (tester) async {
    SharedPreferences.setMockInitialValues(modulePrefs());
    await _pump(tester);
    expect(find.text(BusStrings.summaryNoStop), findsOneWidget);
  });

  testWidgets('정류장을 등록해 두었으면 개수가 보인다', (tester) async {
    SharedPreferences.setMockInitialValues(
      modulePrefs(bus: BusSettings.defaults.copyWith(departure: _stop)),
    );
    await _pump(tester);
    expect(find.text(BusStrings.summaryStops(1)), findsOneWidget);
  });

  testWidgets('정류장이 바뀌면 요약도 바뀐다 — 상세에서 돌아왔을 때 옛 값이 남지 않는다', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(modulePrefs());
    await _pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BusModuleSummary)),
    );
    await container
        .read(busSettingsProvider.notifier)
        .setStop(CommuteDirection.toWork, _stop);
    await tester.pumpAndSettle();
    expect(find.text(BusStrings.summaryStops(1)), findsOneWidget);
  });
}
