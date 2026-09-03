import 'package:flutter/material.dart';

import '../core/constants/app_sizes.dart';

/// 입력 탭 스낵바를 **하단 일괄 확정 바 위로** 띄운다.
///
/// 기본값(`SnackBarBehavior.fixed`)이 앉는 자리가 정확히 그 pill이라, 스낵바가
/// 떠 있는 4초 동안 확정을 누를 수 없다(사용자 신고 2026-08-14).
///
/// ⚠️ **이 헬퍼가 `shared/`에 있는 이유가 그 신고의 재발이다.** 처음 고칠 때는
/// 같은 코드를 `ai_photo_flow.dart`의 private 함수로 뒀는데, 다른 호출부가 쓸 수
/// 없어 **두 곳이 맨 `SnackBar`를 만든 채 남았다** — CSV 등록 완료와 ← 스와이프
/// 삭제 되돌리기. 사용자가 2026-09-03에 그중 하나를 다시 신고했다.
/// 뒤쪽이 더 나빴다: `되돌리기` 액션이 가려지면 **되돌릴 방법 자체가 없다.**
///
/// 그래서 고친 것은 두 번째 호출부가 아니라 **재사용 불가라는 구조**다.
/// 입력 탭에서 스낵바를 띄우는 모든 경로가 이 함수를 쓴다.
///
/// 전역 `snackBarTheme`으로 올리지 않는다 — 이 앱의 다른 스낵바 스무 곳이 함께
/// 바뀐다. 아래 여백은 `AppSizes.bulkRegisterBarHeight`에서 **파생**된다(숫자를
/// 여기 박으면 pill 높이를 바꿀 때 조용히 어긋난다).
///
/// 가드: `test/shared/bulk_bar_snack_test.dart`.
void showBulkBarSnack(
  BuildContext context,
  String message, {
  SnackBarAction? action,
}) => showBulkBarSnackWith(
  ScaffoldMessenger.of(context),
  message,
  action: action,
);

/// messenger를 **미리 붙잡아 둔** 경우용.
///
/// `/import`는 등록이 끝나면 `pop()`으로 스스로 사라지면서 스낵바를 띄운다 —
/// pop 뒤에는 그 `context`로 `ScaffoldMessenger.of`를 부를 수 없어, 화면을 닫기
/// **전에** messenger를 받아 둔다. 그 경로가 이 변종을 쓴다.
void showBulkBarSnackWith(
  ScaffoldMessengerState messenger,
  String message, {
  SnackBarAction? action,
}) {
  messenger
    // 두 줄이 쌓이면 여백을 줘도 위쪽 줄이 pill을 덮는다.
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(
          AppSizes.spacing8,
          0,
          AppSizes.spacing8,
          AppSizes.bulkRegisterBarHeight,
        ),
      ),
    );
}
