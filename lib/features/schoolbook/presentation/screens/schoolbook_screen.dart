import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/button_semantics.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/tab_header_title.dart';
import '../../domain/schoolbook_link.dart';
import '../providers/schoolbook_providers.dart';
import '../widgets/open_schoolbook_url.dart';
import '../widgets/schoolbook_connect_view.dart';
import 'schoolbook_day_body.dart';

/// 장소 예약 탭. 학교를 연결하기 전에는 연결 화면, 뒤에는 교실 하나 × 하루 보기(시안 B).
class SchoolbookScreen extends ConsumerWidget {
  const SchoolbookScreen({super.key, this.clock = DateTime.now});

  /// '오늘'을 정한다 — 테스트가 날짜를 고정하는 주입점.
  final DateTime Function() clock;

  static const settingsKey = Key('schoolbook_settings_shortcut');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(schoolbookSettingsProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const TabHeaderTitle(
          eyebrow: SchoolbookStrings.eyebrow,
          title: SchoolbookStrings.title,
        ),
        actions: [
          ButtonSemantics(
            key: settingsKey,
            label: SchoolbookStrings.settingsShortcut,
            onTap: () => context.push(AppRoutes.schoolbookSettings),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.push(AppRoutes.schoolbookSettings),
              child: const Padding(
                padding: EdgeInsets.all(AppSizes.spacing12),
                child: Icon(
                  Icons.settings_outlined,
                  semanticLabel: SchoolbookStrings.settingsShortcut,
                ),
              ),
            ),
          ),
        ],
      ),
      body: switch (settings) {
        null => const SizedBox.shrink(),
        final s when !s.connected => const _ConnectBody(),
        _ => SchoolbookDayBody(clock: clock),
      },
    );
  }
}

class _ConnectBody extends ConsumerWidget {
  const _ConnectBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pagePadding,
        vertical: AppSizes.spacing24,
      ),
      children: [
        // 처음 켠 사람이 실제로 마주치는 자리라 스쿨북 소개와 제작자를 여기 둔다
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.spacing16, AppSizes.spacing16, AppSizes.spacing16, AppSizes.spacing4,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSizes.radius14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                SchoolbookStrings.intro,
                style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.ink),
              ),
              TextButton(
                onPressed: () => openSchoolbookUrl(context, ref, schoolbookSiteUrl),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: const Text(SchoolbookStrings.openSite),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.spacing24),
        const EmptyState(
          icon: Icons.meeting_room_outlined,
          title: SchoolbookStrings.connectTitle,
          hint: SchoolbookStrings.connectHint,
        ),
        const SizedBox(height: AppSizes.spacing24),
        const SchoolbookConnectView(),
        const SizedBox(height: AppSizes.spacing24),
        // 학교가 아직 스쿨북을 쓰지 않는 선생님에게 시작하는 길
        Text(
          SchoolbookStrings.joinPrompt,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.sub),
        ),
        Center(
          child: TextButton(
            onPressed: () => openSchoolbookUrl(context, ref, schoolbookSiteUrl),
            child: const Text(SchoolbookStrings.joinAction),
          ),
        ),
      ],
    );
  }
}
