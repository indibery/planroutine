import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/modules/app_module.dart';
import 'package:planroutine/core/modules/installed_modules_provider.dart';
import 'package:planroutine/core/modules/installed_today_cards.dart';
import 'package:planroutine/core/modules/module_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/module_prefs.dart';

const _cardA = AppModule(
  id: 'a',
  name: 'a',
  icon: Icons.circle,
  placement: ModulePlacement.todayCard,
  card: Text('카드A'),
);
const _cardB = AppModule(
  id: 'b',
  name: 'b',
  icon: Icons.circle,
  placement: ModulePlacement.todayCard,
  card: Text('카드B'),
);

Future<void> _pump(WidgetTester tester) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      moduleCatalogProvider.overrideWithValue([
        ...moduleCatalog.where((m) => m.fixed),
        _cardA,
        _cardB,
      ]),
    ],
    child: const MaterialApp(home: Scaffold(body: InstalledTodayCards())),
  ),
);

void main() {
  testWidgets('로딩 중에는 카드가 없다', (tester) async {
    SharedPreferences.setMockInitialValues(modulePrefs(installed: ['a']));
    await _pump(tester);
    expect(find.text('카드A'), findsNothing);
  });

  testWidgets('켠 카드만 켠 순서대로 그린다', (tester) async {
    SharedPreferences.setMockInitialValues(modulePrefs(installed: ['b', 'a']));
    await _pump(tester);
    await tester.pumpAndSettle();
    final b = tester.getTopLeft(find.text('카드B')).dy;
    final a = tester.getTopLeft(find.text('카드A')).dy;
    expect(b, lessThan(a));
  });

  testWidgets('아무것도 켜지 않았으면 카드가 없다', (tester) async {
    SharedPreferences.setMockInitialValues(modulePrefs());
    await _pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('카드A'), findsNothing);
    expect(find.text('카드B'), findsNothing);
  });
}
