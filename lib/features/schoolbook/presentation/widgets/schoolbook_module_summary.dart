import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../providers/schoolbook_providers.dart';

/// 기능 관리 `상세 설정` 줄 오른쪽 — 연결된 학교 이름. 글자 모양은 기능 관리 화면이 정한다.
class SchoolbookModuleSummary extends ConsumerWidget {
  const SchoolbookModuleSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(schoolbookSettingsProvider).valueOrNull?.schoolName;
    return Text(name ?? SchoolbookStrings.summaryNotConnected);
  }
}
