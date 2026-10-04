import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/features/settings/presentation/screens/bus_settings_screen.dart';
import 'package:planroutine/features/settings/presentation/screens/modules_screen.dart';
import 'package:planroutine/features/settings/presentation/screens/settings_screen.dart';

/// 버튼 노드가 **다른 누를 수 있는 노드를 자식으로 품으면 안 된다.**
///
/// `ListTile`은 스스로 시맨틱스 노드를 만들지 않아, 한 목록 항목 안에 여러 줄이 있으면 첫 줄의
/// 버튼 표시·이름이 항목 전체 노드로 올라가 뒤 줄(스위치 등)을 자식으로 품는다. 시뮬레이터
/// 자동화는 그 버튼을 두 줄 높이로 읽고 가운데를 누르므로 **엉뚱한 스위치가 바뀐다** —
/// `도장 모양`과 기능 관리의 `상세 설정`이 그랬다(2026-10-04). 고칠 때는 위쪽 줄을
/// `Semantics(container: true)`로 감싼다.
///
/// 줄만 떼어 띄우면 재현되지 않는다 — 반드시 화면 전체를 띄워 본다.
List<String> nestedButtons(SemanticsNode root) {
  final out = <String>[];
  bool hasTapDescendant(SemanticsNode n) {
    var found = false;
    n.visitChildren((c) {
      final d = c.getSemanticsData();
      if (d.hasAction(SemanticsAction.tap) || hasTapDescendant(c)) found = true;
      return !found;
    });
    return found;
  }

  void visit(SemanticsNode n) {
    final d = n.getSemanticsData();
    if (d.flagsCollection.isButton && hasTapDescendant(n)) {
      out.add('${d.label.isEmpty ? '(이름 없음)' : d.label} ${n.rect}');
    }
    n.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  visit(root);
  return out;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      // 버스를 켜 둬야 기능 관리에 `상세 설정` 줄이 생긴다.
      'flutter.installed_modules_v1':
          '["today","calendar","schedule","settings","bus"]',
    });
    PackageInfo.setMockInitialValues(
      appName: '공직플랜',
      packageName: 'com.planroutine.app',
      version: '1.4.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  final screens = <String, Widget>{
    '설정': const SettingsScreen(),
    '기능 관리': const ModulesScreen(),
    '출퇴근 버스 설정': const BusSettingsScreen(),
  };

  for (final MapEntry(key: name, value: screen) in screens.entries) {
    testWidgets('$name 화면: 버튼 노드가 누를 수 있는 노드를 품지 않는다', (tester) async {
      tester.view.physicalSize = const Size(402, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ProviderScope(child: MaterialApp(home: screen)));
      await tester.pump(const Duration(milliseconds: 500));

      final root = tester
          .binding
          .renderViews
          .first
          .owner
          ?.semanticsOwner
          ?.rootSemanticsNode;
      expect(root, isNotNull);
      final offenders = nestedButtons(root ?? SemanticsNode());
      expect(offenders, isEmpty, reason: offenders.join('\n'));
      handle.dispose();
    });
  }

  testWidgets('검사 자체: 버튼이 탭 가능한 자식을 품으면 잡는다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Semantics(
          container: true,
          button: true,
          label: '상세 설정',
          child: Column(
            children: [
              const Text('정류장을 등록해 주세요'),
              Semantics(
                container: true,
                onTap: () {},
                child: const SizedBox(width: 40, height: 40),
              ),
            ],
          ),
        ),
      ),
    );
    final root = tester
        .binding
        .renderViews
        .first
        .owner
        ?.semanticsOwner
        ?.rootSemanticsNode;
    expect(nestedButtons(root ?? SemanticsNode()), hasLength(1));
    handle.dispose();
  });
}
