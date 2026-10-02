import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/bus/presentation/providers/bus_providers.dart';
import 'app_module.dart';
import 'module_catalog.dart';
import 'module_rules.dart';

const installedModulesPrefsKey = 'installed_modules_v1';

/// 등록부. 테스트가 탭형 테스트용 기능을 주입하려고 provider로 감싼다.
final moduleCatalogProvider = Provider<List<AppModule>>((ref) => moduleCatalog);

/// 설치된 기능과 탭 순서 — **켜짐 여부의 유일한 주인.**
final installedModulesProvider =
    AsyncNotifierProvider<InstalledModulesNotifier, ResolvedModules>(
      InstalledModulesNotifier.new,
    );

/// 이 기능이 켜져 있는가. 로딩 중에는 false.
final moduleInstalledProvider = Provider.family<bool, String>((ref, id) {
  final resolved = ref.watch(installedModulesProvider).valueOrNull;
  return resolved?.ids.contains(id) ?? false;
});

class InstalledModulesNotifier extends AsyncNotifier<ResolvedModules> {
  List<AppModule> get _catalog => ref.read(moduleCatalogProvider);

  @override
  Future<ResolvedModules> build() async {
    final catalog = ref.watch(moduleCatalogProvider);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(installedModulesPrefsKey);
    if (raw != null) return resolveModules(catalog, decodeModuleIds(raw));

    // **키가 없을 때 한 번만** 이전한다. 판정 기준이 "키가 있는가" 하나라 같은
    // 사용자를 두 번 이전하지 않는다. `_save`를 쓰지 않는다 — build 중에는
    // state를 대입할 수 없다(반환값이 곧 state).
    final migrated = resolveModules(
      catalog,
      migrateLegacyModuleIds(prefs.getString(busSettingsPrefsKey)),
    );
    await prefs.setString(installedModulesPrefsKey, jsonEncode(migrated.ids));
    return migrated;
  }

  /// 켜기·끄기. **거부하면 false** — 고정 탭을 끄려 하거나 탭이 가득 찼을 때.
  ///
  /// 상한을 여기서도 검사한다. 화면이 스위치를 막는 것만으로는 다른 호출부가
  /// 생겼을 때 7번째 탭이 저장된다.
  Future<bool> setEnabled(String id, bool on) async {
    final current = await future;
    final module = _catalog.where((m) => m.id == id).firstOrNull;
    if (module == null || module.fixed) return false;

    final ids = current.ids.where((x) => x != id).toList();
    if (on) {
      if (module.placement == ModulePlacement.tab) {
        if (current.tabs.length >= kMaxTabs) return false;
        ids.insert(ids.indexOf(ModuleIds.settings), id);
      } else {
        ids.add(id);
      }
    }
    await _save(resolveModules(_catalog, ids));
    return true;
  }

  /// 설정을 뺀 탭 목록에서 순서를 바꾼다. `ReorderableListView.onReorder` 규약이라
  /// 아래로 옮길 때 [newIndex]가 한 칸 크게 온다.
  Future<void> reorderTabs(int oldIndex, int newIndex) async {
    final current = await future;
    final movable = [
      for (final m in current.tabs)
        if (m.id != ModuleIds.settings) m.id,
    ];
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    movable.insert(target, movable.removeAt(oldIndex));
    await _save(
      resolveModules(_catalog, [
        ...movable,
        ModuleIds.settings,
        for (final m in current.cards) m.id,
      ]),
    );
  }

  Future<void> _save(ResolvedModules next) async {
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(installedModulesPrefsKey, jsonEncode(next.ids));
  }
}
