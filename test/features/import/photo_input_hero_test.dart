import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/import/presentation/widgets/photo_input_hero.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
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
}
