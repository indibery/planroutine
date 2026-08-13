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
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

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
      for (
        var i = 0;
        i < 100 && find.text(ImportStrings.aiPreviewTitle).evaluate().isEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('2건'), findsWidgets);
    expect(find.text('입학식'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.textContaining('검토 목록에 등록'));
      for (
        var i = 0;
        i < 100 &&
            find.text(ImportStrings.aiPreviewTitle).evaluate().isNotEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();

    final saved = await tester.runAsync(() => repo.getSchedules());
    expect(saved!.length, 2);
    expect(
      saved.every((s) => s.kind == EntryKind.event),
      isTrue,
      reason: '기본 선택(행사 일정표)이면 행사로 저장된다',
    );
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

    // 히어로 기본 종류는 행사다(`_source = EntryKind.event`). 문구가 종류를
    // 따라가므로 그 값으로 찾는다 — 업무 쪽지로 넣었는데 `행사를 찾지 못했어요`가
    // 뜨던 것을 고치면서 kind 인자가 붙었다.
    expect(
      find.text(ImportStrings.aiParseEmptyFor(EntryKind.event)),
      findsOneWidget,
    );
    final saved = await tester.runAsync(() => repo.getSchedules());
    expect(saved, isEmpty);
    await tester.pump(const Duration(seconds: 4)); // 스낵바 타이머 소진
  });

  testWidgets('업무 쪽지를 고르면 프롬프트가 기한을 찾는 것으로 바뀐다', (tester) async {
    await pumpHero(tester);

    await tester.tap(find.text(ImportStrings.aiSourceTask));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ImportStrings.heroStepCopy));
    await tester.pumpAndSettle();

    expect(clipboardText, contains('내가 해야 할 일'));
    expect(clipboardText, contains('반납예정일'), reason: '학교 밖 낱말도 예시에 있어야 한다');
    expect(clipboardText, isNot(contains('표에 있는 모든 일정')));
    await tester.pump(const Duration(seconds: 4)); // 스낵바 타이머 소진
  });

  testWidgets('행사 일정표로 되돌리면 프롬프트도 되돌아온다', (tester) async {
    await pumpHero(tester);

    await tester.tap(find.text(ImportStrings.aiSourceTask));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ImportStrings.aiSourceEvent));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ImportStrings.heroStepCopy));
    await tester.pumpAndSettle();

    expect(clipboardText, contains('표에 있는 모든 일정'));
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('업무 쪽지로 등록하면 업무로 저장된다 — 오늘 탭에 뜨는 조건', (tester) async {
    // **이 테스트가 이 기능의 급소다.** 프롬프트와 등록 종류가 갈리면 쪽지 프롬프트로
    // 뽑은 마감 기한이 행사로 저장돼 오늘 탭에 뜨지 않고, 사용자는 사진을 찍은
    // 이유(그날 할 일을 잊지 않는 것)를 잃는다.
    await pumpHero(tester);
    clipboardText = '[{"title":"방과후 신청서 제출","date":"2026-10-15"}]';

    await tester.tap(find.text(ImportStrings.aiSourceTask));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text(ImportStrings.heroStepPaste));
      for (
        var i = 0;
        i < 100 && find.text(ImportStrings.aiPreviewTitle).evaluate().isEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.textContaining('검토 목록에 등록'));
      for (
        var i = 0;
        i < 100 &&
            find.text(ImportStrings.aiPreviewTitle).evaluate().isNotEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();

    final saved = await tester.runAsync(() => repo.getSchedules());
    expect(saved!.single.title, '방과후 신청서 제출');
    expect(
      saved.single.kind,
      EntryKind.task,
      reason: '업무로 저장돼야 오늘 탭에 뜨고 체크로 완료할 수 있다',
    );
    await tester.pump(const Duration(seconds: 4));
  });
}
