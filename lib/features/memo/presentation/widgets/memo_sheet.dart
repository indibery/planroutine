import 'package:flutter/material.dart';

import '../../domain/memo.dart';

/// 쪽지 시트. Task 5가 내용을 채운다.
class MemoSheet extends StatelessWidget {
  const MemoSheet({super.key, required this.memo});

  final Memo memo;

  static Future<void> show(BuildContext context, Memo memo) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        builder: (_) => MemoSheet(memo: memo),
      );

  @override
  Widget build(BuildContext context) => const SizedBox(height: 200);
}
