// test/core/modules/module_catalog_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planroutine/core/modules/app_module.dart';
import 'package:planroutine/core/modules/module_catalog.dart';
import 'package:planroutine/core/router/app_router.dart';

/// **배포한 id 목록.** 여기서 지우려면 이유를 함께 적는다.
///
/// id는 사용자 기기의 저장값이다. 이름을 바꾸거나 지우면 그 기능을 켜 둔
/// 사용자의 설정이 오류도 없이 꺼진다(`resolveModules`가 모르는 id를 버린다).
const _shippedIds = [
  ModuleIds.today,
  ModuleIds.calendar,
  ModuleIds.schedule,
  ModuleIds.settings,
  ModuleIds.bus,
];

List<String> _paths(List<RouteBase> routes) => [
  for (final r in routes) ...[if (r is GoRoute) r.path, ..._paths(r.routes)],
];

void main() {
  test('id가 겹치지 않는다', () {
    final ids = moduleCatalog.map((m) => m.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('배포한 id가 등록부에 모두 남아 있다', () {
    final ids = moduleCatalog.map((m) => m.id).toSet();
    for (final id in _shippedIds) {
      expect(ids, contains(id), reason: '$id를 지우면 켜 둔 사용자의 설정이 조용히 꺼진다');
    }
  });

  test('고정 기능은 정확히 오늘·캘린더·입력·설정이다', () {
    expect(moduleCatalog.where((m) => m.fixed).map((m) => m.id).toSet(), {
      ModuleIds.today,
      ModuleIds.calendar,
      ModuleIds.schedule,
      ModuleIds.settings,
    });
  });

  test('자리와 그 자리의 재료가 짝이 맞는다', () {
    for (final m in moduleCatalog) {
      final isTab = m.placement == ModulePlacement.tab;
      expect(m.tab != null, isTab, reason: '${m.id}: tab');
      expect(m.card != null, !isTab, reason: '${m.id}: card');
    }
  });

  test('탭형 기능의 라우트는 설치 여부와 무관하게 라우터에 있다', () {
    final paths = _paths(
      createRouter(onboardingDone: true).configuration.routes,
    );
    for (final m in moduleCatalog) {
      final route = m.tab?.route;
      if (route == null) continue;
      expect(
        paths,
        contains(route),
        reason: '${m.id}의 라우트가 없으면 Page Not Found',
      );
    }
  });

  test('상세 설정 경로는 설치 여부와 무관하게 라우터에 있다', () {
    final paths = _paths(
      createRouter(onboardingDone: true).configuration.routes,
    );
    final routes = [
      for (final m in moduleCatalog) ?m.settingsRoute,
    ];
    // 버스가 상세를 가지므로 비면 안 된다 — 비면 아래 루프가 아무것도 검사하지 않는다.
    expect(routes, isNotEmpty);
    for (final route in routes) {
      expect(
        paths,
        contains(route),
        reason: '$route가 없으면 ›를 눌렀을 때 Page Not Found',
      );
    }
  });

  test('고정 기능은 상세 경로를 갖지 않는다 — 고정 탭의 설정은 설정 탭에 있다', () {
    for (final m in moduleCatalog.where((m) => m.fixed)) {
      expect(m.settingsRoute, isNull, reason: m.id);
      expect(m.settingsSummary, isNull, reason: m.id);
    }
  });

  test('선택 기능은 설명을 갖는다 — 기능 관리 화면에 빈 줄이 뜨지 않게', () {
    for (final m in moduleCatalog.where((m) => !m.fixed)) {
      expect(m.description, isNotEmpty, reason: m.id);
    }
  });
}
