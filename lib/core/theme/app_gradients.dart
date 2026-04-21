import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppGradients {
  AppGradients._();

  static const gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.gold, AppColors.goldGlow],
  );

  static const navyCard = LinearGradient(
    begin: Alignment(-0.77, -0.64),
    end: Alignment(0.77, 0.64),
    colors: [AppColors.navyMid, AppColors.navySoft],
  );

  static const navySheet = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.navyMid, AppColors.navy],
  );

  static const progress = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.gold, AppColors.goldGlow],
  );
}
