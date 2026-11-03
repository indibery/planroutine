import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/core/router/app_router.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/domain/participant.dart';
import 'package:planroutine/features/guidance/presentation/lock/device_authenticator.dart';
import 'package:planroutine/features/guidance/presentation/lock/guidance_unlock.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_list_screen.dart';
import 'package:planroutine/features/guidance/presentation/widgets/guidance_record_tile.dart';

import '../../../helpers/test_database.dart';

class _FakeAuth implements DeviceAuthenticator {
  _FakeAuth(this.outcome);
  AuthOutcome outcome;
  var calls = 0;
  @override
  Future<AuthOutcome> authenticate(String reason) async {
    calls++;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return outcome;
  }
}

/// 잠긴 목록(스펙 "잠긴 목록") — 잠긴 동안 어디서도 이름이 보이거나 읽히지 않고,
/// 줄을 누르면 그 자리에서 인증한다.
void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late GuidanceRepository repo;
  late GuidanceUnlock unlock;
  late _FakeAuth auth;
  late List<String> pushed;
  var clock = DateTime(2026, 11, 3, 9);

  setUp(() {
    db = freshDatabaseHelper();
    repo = GuidanceRepository(dbHelper: db);
    clock = DateTime(2026, 11, 3, 9);
    unlock = GuidanceUnlock(clock: () => clock);
    auth = _FakeAuth(AuthOutcome.success);
    pushed = [];
  });
  tearDown(() async => db.close());

  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    await repo.create(
      GuidanceContent(
        title: '박서준 수업 방해',
        occurredAt: DateTime(2026, 10, 2, 15, 30),
        participants: const [
          Participant(name: '박서준'),
          Participant(name: '김하늘'),
        ],
      ),
    );
    await repo.create(
      GuidanceContent(
        title: '점심 다툼',
        kind: GuidanceKind.infringement,
        precision: OccurredPrecision.approx,
        occurredText: '점심 박서준 다툼',
        participants: const [Participant(name: '박서준')],
      ),
    );
  });

  Future<void> settle(WidgetTester tester) async {
    for (
      var i = 0;
      i < 40 && find.byType(GuidanceRecordTile).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: AppRoutes.guidance,
      routes: [
        GoRoute(
          path: AppRoutes.guidance,
          builder: (_, _) => const GuidanceListScreen(),
          routes: [
            GoRoute(
              path: 'record/:id',
              builder: (_, s) {
                pushed.add(s.uri.path);
                return Scaffold(body: Text('기록 보기 ${s.pathParameters['id']}'));
              },
            ),
            GoRoute(
              path: 'trash',
              builder: (_, s) {
                pushed.add(s.uri.path);
                return const Scaffold(body: Text('삭제한 기록 화면'));
              },
            ),
          ],
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        guidanceRepositoryProvider.overrideWithValue(repo),
        guidanceUnlockProvider.overrideWithValue(unlock),
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
    await settle(tester);
    return container;
  }

  testWidgets('잠김 — 제목·이름이 화면에도 시맨틱스에도 없고 구분 칩은 있다', (tester) async {
    final handle = tester.ensureSemantics();
    await seed(tester);
    await pump(tester);

    expect(find.textContaining('박서준'), findsNothing);
    expect(find.textContaining('김하늘'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('박서준')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('김하늘')), findsNothing);
    expect(find.text(GuidanceStrings.lockedRecordTitle), findsNWidgets(2));
    expect(find.byKey(GuidanceListScreen.personFilterKey), findsNothing);
    expect(find.byKey(GuidanceListScreen.kindFilterKey(null)), findsOneWidget);
    expect(
      find.byKey(GuidanceListScreen.kindFilterKey(GuidanceKind.guidance)),
      findsOneWidget,
    );
    // 대략 시각 글에 든 이름도 가린다.
    expect(find.text(GuidanceStrings.occurredApproxHidden), findsOneWidget);
    handle.dispose();
  });

  testWidgets('풀림 — 제목·이름이 보인다(기존 동작)', (tester) async {
    unlock.markUnlocked();
    await seed(tester);
    await pump(tester);
    expect(find.text('박서준 수업 방해'), findsOneWidget);
    expect(find.text('박서준 · 김하늘'), findsOneWidget);
    expect(find.byKey(GuidanceListScreen.personFilterKey), findsOneWidget);
    expect(find.text(GuidanceStrings.lockedRecordTitle), findsNothing);
  });

  testWidgets('줄 누르기 + 인증 성공 — 인증 1회, 기록 보기로 간다. 빠른 두 번 탭도 1회', (tester) async {
    await seed(tester);
    await pump(tester);
    final row = find.byType(GuidanceRecordTile).first;
    await tester.tap(row);
    await tester.pump(const Duration(milliseconds: 5));
    await tester.tap(row, warnIfMissed: false);
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
    expect(auth.calls, 1);
    expect(
      pushed.where((p) => p.startsWith('/guidance/record/')),
      hasLength(1),
    );
    expect(unlock.isUnlocked, isTrue);
  });

  testWidgets('인증 실패 — 목록에 머문다', (tester) async {
    auth.outcome = AuthOutcome.failed;
    await seed(tester);
    await pump(tester);
    await tester.tap(find.byType(GuidanceRecordTile).first);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pumpAndSettle();
    expect(auth.calls, 1);
    expect(pushed, isEmpty);
    expect(unlock.isUnlocked, isFalse);
    expect(find.byType(GuidanceRecordTile), findsNWidgets(2));
  });

  testWidgets('기기 암호 없음 — 안내 창, 잠금 없이 열기를 누르면 풀고 열린다', (tester) async {
    auth.outcome = AuthOutcome.noCredentials;
    await seed(tester);
    await pump(tester);
    await tester.tap(find.byType(GuidanceRecordTile).first);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.noCredentialsTitle), findsOneWidget);
    expect(pushed, isEmpty);
    await tester.tap(find.text(GuidanceStrings.openWithoutLock));
    await tester.pumpAndSettle();
    expect(unlock.isUnlocked, isTrue);
    expect(
      pushed.where((p) => p.startsWith('/guidance/record/')),
      hasLength(1),
    );
  });

  testWidgets('삭제한 기록 버튼도 잠겨 있으면 인증한다', (tester) async {
    await seed(tester);
    await pump(tester);
    await tester.tap(find.byKey(GuidanceListScreen.trashKey));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pumpAndSettle();
    expect(auth.calls, 1);
    expect(pushed, ['/guidance/trash']);
  });

  testWidgets('풀린 상태에서 줄 누르기 — 인증 없이 바로 열린다', (tester) async {
    unlock.markUnlocked();
    await seed(tester);
    await pump(tester);
    await tester.tap(find.byType(GuidanceRecordTile).first);
    await tester.pumpAndSettle();
    expect(auth.calls, 0);
    expect(
      pushed.where((p) => p.startsWith('/guidance/record/')),
      hasLength(1),
    );
  });

  testWidgets('사람 필터를 골라 둔 채 잠기면 두 기록이 다 보이고 칩이 없다 — 풀리면 돌아온다', (tester) async {
    unlock.markUnlocked();
    await seed(tester);
    final container = await pump(tester);
    container.read(guidancePersonFilterProvider.notifier).state =
        const Participant(name: '김하늘');
    await tester.pumpAndSettle();
    expect(find.byType(GuidanceRecordTile), findsOneWidget);

    // 떠난 지 16분 — 돌아오면 잠긴다.
    unlock.markLeft();
    clock = clock.add(const Duration(minutes: 16));
    unlock.markBack();
    await tester.pumpAndSettle();
    expect(unlock.isUnlocked, isFalse);
    expect(find.byType(GuidanceRecordTile), findsNWidgets(2));
    expect(find.byKey(GuidanceListScreen.personFilterKey), findsNothing);
    expect(find.textContaining('김하늘'), findsNothing);

    // 다시 풀면 골라 둔 사람 필터가 돌아온다.
    unlock.markUnlocked();
    await tester.pumpAndSettle();
    expect(find.byType(GuidanceRecordTile), findsOneWidget);
  });

  testWidgets('사람 고르기 시트가 열린 채 다시 잠기면 시트가 닫혀 이름이 사라진다', (tester) async {
    unlock.markUnlocked();
    await seed(tester);
    await pump(tester);
    await tester.tap(find.byKey(GuidanceListScreen.personFilterKey));
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.personPickerTitle), findsOneWidget);
    expect(find.text('박서준'), findsWidgets);

    unlock.markLeft();
    clock = clock.add(const Duration(minutes: 16));
    unlock.markBack();
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.personPickerTitle), findsNothing);
    expect(find.textContaining('박서준'), findsNothing);
    expect(find.textContaining('김하늘'), findsNothing);
  });
}
