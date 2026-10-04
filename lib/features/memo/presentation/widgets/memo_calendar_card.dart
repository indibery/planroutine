import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/memo.dart';
import 'memo_card.dart';
import '../../../../shared/widgets/button_semantics.dart';

/// 캘린더 목록의 쪽지 — 흰 일정 카드와 갈리게 쪽지 색 바탕. **스와이프 없음**(일정의 동작이다).
class MemoCalendarCard extends StatelessWidget {
  const MemoCalendarCard({super.key, required this.memo, this.onTap});

  final Memo memo;
  final VoidCallback? onTap;

  static Key cardKey(int id) => Key('memo_calendar_card_$id');

  @override
  Widget build(BuildContext context) {
    final id = memo.id;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing4,
      ),
      child: Material(
        color: memoFill(memo.color),
        borderRadius: BorderRadius.circular(4),
        // 버튼으로 읽히게 한 노드로 묶는다 — `InkWell`은 탭 동작만 주고 버튼 표시를 안 붙인다.
        child: ButtonSemantics(
          label: '${memo.text}, ${MemoStrings.calendarBadge}',
          onTap: onTap,
          child: InkWell(
            key: id == null ? null : cardKey(id),
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.spacing12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.sticky_note_2_outlined,
                    size: 16,
                    color: AppColors.ink,
                  ),
                  const SizedBox(width: AppSizes.spacing8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          memo.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          MemoStrings.calendarBadge,
                          style: TextStyle(fontSize: 12, color: AppColors.sub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
