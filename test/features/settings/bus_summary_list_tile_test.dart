import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/router/app_router.dart';
import 'package:planroutine/features/settings/presentation/widgets/bus_summary_list_tile.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 요약 타일만 띄우고, push 대상 라우트에는 표식 위젯을 둔다.
  Future<void> pump(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: BusSummaryListTile()),
        ),
        GoRoute(
          path: AppRoutes.busSettings,
          builder: (_, _) => const Scaffold(body: Text('버스설정화면')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('기본은 꺼짐으로 보인다', (tester) async {
    await pump(tester);

    expect(find.text(BusStrings.section), findsOneWidget);
    expect(find.text(BusStrings.summaryOff), findsOneWidget);
  });

  testWidgets('누르면 버스 설정 화면으로 간다', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(BusSummaryListTile.tileKey));
    await tester.pumpAndSettle();

    expect(find.text('버스설정화면'), findsOneWidget);
  });
}
