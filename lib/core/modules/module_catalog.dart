import 'package:flutter/material.dart';

import '../../features/bus/presentation/widgets/bus_card_host.dart';
import '../../features/bus/presentation/widgets/bus_module_summary.dart';
import '../constants/app_strings.dart';
import '../router/app_router.dart';
import 'app_module.dart';

const todayTab = ModuleTab(
  route: AppRoutes.today,
  icon: Icons.check_circle_outline,
  activeIcon: Icons.check_circle,
  label: AppStrings.tabToday,
);

const calendarTab = ModuleTab(
  route: AppRoutes.calendar,
  icon: Icons.calendar_month_outlined,
  activeIcon: Icons.calendar_month,
  label: AppStrings.tabCalendar,
);

const scheduleTab = ModuleTab(
  route: AppRoutes.schedule,
  // 이 탭의 주 동작은 검토가 아니라 넣기 — 체크리스트 아이콘은 어긋난다.
  icon: Icons.note_add_outlined,
  activeIcon: Icons.note_add,
  label: AppStrings.tabSchedule,
);

const settingsTab = ModuleTab(
  route: AppRoutes.settings,
  icon: Icons.settings_outlined,
  activeIcon: Icons.settings,
  label: SettingsStrings.title,
);

/// 등록부가 아직 로딩 중일 때와 `MainShell`의 기본값.
const defaultTabs = [todayTab, calendarTab, scheduleTab, settingsTab];

/// 기능 등록부. **새 기능은 여기에 한 항목만 더한다.**
///
/// 탭형 기능의 라우트는 설치 여부와 무관하게 `app_router.dart`에 항상 등록한다
/// (`module_catalog_test.dart`가 지킨다).
const moduleCatalog = <AppModule>[
  AppModule(
    id: ModuleIds.today,
    name: AppStrings.tabToday,
    icon: Icons.check_circle_outline,
    placement: ModulePlacement.tab,
    fixed: true,
    tab: todayTab,
  ),
  AppModule(
    id: ModuleIds.calendar,
    name: AppStrings.tabCalendar,
    icon: Icons.calendar_month_outlined,
    placement: ModulePlacement.tab,
    fixed: true,
    tab: calendarTab,
  ),
  AppModule(
    id: ModuleIds.schedule,
    name: AppStrings.tabSchedule,
    icon: Icons.note_add_outlined,
    placement: ModulePlacement.tab,
    fixed: true,
    tab: scheduleTab,
  ),
  AppModule(
    id: ModuleIds.settings,
    name: SettingsStrings.title,
    icon: Icons.settings_outlined,
    placement: ModulePlacement.tab,
    fixed: true,
    tab: settingsTab,
  ),
  AppModule(
    id: ModuleIds.bus,
    name: BusStrings.moduleName,
    description: BusStrings.moduleDescription,
    icon: Icons.directions_bus_outlined,
    placement: ModulePlacement.todayCard,
    card: BusCardHost(),
    settingsRoute: AppRoutes.busSettings,
    settingsSummary: BusModuleSummary(),
  ),
];
