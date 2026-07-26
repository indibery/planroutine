import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/import/presentation/screens/import_screen.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/presentation/providers/schedule_providers.dart';

import '../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);

  late DatabaseHelper db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = freshDatabaseHelper();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('가져오기 화면은 작년 업무 CSV 전용 — 사진 AI 섹션이 없다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleRepositoryProvider
              .overrideWithValue(ScheduleRepository(dbHelper: db)),
        ],
        child: const MaterialApp(home: ImportScreen()),
      ),
    );
    await tester.pump();

    // 제목부터 무엇을 하는 화면인지 말한다.
    expect(find.text(ImportStrings.screenTitle), findsOneWidget);
    expect(find.text(ImportStrings.csvTitle), findsOneWidget);
    expect(find.text(ImportStrings.selectFile), findsOneWidget);
    expect(find.text(ImportStrings.edufineGuideTitle), findsOneWidget);

    // 사진 AI는 입력 탭 히어로가 맡는다 — 여기서 또 권하면
    // '작년 업무 가져오기'를 누르고 들어온 사람에게 엉뚱한 화면이 된다.
    expect(find.text(ImportStrings.aiPaste), findsNothing);
    expect(find.text(ImportStrings.aiCopyPrompt), findsNothing);
    expect(find.text(ImportStrings.aiTitle), findsNothing);
  });
}
