import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/features/settings/presentation/screens/settings_screen.dart';
import 'package:planroutine/features/settings/presentation/widgets/stamp_settings_tiles.dart';

/// 설정의 `도장 모양` 줄은 **자기 영역만큼의 노드**여야 한다.
///
/// `ListTile`은 스스로 시맨틱스 노드를 만들지 않아, 같은 목록 항목 안에 `이미 찍은 도장 흐리게`
/// 스위치 줄이 함께 있으면 도장 줄의 버튼 표시·이름이 항목 전체 노드로 올라가고 스위치 줄이
/// 그 자식이 됐다. 두 시뮬레이터 자동화 도구 모두 도장 줄을 두 줄 높이(145)로 읽어, 가운데를
/// 누르면 스위치가 바뀌었다(2026-10-04 실측). 처음엔 iOS 쪽 현상으로 봤는데 — 줄만 떼어
/// 띄우면 재현되지 않는다 — **설정 화면 전체**를 띄우자 Flutter 트리에서 그대로 나왔다.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: '공직플랜',
      packageName: 'com.planroutine.app',
      version: '1.4.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('도장 모양 줄 노드가 스위치 줄을 품지 않는다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final tile = find.byKey(StampSettingsTiles.styleTileKey);
    final node = tester.getSemantics(tile);
    expect(node.childrenCount, 0, reason: '스위치 줄이 도장 줄 노드의 자식이면 안 된다');
    expect(
      node.rect.height,
      tester.getSize(tile).height,
      reason: '노드 높이가 도장 줄 높이와 같아야 한다',
    );
    handle.dispose();
  });
}
