import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _LogoMonthTabPainter(),
    );
  }
}

class _LogoMonthTabPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    const navy = AppColors.navyMid;
    const navyBack = AppColors.navySoft;
    const gold = AppColors.gold;

    final backTabPaint = Paint()..color = navyBack;
    final backTabPath = Path()
      ..moveTo(s * 0.18, s * 0.22)
      ..lineTo(s * 0.38, s * 0.22)
      ..lineTo(s * 0.38, s * 0.30)
      ..lineTo(s * 0.18, s * 0.30)
      ..close();
    canvas.drawPath(backTabPath, backTabPaint);

    final goldTabPaint = Paint()..color = gold;
    final goldTabPath = Path()
      ..moveTo(s * 0.34, s * 0.18)
      ..lineTo(s * 0.62, s * 0.18)
      ..quadraticBezierTo(s * 0.66, s * 0.18, s * 0.66, s * 0.22)
      ..lineTo(s * 0.66, s * 0.30)
      ..lineTo(s * 0.34, s * 0.30)
      ..close();
    canvas.drawPath(goldTabPath, goldTabPaint);

    final bodyPaint = Paint()..color = navy;
    final bodyRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.16, s * 0.30, s * 0.68, s * 0.54),
      Radius.circular(s * 0.04),
    );
    canvas.drawRRect(bodyRRect, bodyPaint);

    final dotPaint = Paint()..color = gold;
    const cols = 4;
    const rows = 3;
    final dotRadius = s * 0.022;
    final startX = s * 0.30;
    final startY = s * 0.46;
    final gap = s * 0.09;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final highlight = r == 1 && c == 1;
        dotPaint.color = highlight
            ? AppColors.gold
            : AppColors.gold.withValues(alpha: 0.5);
        canvas.drawCircle(
          Offset(startX + c * gap, startY + r * gap),
          dotRadius,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
