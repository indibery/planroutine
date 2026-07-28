import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';

/// `2개 더` — 상한(3개)에 걸려 감춘 노선 수. **두 본문 모양이 같은 위젯을 쓴다.**
///
/// 위젯으로 뽑아 둔 이유는 재사용이 아니라 **누락 방지**다. 이 표시가 `간단히`에만
/// 인라인으로 있던 동안 `시간 축`은 `hiddenCount`를 아예 참조하지 않아, 모양을 바꾼
/// 사용자에게 5노선 중 2개가 조용히 사라졌다 — 화면에는 점 3개뿐이라 사용자는 이
/// 정류장에 버스가 3대만 온다고 읽고, 자기 노선이 4·5번째면 "내 버스는 안 오네"로
/// 결론 낸다. 상한이 걸리는 조건(`routeIds`가 비어 있음)은 확인 시트의 **기본
/// 저장값**이라 예외 설정이 아니라 다수 경로다.
///
/// 스펙 §1은 "두 모양은 실패 계약·접기·시간대를 전부 공유한다. 다른 것은 본문
/// 렌더뿐"이라고 정했다 — 감춘 개수는 본문 렌더가 아니라 그 공유 목록에 속한다.
///
/// **골드를 쓰지 않는다.** 이 카드 안의 골드 텍스트는 전부 탭 대상이고
/// (`다시 시도`·`정류장 등록`·`퇴근 보기`) 이 줄은 정보 라벨이다. 골드로 두면
/// 눌러도 아무 일이 없는 링크처럼 보인다.
class BusMoreCount extends StatelessWidget {
  const BusMoreCount({super.key, required this.hiddenCount});

  final int hiddenCount;

  @override
  Widget build(BuildContext context) {
    return Text(
      BusStrings.moreCount(hiddenCount),
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.sub,
      ),
    );
  }
}
