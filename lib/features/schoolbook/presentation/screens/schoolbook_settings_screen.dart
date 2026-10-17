import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/schoolbook_providers.dart';
import '../widgets/schoolbook_connect_view.dart';

/// 장소 예약 상세 설정(`기능 관리 › 장소 예약 › 상세 설정`, 탭의 ⚙).
/// 켜고 끄는 스위치는 없다 — 기능 행에 하나뿐이다(설정 규칙).
class SchoolbookSettingsScreen extends ConsumerWidget {
  const SchoolbookSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(schoolbookSettingsProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(SchoolbookStrings.title, style: AppTextStyles.heading),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        children: [
          if (settings == null || !settings.connected) const SchoolbookConnectView()
          else ListTile(
            title: const Text(SchoolbookStrings.settingsSchool),
            trailing: Text(settings.schoolName ?? ''),
          ),
        ],
      ),
    );
  }
}
