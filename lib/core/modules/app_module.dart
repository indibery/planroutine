import 'package:flutter/widgets.dart';

/// 기능 id — **저장값이다.** 한번 배포하면 바꾸거나 지우지 않는다.
///
/// `*Strings`에 두지 않는 이유는 Android 알림 채널 id와 같다: UI 문자열이
/// 아니라 사용자 기기에 저장되는 키라, 바꾸면 그 기능을 켜 둔 사용자의 설정이
/// 조용히 꺼진다. `module_catalog_test.dart`가 배포한 id 목록을 지킨다.
abstract final class ModuleIds {
  static const today = 'today';
  static const calendar = 'calendar';
  static const schedule = 'schedule';
  static const settings = 'settings';
  static const bus = 'bus';
}

/// 기능이 화면에 들어오는 자리. 한 기능은 하나의 자리만 갖는다.
enum ModulePlacement { tab, todayCard }

/// 탭바 한 칸. `MainShell`이 그린다.
class ModuleTab {
  const ModuleTab({
    required this.route,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final String route;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// 등록부의 한 항목. 새 기능을 만들면 `moduleCatalog`에 이것 하나를 더한다.
class AppModule {
  const AppModule({
    required this.id,
    required this.name,
    required this.icon,
    required this.placement,
    this.description = '',
    this.fixed = false,
    this.tab,
    this.card,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final ModulePlacement placement;

  /// 숨길 수 없는 기능. 순서는 바꿀 수 있다.
  final bool fixed;

  /// [placement]가 tab일 때만 있다.
  final ModuleTab? tab;

  /// [placement]가 todayCard일 때만 있다. 오늘 탭 맨 위에 놓인다.
  final Widget? card;
}

/// [resolveModules]가 정리한 결과. 화면은 저장값이 아니라 이것만 본다.
class ResolvedModules {
  const ResolvedModules({required this.tabs, required this.cards});

  /// 탭 순서대로. 설정이 항상 맨 끝이다.
  final List<AppModule> tabs;

  /// 오늘 탭 카드. 켠 순서대로.
  final List<AppModule> cards;

  /// 저장할 id 목록 — 탭 다음 카드.
  List<String> get ids => [
    for (final m in tabs) m.id,
    for (final m in cards) m.id,
  ];
}
