import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_list_screen.dart';

import '../../../helpers/test_database.dart';

/// 지도 기록의 `+`(새 기록)는 **자식 없는 잎 노드**여야 한다.
///
/// `FloatingActionButton`에 `Icon(semanticLabel:)`만 주면 Flutter 트리에는 이름이 있지만
/// (아이콘 노드를 버튼 노드에 합친다) mobile MCP는 그 합친 노드를 이름 없는 `Button`으로
/// 읽었다 — `SegmentedButton`과 같은 증상이다. 직접 만든 잎 노드는 어떤 플래그 조합이든
/// 이름이 보였다(2026-10-04 실측). `snapshot_ui`는 원래도 읽었다.
void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;

  setUp(() => db = freshDatabaseHelper());
  tearDown(() async => db.close());

  testWidgets('새 기록 버튼이 이름 있는 잎 노드다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidanceRepositoryProvider.overrideWithValue(
            GuidanceRepository(dbHelper: db),
          ),
        ],
        child: const MaterialApp(home: GuidanceListScreen()),
      ),
    );
    for (var i = 0; i < 2; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final node = tester.getSemantics(
      find.bySemanticsLabel(GuidanceStrings.newRecord),
    );
    expect(
      node,
      isSemantics(
        label: GuidanceStrings.newRecord,
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(node.mergeAllDescendantsIntoThisNode, isFalse);
    expect(node.childrenCount, 0);
    handle.dispose();
  });
}
