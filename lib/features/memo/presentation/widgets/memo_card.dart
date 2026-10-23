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

/// 쪽지에 붙인 날짜를 길게 적는 형식(`10월 23일 (금)`) — 스크린리더 라벨과 쪽지 시트가 같이 쓴다.
final memoLongDate = DateFormat('M월 d일 (E)', 'ko');

/// 쪽지를 스크린리더·시뮬레이터 자동화가 읽을 라벨 — 글, 날짜가 붙어 있으면 그 날짜.

String memoCardSemanticsLabel(Memo memo) {
  final date = memo.memoDate;
  return [memo.text, if (date != null) memoLongDate.format(date)].join(', ');
}

/// 보드의 쪽지 한 장. 글은 최대 5줄, 붙인 날짜는 오른쪽 아래(달력 아이콘 + 요일).
/// 글이 남은 높이를 다 가져가므로 **높이가 정해진 부모**(보드 격자 칸) 안에 둔다.
class MemoCard extends StatelessWidget {
  const MemoCard({super.key, required this.memo});

  final Memo memo;

  static Key cardKey(int id) => Key('memo_card_$id');

  @override
  Widget build(BuildContext context) {
    final date = memo.memoDate;
    return Container(
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
        children: [
          // 칸 높이가 고정이라 큰 글자 설정에서는 남은 높이만큼만 그리고 말줄임한다.
          // 글이 남은 높이를 다 가져가 붙인 날짜는 늘 오른쪽 아래에 선다(실기기 피드백 2026-10-24).
          Expanded(
            child: Text(
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
          ),
          // 만든 날은 보이지 않는다 — 뜻이 없다(실기기 피드백 2026-10-24).
          if (date != null) ...[
            const SizedBox(height: AppSizes.spacing8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
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
            ),
          ],
        ],
      ),
    );
  }
}
