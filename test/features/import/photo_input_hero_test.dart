import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/import/presentation/widgets/photo_input_hero.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/schedule/presentation/providers/schedule_providers.dart';

import '../../helpers/test_database.dart';

/// 입력 탭 히어로 — 사진 AI가 주 경로, 작년 업무 CSV는 보조 한 줄.
void main() {
  setUpAll(setUpFfiForTests);

  late DatabaseHelper db;
  late ScheduleRepository repo;
  String? clipboardText;
  var csvTapped = 0;

  setUp(() {
    db = freshDatabaseHelper();
    repo = ScheduleRepository(dbHelper: db);
    clipboardText = null;
    csvTapped = 0;
  });

  tearDown(() async => db.close());

  Future<void> pumpHero(WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText = (call.arguments as Map)['text'] as String?;
          return null;
        }
        if (call.method == 'Clipboard.getData') return {'text': clipboardText};
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [scheduleRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: PhotoInputHero(onOpenCsvImport: () => csvTapped++),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('사진 히어로가 왕복 3단 흐름을 보여준다', (tester) async {
    await pumpHero(tester);

    expect(find.text(ImportStrings.heroTitle), findsOneWidget);
    expect(find.text(ImportStrings.heroStepCopy), findsOneWidget);
    expect(find.text(ImportStrings.heroStepAway), findsOneWidget);
    expect(find.text(ImportStrings.heroStepPaste), findsOneWidget);
  });

  testWidgets('① 프롬프트를 탭하면 클립보드에 변환 프롬프트가 실린다', (tester) async {
    await pumpHero(tester);

    await tester.tap(find.text(ImportStrings.heroStepCopy));
    await tester.pump();

    expect(clipboardText, contains('yyyy-MM-dd'));
    expect(clipboardText, contains('일정표'));
  });

  testWidgets('작년 업무 CSV는 보조 한 줄 링크다', (tester) async {
    await pumpHero(tester);

    expect(find.text(ImportStrings.heroCsvLink), findsOneWidget);
    await tester.tap(find.text(ImportStrings.heroCsvLink));
    await tester.pump();

    expect(csvTapped, 1);
  });

  testWidgets('좁은 화면에서도 3단 흐름이 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHero(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('② 붙여넣기 → 미리보기 → 등록하면 검토 대기로 저장된다', (tester) async {
    await pumpHero(tester);
    clipboardText =
        '[{"title":"입학식","date":"2026-03-02"},{"title":"봄 현장체험학습","date":"2026-04-24"}]';

    // FFI DB 호출은 실제 비동기라 runAsync로 감싸고, 고정 delay 대신
    // 시트가 열릴 때까지 조건 대기(첫 DB 오픈은 수백 ms 걸릴 수 있음).
    await tester.runAsync(() async {
      await tester.tap(find.text(ImportStrings.heroStepPaste));
      for (var i = 0;
          i < 100 && find.text(ImportStrings.aiPreviewTitle).evaluate().isEmpty;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();

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
    expect(saved.every((s) => s.kind == EntryKind.event), isTrue,
        reason: '사진 경로는 행사');
    await tester.pump(const Duration(seconds: 4)); // 스낵바 타이머 소진
  });

  testWidgets('클립보드에 일정 JSON이 없으면 안내만 하고 등록하지 않는다', (tester) async {
    await pumpHero(tester);
    clipboardText = '사진이 잘 안 보여요';

    await tester.runAsync(() async {
      await tester.tap(find.text(ImportStrings.heroStepPaste));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.text(ImportStrings.aiParseEmpty), findsOneWidget);
    final saved = await tester.runAsync(() => repo.getSchedules());
    expect(saved, isEmpty);
    await tester.pump(const Duration(seconds: 4)); // 스낵바 타이머 소진
  });
}
