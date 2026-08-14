import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/entry_kind.dart';

/// 업무 / 행사 배지 — 입력 탭 검토 목록과 캘린더 목록이 공유한다.
///
/// **색이 아니라 세기로 가른다**(2026-08-14). 라이트에서 둘 다 파랑 계열이라 서로
/// 1.39:1로 붙어 구별이 안 됐다(사용자 신고). 색을 하나 더 쓰는 대신 같은 파랑을
/// 채움/틴트 두 세기로 나눈다:
///
/// - **업무 = 채움**(불투명 + 대비색 글씨). 내가 처리할 일이고 오늘 탭의 주인공이라
///   강조를 가져간다.
/// - **행사 = 틴트**(15% + 진한 글씨). 학교에서 열리는 참고 정보라 물러난다.
///
/// **회색을 쓰지 않는 이유**: `작년` 배지(`event_list_section`)가 회색 테두리형이라
/// 한 행에 같이 뜬다. 색 축은 종류, 회색은 출처로 나눠 둔다.
/// 초록(`확정됨`)·골드(오늘·중요)도 이미 임자가 있어 쓰지 않는다.
///
/// `shared/widgets/`가 아니라 schedule feature에 두는 이유: 이 배지는 [EntryKind]에
/// 종속인데 `shared/widgets/` 아래 어떤 위젯도 `features/`를 import 하지 않는다.
/// 캘린더는 이미 schedule 도메인에 의존하므로(calendar_event.dart) 여기서 가져다 쓴다.
class KindBadge extends StatelessWidget {
  const KindBadge({super.key, required this.kind});

  final EntryKind kind;

  @override
  Widget build(BuildContext context) {
    final isTask = kind == EntryKind.task;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: isTask
            ? AppColors.kindTaskFill
            : AppColors.kindEvent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Text(
        kind.label,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 10,
          color: isTask ? AppColors.onKindTaskFill : AppColors.kindEvent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
