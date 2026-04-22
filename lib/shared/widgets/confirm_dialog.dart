import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';

/// 2-버튼 확인 다이얼로그 공통 위젯.
///
/// 반환값: 확인 버튼을 눌렀으면 true, 취소/바깥 탭하면 false.
/// 위험 액션(예: 초기화)은 [confirmColor]에 AppColors.error를 넘겨 버튼 강조.
class ConfirmDialog {
  ConfirmDialog._();

  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = AppStrings.cancel,
    Color? confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
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
