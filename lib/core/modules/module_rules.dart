import 'dart:convert';

import 'app_module.dart';

/// 탭바에 들어가는 최대 칸 수. 320pt에서 6칸이면 한 칸이 53pt다.
const kMaxTabs = 6;

/// 저장값을 화면이 쓸 수 있는 형태로 정리한다. **저장값을 그대로 믿지 않는다.**
///
/// 규칙(스펙 "정리 규칙"):
/// 1. 고정 탭은 저장값에 없어도 포함한다 — 카탈로그 순서로 설정 앞에 붙는다.
/// 2. 설정은 항상 맨 끝이다.
/// 3. 등록부에 없는 id(사라진 기능)는 버린다.
/// 4. 중복 id는 첫 등장만 남긴다.
/// 5. 탭이 [kMaxTabs]를 넘으면 뒤쪽 선택 탭부터 잘라 낸다.
/// 6. 저장값이 null이면 고정 탭만 남는다.
ResolvedModules resolveModules(List<AppModule> catalog, List<String>? savedIds) {
  final byId = {for (final m in catalog) m.id: m};
  final seen = <String>{};
  final tabs = <AppModule>[];
  final cards = <AppModule>[];

  for (final id in savedIds ?? const <String>[]) {
    final module = byId[id];
    if (module == null || !seen.add(id)) continue;
    (module.placement == ModulePlacement.tab ? tabs : cards).add(module);
  }
  for (final module in catalog) {
    if (module.fixed && seen.add(module.id)) tabs.add(module);
  }

  final settings = tabs.firstWhere((m) => m.id == ModuleIds.settings);
  tabs.remove(settings);
  while (tabs.length + 1 > kMaxTabs) {
    final last = tabs.lastIndexWhere((m) => !m.fixed);
    if (last < 0) break;
    tabs.removeAt(last);
  }
  tabs.add(settings);

  return ResolvedModules(
    tabs: List.unmodifiable(tabs),
    cards: List.unmodifiable(cards),
  );
}

/// `installed_modules_v1`을 읽는다. 손상됐으면 null — 기본값으로 떨어진다.
List<String>? decodeModuleIds(String? raw) {
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    return decoded.whereType<String>().toList();
  } catch (_) {
    return null;
  }
}

/// 등록부 이전 전의 버스 켜짐(`bus_settings_v1`의 `enabled`)을 설치 목록으로 옮긴다.
///
/// `installed_modules_v1`이 없을 때 **한 번만** 부른다. 이 함수가 `enabled`를
/// 읽는 유일한 곳이다 — `BusSettings`에서는 그 필드가 사라졌다.
List<String> migrateLegacyModuleIds(String? busSettingsRaw) {
  if (busSettingsRaw == null) return const [];
  try {
    final decoded = jsonDecode(busSettingsRaw);
    if (decoded is Map && decoded['enabled'] == true) {
      return const [ModuleIds.bus];
    }
  } catch (_) {
    // 깨진 값이면 설치하지 않는다
  }
  return const [];
}
