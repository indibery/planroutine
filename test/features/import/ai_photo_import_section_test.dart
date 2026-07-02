import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/import/presentation/widgets/ai_photo_import_section.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/presentation/providers/schedule_providers.dart';

import '../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);

  late DatabaseHelper db;
  late ScheduleRepository repo;
  String? clipboardText;

  setUp(() {
    db = freshDatabaseHelper();
    repo = ScheduleRepository(dbHelper: db);
    clipboardText = null;
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpSection(WidgetTester tester) async {
    // 클립보드 채널 mock — setData 캡처 / getData 주입
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText = (call.arguments as Map)['text'] as String?;
          return null;
        }
        if (call.method == 'Clipboard.getData') {
          return {'text': clipboardText};
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [scheduleRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: AiPhotoImportSection())),
        ),
      ),
    );
    await tester.pump();
  }

  group('AiPhotoImportSection', () {
    testWidgets('프롬프트 복사·붙여넣기 두 버튼이 보인다', (tester) async {
      await pumpSection(tester);
      expect(find.text('① 변환 프롬프트 복사'), findsOneWidget);
      expect(find.text('② 붙여넣기로 가져오기'), findsOneWidget);
    });

    testWidgets('프롬프트 복사를 탭하면 클립보드에 변환 프롬프트가 실린다', (tester) async {
      await pumpSection(tester);
      await tester.tap(find.text('① 변환 프롬프트 복사'));
      await tester.pump();
      expect(clipboardText, contains('학교 연간 행사 일정표'));
      expect(clipboardText, contains('yyyy-MM-dd'));
    });

    testWidgets('붙여넣기 → 미리보기 시트 → 등록하면 검토 대기로 저장', (tester) async {
      await pumpSection(tester);
      clipboardText =
          '[{"title":"입학식","date":"2026-03-02"},{"title":"봄 현장체험학습","date":"2026-04-24"}]';

      // FFI DB 호출은 실제 비동기라 runAsync로 감싸고, 고정 delay 대신
      // 시트가 열릴 때까지 조건 대기(첫 DB 오픈은 수백 ms 걸릴 수 있음).
      await tester.runAsync(() async {
        await tester.tap(find.text('② 붙여넣기로 가져오기'));
        for (var i = 0;
            i < 100 && find.text(ImportStrings.aiPreviewTitle).evaluate().isEmpty;
            i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();

      // 미리보기: 인식 건수 + 항목
      expect(find.textContaining('2건'), findsWidgets);
      expect(find.text('입학식'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.textContaining('검토 목록에 등록'));
        for (var i = 0;
            i < 100 &&
                find.text(ImportStrings.aiPreviewTitle).evaluate().isNotEmpty;
            i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();

      final saved = await tester.runAsync(() => repo.getSchedules());
      expect(saved!.length, 2);
      await tester.pump(const Duration(seconds: 4)); // 스낵바 타이머 소진
    });

    testWidgets('클립보드에 행사 JSON이 없으면 안내만 하고 등록 없음', (tester) async {
      await pumpSection(tester);
      clipboardText = '사진이 잘 안 보여요';

      await tester.runAsync(() async {
        await tester.tap(find.text('② 붙여넣기로 가져오기'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.textContaining('행사를 찾지 못했'), findsOneWidget);
      final saved = await tester.runAsync(() => repo.getSchedules());
      expect(saved, isEmpty);
      await tester.pump(const Duration(seconds: 4)); // 스낵바 타이머 소진
    });
  });
}
