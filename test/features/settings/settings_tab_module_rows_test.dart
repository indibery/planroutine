// 설정 탭에는 앱 공통 설정과 고정 탭의 설정만 둔다. 선택 기능의 설정은
// `기능 관리` › 그 기능의 행으로만 들어간다(2026-10-03 설계).
//
// 다음 기능을 만들 때 습관적으로 설정 탭에 행을 추가하면 이 가드가 막는다.
// **주석은 걷어내고 본다** — 이 리포는 "언급을 사용으로 읽는" 스캐너 함정을
// 다섯 번 밟았다(CLAUDE.md 훅 절).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/modules/module_catalog.dart';

String _code(File f) => f
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

/// `AppRoutes`의 `static const 이름 = '경로';`를 이름 → 경로로 읽는다.
Map<String, String> _appRoutes() {
  final src = File('lib/core/router/app_router.dart').readAsStringSync();
  return {
    for (final m in RegExp(
      r"static const (\w+) = '([^']+)';",
    ).allMatches(src))
      m.group(1) ?? '': m.group(2) ?? '',
  };
}

/// 설정 탭을 이루는 파일들 — 화면 하나와 그 섹션 위젯들.
List<File> _settingsTabFiles() => [
  File('lib/features/settings/presentation/screens/settings_screen.dart'),
  ...Directory('lib/features/settings/presentation/widgets')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart')),
];

void main() {
  test('설정 탭은 선택 기능의 상세 설정으로 직접 가지 않는다 — 입구는 기능 관리', () {
    final targets = {for (final m in moduleCatalog) ?m.settingsRoute};
    final names = [
      for (final e in _appRoutes().entries)
        if (targets.contains(e.value)) e.key,
    ];
    expect(names, isNotEmpty, reason: '등록부의 상세 경로를 AppRoutes에서 찾지 못했다');

    for (final f in _settingsTabFiles()) {
      final src = _code(f);
      for (final n in names) {
        expect(
          src.contains('AppRoutes.$n'),
          isFalse,
          reason: '${f.path}가 AppRoutes.$n로 간다 — 선택 기능의 설정은 기능 관리 안에서 연다',
        );
      }
    }
  });

  test('설정 탭은 선택 기능의 요약 위젯을 그리지 않는다', () {
    final types = [
      for (final m in moduleCatalog)
        if (m.settingsSummary case final w?) w.runtimeType.toString(),
    ];
    expect(types, isNotEmpty, reason: '요약 위젯을 가진 기능이 없다');

    final src = _code(
      File('lib/features/settings/presentation/screens/settings_screen.dart'),
    );
    for (final t in types) {
      expect(src.contains(t), isFalse, reason: '설정 탭에 $t가 다시 들어왔다');
    }
  });
}
