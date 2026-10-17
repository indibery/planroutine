import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/button_semantics.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/tab_header_title.dart';
import '../providers/schoolbook_providers.dart';
import '../widgets/schoolbook_connect_view.dart';

/// 장소 예약 탭. 학교를 연결하기 전에는 연결 화면, 뒤에는 교실 하나 × 하루 보기(시안 B).
class SchoolbookScreen extends ConsumerWidget {
  const SchoolbookScreen({super.key});

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
        final s => Center(child: Text(s.schoolName ?? '')),
      },
    );
  }
}

class _ConnectBody extends StatelessWidget {
  const _ConnectBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pagePadding,
        vertical: AppSizes.spacing32,
      ),
      children: const [
        EmptyState(
          icon: Icons.meeting_room_outlined,
          title: SchoolbookStrings.connectTitle,
          hint: SchoolbookStrings.connectHint,
        ),
        SizedBox(height: AppSizes.spacing24),
        SchoolbookConnectView(),
      ],
    );
  }
}
