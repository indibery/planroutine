import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/settings_providers.dart';
import '../widgets/app_info_list_tile.dart';
import '../widgets/export_list_tile.dart';
import '../widgets/google_account_list_tile.dart';
import '../widgets/import_list_tile.dart';
import '../widgets/notification_settings_tiles.dart';
import '../widgets/reset_list_tile.dart';
import '../widgets/settings_section.dart';
import '../widgets/trash_list_tile.dart';

/// 설정 화면 (하단 탭).
///
/// 각 섹션은 `features/settings/presentation/widgets/` 하위의 개별 위젯으로
/// 분리돼 있다. 이 화면은 섹션을 조합하고 reset 완료/실패 시 스낵바를 띄우는
/// 역할만 맡는다.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ResetState>(appResetProvider, (prev, next) {
      switch (next) {
        case ResetSuccess():
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              const SnackBar(content: Text(AppStrings.settingsResetAllDone)),
            );
        case ResetFailure(message: final msg):
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text('${AppStrings.settingsResetAllFailed}: $msg'),
                backgroundColor: AppColors.error,
              ),
            );
        case ResetIdle() || ResetInProgress():
          break;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.settingsTitle,
          style: AppTextStyles.heading,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSizes.spacing24),
        children: const [
          SettingsSection(
            title: AppStrings.settingsImportSection,
            subtitle: AppStrings.importDescription,
            child: ImportListTile(),
          ),
          SettingsSection(
            title: AppStrings.settingsExportSection,
            subtitle: AppStrings.settingsExportDescription,
            child: ExportListTile(),
          ),
          SettingsSection(
            title: AppStrings.settingsGoogleSection,
            subtitle: AppStrings.settingsGoogleSignInDescription,
            child: GoogleAccountListTile(),
          ),
          SettingsSection(
            title: AppStrings.settingsNotificationSection,
            subtitle: AppStrings.settingsNotificationMasterDescription,
            child: NotificationSettingsTiles(),
          ),
          SettingsSection(
            title: AppStrings.settingsTrashSection,
            subtitle: AppStrings.settingsTrashDescription,
            child: TrashListTile(),
          ),
          SettingsSection(
            title: AppStrings.settingsDataSection,
            child: ResetListTile(),
          ),
          SettingsSection(
            title: AppStrings.settingsAboutSection,
            showDivider: false,
            child: AppInfoListTile(),
          ),
          SizedBox(height: AppSizes.spacing24),
        ],
      ),
    );
  }
}
