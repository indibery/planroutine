import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/modules/app_module.dart';
import 'package:planroutine/core/modules/installed_modules_provider.dart';
import 'package:planroutine/core/modules/module_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 탭형 선택 기능이 아직 없으므로 테스트용 둘을 주입한다.
const _t1 = AppModule(
  id: 't1',
  name: 't1',
  icon: Icons.circle,
  placement: ModulePlacement.tab,
  tab: ModuleTab(
    route: '/t1',
    icon: Icons.circle_outlined,
    activeIcon: Icons.circle,
    label: 't1',
  ),
);
const _t2 = AppModule(
  id: 't2',
  name: 't2',
  icon: Icons.circle,
  placement: ModulePlacement.tab,
  tab: ModuleTab(
    route: '/t2',
    icon: Icons.circle_outlined,
    activeIcon: Icons.circle,
    label: 't2',
  ),
);
const _t3 = AppModule(
  id: 't3',
  name: 't3',
  icon: Icons.circle,
  placement: ModulePlacement.tab,
  tab: ModuleTab(
    route: '/t3',
    icon: Icons.circle_outlined,
    activeIcon: Icons.circle,
    label: 't3',
  ),
);

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: [
      moduleCatalogProvider.overrideWithValue([
        ...moduleCatalog,
        _t1,
        _t2,
        _t3,
      ]),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<List<String>?> _saved() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(installedModulesPrefsKey);
  return raw == null ? null : List<String>.from(jsonDecode(raw) as List);
}

void main() {
  group('이전', () {
    test('버스를 켜 둔 기존 사용자는 첫 읽기에서 버스가 설치되고 저장된다', () async {
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': '{"enabled":true}',
      });
      final r = await _container().read(installedModulesProvider.future);
      expect(r.cards.map((m) => m.id), [ModuleIds.bus]);
      expect(await _saved(), contains(ModuleIds.bus));
    });

    test('이미 이전한 사용자는 다시 이전하지 않는다 — 버스를 끈 뒤 enabled가 남아 있어도', () async {
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': '{"enabled":true}',
        installedModulesPrefsKey: '["today","calendar","schedule","settings"]',
      });
      final r = await _container().read(installedModulesProvider.future);
      expect(r.cards, isEmpty);
    });

    test('손상된 저장값이면 기본 4탭으로 뜬다', () async {
      SharedPreferences.setMockInitialValues({
        installedModulesPrefsKey: 'not json',
      });
      final r = await _container().read(installedModulesProvider.future);
      expect(r.tabs.map((m) => m.id), [
        'today',
        'calendar',
        'schedule',
        'settings',
      ]);
    });
  });

  group('setEnabled', () {
    setUp(() => SharedPreferences.setMockInitialValues({
      installedModulesPrefsKey: '[]',
    }));

    test('탭형을 켜면 설정 바로 앞에 들어간다', () async {
      final c = _container();
      await c.read(installedModulesProvider.future);
      expect(
        await c.read(installedModulesProvider.notifier).setEnabled('t1', true),
        isTrue,
      );
      final ids = c.read(installedModulesProvider).requireValue.tabs
          .map((m) => m.id);
      expect(ids, ['today', 'calendar', 'schedule', 't1', 'settings']);
      expect(await _saved(), contains('t1'));
    });

    test('끄면 빠지고 저장된다', () async {
      final c = _container();
      await c.read(installedModulesProvider.future);
      final n = c.read(installedModulesProvider.notifier);
      await n.setEnabled(ModuleIds.bus, true);
      await n.setEnabled(ModuleIds.bus, false);
      expect(await _saved(), isNot(contains(ModuleIds.bus)));
    });

    test('고정 탭은 끌 수 없다', () async {
      final c = _container();
      await c.read(installedModulesProvider.future);
      expect(
        await c
            .read(installedModulesProvider.notifier)
            .setEnabled(ModuleIds.calendar, false),
        isFalse,
      );
      expect(
        c.read(installedModulesProvider).requireValue.ids,
        contains(ModuleIds.calendar),
      );
    });

    test('setEnabled는 상한을 넘기지 않는다 — UI가 아니어도', () async {
      final c = _container();
      await c.read(installedModulesProvider.future);
      final n = c.read(installedModulesProvider.notifier);
      await n.setEnabled('t1', true);
      await n.setEnabled('t2', true); // 6칸 가득
      expect(await n.setEnabled('t3', true), isFalse);
      expect(c.read(installedModulesProvider).requireValue.tabs, hasLength(6));
    });

    test('moduleInstalledProvider가 켜짐을 따라간다', () async {
      final c = _container();
      await c.read(installedModulesProvider.future);
      expect(c.read(moduleInstalledProvider(ModuleIds.bus)), isFalse);
      await c
          .read(installedModulesProvider.notifier)
          .setEnabled(ModuleIds.bus, true);
      expect(c.read(moduleInstalledProvider(ModuleIds.bus)), isTrue);
    });
  });

  group('reorderTabs', () {
    setUp(() => SharedPreferences.setMockInitialValues({
      installedModulesPrefsKey: '[]',
    }));

    test('아래로 옮기면 onReorder 규약대로 한 칸 당겨 넣는다', () async {
      final c = _container();
      await c.read(installedModulesProvider.future);
      // 오늘(0)을 입력(2) 뒤로: ReorderableListView는 newIndex=3을 준다
      await c.read(installedModulesProvider.notifier).reorderTabs(0, 3);
      expect(
        c.read(installedModulesProvider).requireValue.tabs.map((m) => m.id),
        ['calendar', 'schedule', 'today', 'settings'],
      );
    });

    test('옮긴 순서가 저장되고 설정은 여전히 맨 끝이다', () async {
      final c = _container();
      await c.read(installedModulesProvider.future);
      await c.read(installedModulesProvider.notifier).reorderTabs(2, 0);
      final saved = await _saved();
      expect(saved?.first, 'schedule');
      expect(
        c.read(installedModulesProvider).requireValue.tabs.last.id,
        ModuleIds.settings,
      );
    });
  });
}
