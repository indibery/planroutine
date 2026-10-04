import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/domain/participant.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_list_screen.dart';
import 'package:planroutine/features/guidance/presentation/widgets/guidance_record_tile.dart';

import 'package:planroutine/shared/widgets/empty_state.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late GuidanceRepository repo;

  setUp(() {
    db = freshDatabaseHelper();
    repo = GuidanceRepository(dbHelper: db);
  });
  tearDown(() async => db.close());

  /// 목록이 다 읽힐 때까지 기다린다 — 읽는 동안 화면은 빈 칸(`SizedBox.shrink`)이다.
  /// 고정 대기(50ms × 2)는 전체 실행의 부하에서 모자라 빈 상태 테스트가 간헐적으로 실패했다.
  Future<void> settle(WidgetTester tester) async {
    bool loaded() =>
        find.byType(EmptyState).evaluate().isNotEmpty ||
        find.byType(GuidanceRecordTile).evaluate().isNotEmpty ||
        find.text(GuidanceStrings.noMatch).evaluate().isNotEmpty;
    for (var i = 0; i < 40 && !loaded(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guidanceRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: GuidanceListScreen()),
      ),
    );
    await settle(tester);
  }

  testWidgets('기록이 없으면 다른 탭과 같은 빈 상태(아이콘 + 두 줄)가 보인다', (tester) async {
    // 범위 안내 문장은 새 기록 화면의 `구분` 아래로 옮겼다(2026-10-04 디자인 점검).
    await pump(tester);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text(GuidanceStrings.empty), findsOneWidget);
    expect(find.text(GuidanceStrings.emptyHint), findsOneWidget);
    expect(find.text(GuidanceStrings.scopeNote), findsNothing);
  });

  testWidgets('사건 시각이 최근인 기록이 위에 오고 수정 횟수가 보인다', (tester) async {
    await tester.runAsync(() async {
      final a = await repo.create(
        GuidanceContent(title: '오래된 일', occurredAt: DateTime(2026, 9, 25, 12, 40)),
      );
      await repo.create(GuidanceContent(title: '최근 일', occurredAt: DateTime(2026, 10, 2, 15, 30)));
      await repo.saveRevision(
        a,
        GuidanceContent(title: '오래된 일', facts: '덧붙임', occurredAt: DateTime(2026, 9, 25, 12, 40)),
      );
    });
    await pump(tester);
    final recent = tester.getTopLeft(find.text('최근 일'));
    final old = tester.getTopLeft(find.text('오래된 일'));
    expect(recent.dy < old.dy, isTrue);
    expect(find.text(GuidanceStrings.revisedTimes(1)), findsOneWidget);
  });

  testWidgets('구분 필터로 교육활동 침해만 본다', (tester) async {
    await tester.runAsync(() async {
      await repo.create(const GuidanceContent(title: '복도 다툼'));
      await repo.create(
        const GuidanceContent(title: '학부모 폭언', kind: GuidanceKind.infringement),
      );
    });
    await pump(tester);
    await tester.tap(find.byKey(GuidanceListScreen.kindFilterKey(GuidanceKind.infringement)));
    await settle(tester);
    expect(find.text('학부모 폭언'), findsOneWidget);
    expect(find.text('복도 다툼'), findsNothing);
  });

  testWidgets('사람으로 고르면 그 사람이 나온 기록만 보인다', (tester) async {
    await tester.runAsync(() async {
      await repo.create(
        const GuidanceContent(title: '하늘 건', participants: [Participant(personId: 1, name: '김하늘')]),
      );
      await repo.create(
        const GuidanceContent(title: '서준 건', participants: [Participant(name: '박서준', memo: '5반')]),
      );
    });
    await pump(tester);
    await tester.tap(find.byKey(GuidanceListScreen.personFilterKey));
    await tester.pumpAndSettle();
    // 목록 행에도 같은 이름이 있으므로 시트 안의 것만 누른다.
    await tester.tap(
      find.descendant(of: find.byType(BottomSheet), matching: find.text('박서준 · 5반')),
    );
    await settle(tester);
    expect(find.text('서준 건'), findsOneWidget);
    expect(find.text('하늘 건'), findsNothing);
    expect(find.text(GuidanceStrings.personLabel('박서준')), findsOneWidget);
  });

  testWidgets('이관한 기록에는 이관 배지가, 진행 중에는 상태 배지가 없다', (tester) async {
    await tester.runAsync(() async {
      await repo.create(
        const GuidanceContent(title: '넘긴 일', status: GuidanceStatus.transferred),
      );
      await repo.create(const GuidanceContent(title: '진행 일'));
    });
    await pump(tester);
    expect(find.text(GuidanceStrings.statusTransferredShort), findsOneWidget);
    expect(find.text(GuidanceStrings.statusClosedShort), findsNothing);
  });

  testWidgets('320pt에서도 필터 줄이 넘치지 않는다', (tester) async {
    await pump(tester, width: 320);
    expect(tester.takeException(), isNull);
  });
}
