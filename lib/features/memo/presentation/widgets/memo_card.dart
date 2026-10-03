import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/memo.dart';
import '../../domain/memo_color.dart';

/// 쪽지 색 → 바탕. 위 글자는 ink·sub(대비 가드: memo_color_contrast_test).
Color memoFill(MemoColor c) => switch (c) {
  MemoColor.yellow => AppColors.memoYellow,
  MemoColor.green => AppColors.memoGreen,
  MemoColor.blue => AppColors.memoBlue,
  MemoColor.pink => AppColors.memoPink,
};

/// 보드의 쪽지 한 장. 글은 최대 5줄, 아래에 날짜(있으면 달력 아이콘 + 요일).
class MemoCard extends StatelessWidget {
  const MemoCard({super.key, required this.memo});

  final Memo memo;

  static Key cardKey(int id) => Key('memo_card_$id');

  @override
  Widget build(BuildContext context) {
    final date = memo.memoDate;
    final created = DateTime.tryParse(memo.createdAt ?? '');
    return Container(
      constraints: const BoxConstraints(minHeight: 132),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.spacing12,
        AppSizes.spacing12,
        AppSizes.spacing12,
        AppSizes.spacing8,
      ),
      decoration: BoxDecoration(
        color: memoFill(memo.color),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            memo.text,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              height: 1.45,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSizes.spacing8),
          if (date != null)
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: AppColors.ink,
                ),
                const SizedBox(width: AppSizes.spacing4),
                Flexible(
                  child: Text(
                    DateFormat('M.d (E)', 'ko').format(date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            )
          else if (created != null)
            Text(
              DateFormat('M.d').format(created),
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                color: AppColors.sub,
              ),
            ),
        ],
      ),
    );
  }
}
