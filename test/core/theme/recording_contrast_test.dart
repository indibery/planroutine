import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';

import '../../helpers/contrast.dart';

void main() {
  tearDown(() => AppColors.applyBrightness(Brightness.dark));

  for (final b in Brightness.values) {
    test('$b: 녹음 화면의 글자·녹음 중 표시가 4.5:1 이상', () {
      AppColors.applyBrightness(b);
      expect(contrastRatio(AppColors.onRecording, AppColors.recordingBackground), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(AppColors.recordingLive, AppColors.recordingBackground), greaterThanOrEqualTo(4.5));
    });
  }
}
