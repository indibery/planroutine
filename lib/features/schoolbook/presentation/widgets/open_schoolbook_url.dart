import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../providers/schoolbook_providers.dart';

/// 스쿨북 웹을 연다. 열지 못하면 알림 한 줄.
Future<void> openSchoolbookUrl(BuildContext context, WidgetRef ref, String url) async {
  // 시트에서 부르면 열린 뒤 시트가 닫힐 수 있다 — 알림 자리를 먼저 붙잡아 둔다
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(schoolbookUrlOpenerProvider)(url);
  } catch (_) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(
        content: Text(SchoolbookStrings.openFailed),
        behavior: SnackBarBehavior.floating,
      ));
  }
}
