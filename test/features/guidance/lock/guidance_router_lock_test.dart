import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/core/router/app_router.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/presentation/lock/device_authenticator.dart';
import 'package:planroutine/features/guidance/presentation/lock/guidance_lock_gate.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';

import '../../../helpers/test_database.dart';

class _FakeAuth implements DeviceAuthenticator {
  var calls = 0;
  @override
  Future<AuthOutcome> authenticate(String reason) async {
    calls++;
    return AuthOutcome.failed;
  }
}

/// 실제 `createRouter`의 지도 기록 셸 배선 — 열린 경로는 묻지 않고, 예전 기록 경로는 덮개 + 인증.
void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late _FakeAuth auth;
  late GoRouter router;

  setUp(() {
    db = freshDatabaseHelper();
    auth = _FakeAuth();
  });
  tearDown(() async => db.close());

  Future<void> pump(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    router = createRouter(onboardingDone: true, initialLocation: location);
    final container = ProviderContainer(
      overrides: [
        guidanceRepositoryProvider.overrideWithValue(GuidanceRepository(dbHelper: db)),
        deviceAuthenticatorProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 30));
    }
  }

  testWidgets('목록 — 인증 0회, 덮개 없음', (tester) async {
    await pump(tester, AppRoutes.guidance);
    expect(auth.calls, 0);
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
  });

  testWidgets('새 기록(녹음 버튼) — 인증 0회', (tester) async {
    await pump(tester, AppRoutes.guidanceNewRecording);
    expect(auth.calls, 0);
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
  });

  testWidgets('예전 기록의 쓰기 경로(되살리기) — 덮개 + 인증 1회, 뒤로는 목록', (tester) async {
    await pump(tester, AppRoutes.guidanceEdit(1));
    expect(auth.calls, 1);
    expect(find.byKey(GuidanceLockGate.coverKey), findsOneWidget);

    await tester.tap(find.byKey(GuidanceLockGate.backKey));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutes.guidance,
    );
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
  });
}
