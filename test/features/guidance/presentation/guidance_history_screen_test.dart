import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_history_screen.dart';

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

  testWidgets('판마다 저장 시각·전체 내용을 보여 주고 바뀐 칸을 말한다', (tester) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final id = await tester.runAsync(() async {
      final id = await repo.create(const GuidanceContent(title: '복도 다툼', facts: '처음 쓴 경과'));
      await repo.saveRevision(
        id,
        const GuidanceContent(title: '복도 다툼', facts: '고친 경과', status: GuidanceStatus.closedAtSchool),
      );
      final a = await repo.addAttachment(
        GuidanceAttachment(
          recordId: id,
          type: AttachmentType.audio,
          source: AttachmentSource.imported,
          fileName: 'x.m4a',
          originalName: '음성 메모 0930.m4a',
          sha256: 'h',
          byteSize: 1,
          attachedAt: DateTime(2026, 10, 2, 17, 10).toIso8601String(),
        ),
      );
      await repo.removeAttachment(a.id ?? -1);
      return id;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guidanceRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(home: GuidanceHistoryScreen(recordId: id ?? -1)),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text(GuidanceStrings.historyIntro), findsOneWidget);
    expect(find.byKey(GuidanceHistoryScreen.revisionKey(2)), findsOneWidget);
    expect(find.byKey(GuidanceHistoryScreen.revisionKey(1)), findsOneWidget);
    expect(find.text('처음 쓴 경과'), findsOneWidget, reason: '옛 판의 원문이 남아 있다');
    expect(find.text('고친 경과'), findsOneWidget);
    expect(find.text(GuidanceStrings.revisionCurrent), findsOneWidget);
    expect(find.text('처음 작성'), findsOneWidget);
    expect(find.text('수정 버전 1'), findsOneWidget);
    // `판단·조치` 칸 이름에도 `판`이 있으므로 `판 1` 같은 번호 꼴만 찾는다
    expect(find.textContaining(RegExp(r'판 \d')), findsNothing, reason: '화면에 `판 N`을 쓰지 않는다');
    expect(
      find.text(GuidanceStrings.changedLabel('${GuidanceStrings.fieldStatus}, ${GuidanceStrings.fieldFacts}')),
      findsOneWidget,
    );
    expect(find.textContaining(GuidanceStrings.attachedLog('음성 메모 0930.m4a')), findsOneWidget);
    expect(find.textContaining(GuidanceStrings.removedLog('음성 메모 0930.m4a')), findsOneWidget);
  });
}
