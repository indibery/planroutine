import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/arrival_text.dart';

/// 임박도 칸 → 신호색. **두 본문 모양과 범례가 같은 함수를 쓴다.**
Color busSignalColor(BusSignal signal) => switch (signal) {
  BusSignal.near => AppColors.busSignalNear,
  BusSignal.soon => AppColors.busSignalSoon,
  BusSignal.far => AppColors.busSignalFar,
};
