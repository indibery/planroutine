import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';

/// 2-버튼 확인 다이얼로그 공통 위젯.
///
/// 반환값: 확인 버튼을 눌렀으면 true, 취소/바깥 탭하면 false.
/// 위험 액션(예: 초기화)은 [confirmColor]에 AppColors.error를 넘겨 버튼 강조.
/// 지도 기록 화면에서는 `useRootNavigator: false`로 부른다 — 루트에 뜨면 잠금 덮개 **위**에 남는다.
class ConfirmDialog {
  ConfirmDialog._();

  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = AppStrings.cancel,
    Color? confirmColor,
    bool useRootNavigator = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: useRootNavigator,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: confirmColor != null
                  ? TextStyle(color: confirmColor)
                  : null,
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
