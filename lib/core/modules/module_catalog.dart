import 'package:flutter/material.dart';

import '../../features/bus/presentation/widgets/bus_card_host.dart';
import '../../features/bus/presentation/widgets/bus_module_summary.dart';
import '../constants/app_strings.dart';
import '../router/app_router.dart';
import 'app_module.dart';
import 'fixed_tabs.dart';

export 'fixed_tabs.dart';

const memoTab = ModuleTab(
  route: AppRoutes.memo,
  icon: Icons.sticky_note_2_outlined,
  activeIcon: Icons.sticky_note_2,
  label: MemoStrings.tabLabel,
);

const guidanceTab = ModuleTab(
  route: AppRoutes.guidance,
  icon: Icons.lock_outline,
  activeIcon: Icons.lock,
  label: GuidanceStrings.tabLabel,
);

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
  AppModule(
    id: ModuleIds.memo,
    name: MemoStrings.title,
    description: MemoStrings.moduleDescription,
    icon: Icons.sticky_note_2_outlined,
    placement: ModulePlacement.tab,
    tab: memoTab,
  ),
  AppModule(
    id: ModuleIds.guidance,
    name: GuidanceStrings.title,
    description: GuidanceStrings.moduleDescription,
    icon: Icons.lock_outline,
    placement: ModulePlacement.tab,
    tab: guidanceTab,
  ),
];
