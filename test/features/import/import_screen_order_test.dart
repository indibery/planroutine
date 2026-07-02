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

  testWidgets('가져오기 초기 화면: AI 사진 섹션이 CSV 카드보다 위', (tester) async {
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

    final aiY = tester.getTopLeft(find.text(ImportStrings.aiPaste)).dy;
    final csvY = tester.getTopLeft(find.text(ImportStrings.selectFile)).dy;
    expect(aiY, lessThan(csvY), reason: 'AI 사진(수시)이 위, CSV(연 1회)가 아래');

    // 구분선 문구는 CSV 쪽으로
    expect(find.text(ImportStrings.csvDivider), findsOneWidget);
    expect(find.text(ImportStrings.aiDivider), findsNothing);
  });
}
