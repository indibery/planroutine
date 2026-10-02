import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/modules/app_module.dart';
import 'package:planroutine/core/modules/module_rules.dart';

ModuleTab _tab(String route) => ModuleTab(
  route: route,
  icon: Icons.circle_outlined,
  activeIcon: Icons.circle,
  label: route,
);

AppModule _fixed(String id) => AppModule(
  id: id,
  name: id,
  icon: Icons.circle,
  placement: ModulePlacement.tab,
  fixed: true,
  tab: _tab('/$id'),
);

AppModule _optionalTab(String id) => AppModule(
  id: id,
  name: id,
  icon: Icons.circle,
  placement: ModulePlacement.tab,
  tab: _tab('/$id'),
);

AppModule _card(String id) => AppModule(
  id: id,
  name: id,
  icon: Icons.circle,
  placement: ModulePlacement.todayCard,
  card: const SizedBox(),
);

final _catalog = [
  _fixed(ModuleIds.today),
  _fixed(ModuleIds.calendar),
  _fixed(ModuleIds.schedule),
  _fixed(ModuleIds.settings),
  _card(ModuleIds.bus),
  _optionalTab('t1'),
  _optionalTab('t2'),
  _optionalTab('t3'),
];

List<String> _tabIds(ResolvedModules r) => r.tabs.map((m) => m.id).toList();

void main() {
  group('resolveModules', () {
    test('저장값이 없으면 고정 4탭만, 카탈로그 순서로', () {
      final r = resolveModules(_catalog, null);
      expect(_tabIds(r), ['today', 'calendar', 'schedule', 'settings']);
      expect(r.cards, isEmpty);
    });

    test('저장 순서가 곧 탭 순서다', () {
      final r = resolveModules(_catalog, [
        'calendar',
        'today',
        'schedule',
        'settings',
      ]);
      expect(_tabIds(r), ['calendar', 'today', 'schedule', 'settings']);
    });

    test('빠진 고정 탭은 카탈로그 순서로 설정 앞에 붙는다', () {
      final r = resolveModules(_catalog, ['schedule']);
      expect(_tabIds(r), ['schedule', 'today', 'calendar', 'settings']);
    });

    test('설정은 저장 위치와 무관하게 맨 끝이다', () {
      final r = resolveModules(_catalog, [
        'settings',
        'today',
        'calendar',
        'schedule',
      ]);
      expect(_tabIds(r).last, 'settings');
    });

    test('등록부에 없는 id는 조용히 버린다', () {
      final r = resolveModules(_catalog, ['gone', 'today', 'bus']);
      expect(r.ids, isNot(contains('gone')));
      expect(r.cards.map((m) => m.id), ['bus']);
    });

    test('중복 id는 첫 등장만 남는다', () {
      final r = resolveModules(_catalog, ['t1', 'today', 't1']);
      expect(_tabIds(r).where((id) => id == 't1'), hasLength(1));
      expect(_tabIds(r).first, 't1');
    });

    test('탭이 6개를 넘으면 뒤쪽 선택 탭부터 잘린다 — 고정과 설정은 남는다', () {
      final r = resolveModules(_catalog, [
        'today',
        'calendar',
        'schedule',
        't1',
        't2',
        't3',
        'settings',
      ]);
      expect(r.tabs, hasLength(kMaxTabs));
      expect(_tabIds(r), [
        'today',
        'calendar',
        'schedule',
        't1',
        't2',
        'settings',
      ]);
    });

    test('카드형은 탭 상한에 포함되지 않는다', () {
      final r = resolveModules(_catalog, [
        'today',
        'calendar',
        'schedule',
        't1',
        't2',
        'settings',
        'bus',
      ]);
      expect(r.tabs, hasLength(6));
      expect(r.cards.map((m) => m.id), ['bus']);
    });

    test('ids는 탭 다음 카드 순서다', () {
      final r = resolveModules(_catalog, ['bus', 'today']);
      expect(r.ids, ['today', 'calendar', 'schedule', 'settings', 'bus']);
    });
  });

  group('decodeModuleIds', () {
    test('null이면 null', () => expect(decodeModuleIds(null), isNull));

    test('정상 목록을 읽는다', () {
      expect(decodeModuleIds('["today","bus"]'), ['today', 'bus']);
    });

    test('손상된 저장값이면 null — 기본값으로 떨어진다', () {
      expect(decodeModuleIds('not json'), isNull);
      expect(decodeModuleIds('{"a":1}'), isNull);
    });

    test('문자열이 아닌 원소는 버린다', () {
      expect(decodeModuleIds('["today",3,null,"bus"]'), ['today', 'bus']);
    });
  });

  group('migrateLegacyModuleIds — bus_settings_v1의 enabled 이전', () {
    test('버스를 켜 둔 기존 사용자는 버스가 설치된다', () {
      expect(migrateLegacyModuleIds('{"enabled":true}'), [ModuleIds.bus]);
    });

    test('꺼 둔 기존 사용자는 아무것도 설치되지 않는다', () {
      expect(migrateLegacyModuleIds('{"enabled":false}'), isEmpty);
    });

    test('신규 사용자(키 없음)는 아무것도 설치되지 않는다', () {
      expect(migrateLegacyModuleIds(null), isEmpty);
    });

    test('bus_settings_v1이 깨져 있으면 설치하지 않는다', () {
      expect(migrateLegacyModuleIds('{{{'), isEmpty);
      expect(migrateLegacyModuleIds('[1,2]'), isEmpty);
    });
  });
}
