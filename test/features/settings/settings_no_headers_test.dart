import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/settings/presentation/widgets/export_list_tile.dart';
import 'package:planroutine/features/settings/presentation/widgets/settings_section.dart';
import 'package:planroutine/features/settings/presentation/widgets/stamp_settings_tiles.dart';
import 'package:planroutine/features/settings/presentation/widgets/trash_list_tile.dart';
import 'package:planroutine/shared/widgets/section_header.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(home: Scaffold(body: ListView(children: [child]))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SettingsSection — 제목 없이도 선다', () {
    testWidgets('title이 null이면 헤더를 그리지 않는다', (tester) async {
      await _pump(tester, const SettingsSection(child: Text('본문')));

      expect(find.byType(SectionHeader), findsNothing);
      expect(find.text('본문'), findsOneWidget);
    });

    testWidgets('title을 주면 그린다 — 아직 쓰는 곳이 생길 수 있다', (tester) async {
      await _pump(
        tester,
        const SettingsSection(title: '제목', child: Text('본문')),
      );

      expect(find.byType(SectionHeader), findsOneWidget);
    });
  });

  group('헤더를 걷어내며 설명을 잃지 않았는가', () {
    // **이 그룹이 이번 변경의 급소다.** 헤더만 지우면 그 부제가 함께 사라지는데,
    // 아래 셋은 앱의 다른 어디에서도 다시 볼 수 없는 사실이다.

    testWidgets('휴지통 — 30일 규칙이 행에 남아 있다', (tester) async {
      await _pump(tester, const TrashListTile());

      expect(find.text(SettingsStrings.trashDescription), findsOneWidget);
      expect(
        SettingsStrings.trashDescription,
        contains('30일'),
        reason: '이 규칙은 여기서만 볼 수 있다 — 문구가 바뀌어도 30일은 남아야 한다',
      );
    });

    testWidgets('내보내기 — 무엇이 나가는지 행에 남아 있다', (tester) async {
      await _pump(tester, const ExportListTile());

      expect(find.text(SettingsStrings.exportDescription), findsOneWidget);
    });

    testWidgets('완료 도장 — 어디에 찍히는지 행에 남아 있다', (tester) async {
      await _pump(tester, const StampSettingsTiles());

      expect(find.text(SettingsStrings.stampDescription), findsOneWidget);
    });
  });
}
