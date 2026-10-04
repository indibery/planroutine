// lib/features/settings/presentation/screens/modules_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/modules/app_module.dart';
import '../../../../core/modules/installed_modules_provider.dart';
import '../../../../core/modules/module_rules.dart';
import '../../../../core/theme/app_text_styles.dart';

/// `설정 › 기능 관리` — 선택 기능을 켜고 끄고, 탭 순서를 바꾼다.
///
/// **켜고 꺼도 항목이 자리를 옮기지 않는다.** 아래 `기능` 목록은 켜짐과 무관하게
/// 등록부 순서 그대로다 — 버튼으로 "추가"하면 항목이 위 섹션으로 옮겨 가 누른
/// 자리에서 사라진다(오늘 탭 완료 토글을 재정렬하지 않는 것과 같은 원칙).
/// 끄더라도 데이터는 남으므로 확인 다이얼로그가 없다.
///
/// **켜진 기능의 상세 설정은 여기서만 연다**(2026-10-03 설계). 기능 행은 행 전체가
/// 스위치이고, 켜져 있으면 그 아래 `상세 설정 … ›` 줄이 따로 붙는다. 두 버튼이 한 줄에
/// 붙어 있으면 켜려다 상세로, 상세로 가려다 끄게 된다(사용자 지적). 설정 탭에는 기능별 행이 없다.
class ModulesScreen extends ConsumerWidget {
  const ModulesScreen({super.key});

  static Key switchKey(String id) => Key('module_switch_$id');
  static Key tabRowKey(String id) => Key('module_tab_$id');
  static const lockIconKey = Key('module_lock');
  static Key settingsKey(String id) => Key('module_settings_$id');
  static Key chevronKey(String id) => Key('module_chevron_$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(moduleCatalogProvider);
    final resolved =
        ref.watch(installedModulesProvider).valueOrNull ??
        resolveModules(catalog, null);
    final notifier = ref.read(installedModulesProvider.notifier);

    final movable = [
      for (final m in resolved.tabs)
        if (m.id != ModuleIds.settings) m,
    ];
    final settings = resolved.tabs.last;
    final optional = [
      for (final m in catalog)
        if (!m.fixed) m,
    ];
    final tabsFull = resolved.tabs.length >= kMaxTabs;
    final installedIds = resolved.ids.toSet();

    return Scaffold(
      appBar: AppBar(
        title: Text(SettingsStrings.modulesTitle, style: AppTextStyles.heading),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSizes.spacing24),
        children: [
          _header(
            SettingsStrings.modulesMyTabs,
            trailing: SettingsStrings.modulesTabCount(
              resolved.tabs.length,
              kMaxTabs,
            ),
          ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            // reorderTabs는 onReorderItem 규약(newIndex가 이미 보정됨)을 받는다.
            onReorderItem: notifier.reorderTabs,
            children: [
              for (final (i, m) in movable.indexed)
                ListTile(
                  key: tabRowKey(m.id),
                  leading: ReorderableDragStartListener(
                    index: i,
                    child: Icon(Icons.drag_handle, color: AppColors.sub),
                  ),
                  title: Text(m.name),
                  trailing: m.fixed ? _lock() : null,
                ),
            ],
          ),
          // 설정은 드래그 목록 밖에 둔다 — 늘 맨 끝이라 옮길 수 없다.
          ListTile(
            key: tabRowKey(settings.id),
            leading: const SizedBox(width: 24),
            title: Text(settings.name),
            trailing: _lock(),
          ),
          const Divider(),
          _header(SettingsStrings.modulesFeatures),
          if (optional.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              child: Text(
                SettingsStrings.modulesEmpty,
                style: TextStyle(color: AppColors.sub),
              ),
            ),
          for (final m in optional)
            _moduleTile(
              context,
              m,
              installed: installedIds.contains(m.id),
              blocked:
                  tabsFull &&
                  m.placement == ModulePlacement.tab &&
                  !installedIds.contains(m.id),
              onChanged: (v) => notifier.setEnabled(m.id, v),
            ),
        ],
      ),
    );
  }

  Widget _lock() => Icon(
    Icons.lock_outline,
    key: lockIconKey,
    size: 18,
    color: AppColors.faint,
  );

  Widget _header(String title, {String? trailing}) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSizes.pagePadding,
      AppSizes.spacing16,
      AppSizes.pagePadding,
      AppSizes.spacing4,
    ),
    child: Row(
      children: [
        Expanded(child: Text(title, style: AppTextStyles.eyebrow)),
        if (trailing != null)
          Text(trailing, style: TextStyle(fontSize: 14, color: AppColors.sub)),
      ],
    ),
  );

  /// 스위치에 `activeThumbColor`를 주지 않는다 — 전역 `switchTheme` 색 가드.
  ///
  /// 기능 행(행 전체가 스위치)과 상세 설정 줄이 **위아래로 갈린다.** 행의 부제는 늘
  /// 기능 설명이라 켜고 꺼도 행 높이가 변하지 않고, 상세 설정 줄은 그 아래에 붙으므로
  /// 누른 스위치가 움직이지 않는다.
  Widget _moduleTile(
    BuildContext context,
    AppModule m, {
    required bool installed,
    required bool blocked,
    required ValueChanged<bool> onChanged,
  }) {
    final placement = m.placement == ModulePlacement.tab
        ? SettingsStrings.placementTab
        : SettingsStrings.placementTodayCard;
    // 꺼져 있으면 상세로 가지 않는다 — 꺼진 기능의 설정을 고칠 이유가 없다.
    final route = installed ? m.settingsRoute : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          key: switchKey(m.id),
          secondary: Icon(m.icon, color: AppColors.primary),
          title: Text(m.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$placement · ${m.description}'),
              if (blocked) Text(SettingsStrings.modulesTabsFull(kMaxTabs)),
            ],
          ),
          isThreeLine: blocked,
          value: installed,
          onChanged: blocked ? null : onChanged,
        ),
        if (route != null)
          // 자기 노드를 갖게 한다. `ListTile`은 스스로 노드를 만들지 않아 위 스위치 줄과 한 항목에
          // 있으면 버튼 표시가 항목 전체로 올라가 스위치 줄을 품었다(button_node_nesting_test).
          Semantics(
            container: true,
            child: ListTile(
              key: settingsKey(m.id),
              // 기능 행의 글자 줄에 맞춰 들여 쓴다 — 이 줄이 위 기능에 속한다는 표시.
              contentPadding: const EdgeInsets.only(
                left: AppSizes.moduleSettingsIndent,
                right: AppSizes.pagePadding,
              ),
              dense: true,
              title: const Text(SettingsStrings.moduleSettings),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (m.settingsSummary case final summary?)
                    DefaultTextStyle.merge(
                      style: TextStyle(fontSize: 14, color: AppColors.sub),
                      child: summary,
                    ),
                  const SizedBox(width: AppSizes.spacing4),
                  Icon(Icons.chevron_right, key: chevronKey(m.id)),
                ],
              ),
              onTap: () => context.push(route),
            ),
          ),
      ],
    );
  }
}
