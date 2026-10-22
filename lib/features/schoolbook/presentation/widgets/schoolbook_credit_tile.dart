import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/gold_gradient_button.dart';
import '../../../../shared/widgets/sheet_title.dart';
import '../../domain/schoolbook_link.dart';
import 'open_schoolbook_url.dart';

/// 설정 › `함께 만든 서비스` — 장소 예약이 기대는 스쿨북과 그 제작자에게 고마움을 남기는 행.
///
/// 공공데이터 [DataSourceListTile]과 따로 둔다 — 그쪽은 라이선스 의무 표시이고, 이쪽은
/// 제작자의 허락과 협조로 붙인 서비스다. 기능을 꺼도 보인다(감사는 켜짐과 무관하다).
class SchoolbookCreditTile extends StatelessWidget {
  const SchoolbookCreditTile({super.key});

  static const openSiteKey = Key('schoolbook_credit_open_site');

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.handshake_outlined, color: AppColors.textSecondary),
      title: const Text(SchoolbookStrings.creditTitle),
      subtitle: const Text(SchoolbookStrings.creditSubtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radius18)),
        ),
        builder: (_) => const _CreditSheet(),
      ),
    );
  }
}

class _CreditSheet extends ConsumerWidget {
  const _CreditSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding,
          AppSizes.spacing12,
          AppSizes.pagePadding,
          AppSizes.spacing24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.faint,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.spacing16),
            const SheetTitle(SchoolbookStrings.creditTitle),
            const SizedBox(height: AppSizes.spacing12),
            _Card(children: [
              Text(
                SchoolbookStrings.creditService,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              const SizedBox(height: AppSizes.spacing4),
              Text(SchoolbookStrings.creditMaker, style: TextStyle(fontSize: 14, color: AppColors.ink)),
              Text(schoolbookHost, style: TextStyle(fontSize: 13, color: AppColors.sub)),
            ]),
            const SizedBox(height: AppSizes.spacing12),
            _Card(children: [
              Text(
                SchoolbookStrings.creditThanks,
                style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.ink),
              ),
            ]),
            const SizedBox(height: AppSizes.spacing12),
            Text(
              SchoolbookStrings.creditContact,
              style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.sub),
            ),
            const SizedBox(height: AppSizes.spacing16),
            Center(
              child: GoldGradientButton(
                key: SchoolbookCreditTile.openSiteKey,
                label: SchoolbookStrings.openSite,
                onPressed: () => openSchoolbookUrl(context, ref, schoolbookSiteUrl),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSizes.radius14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}
