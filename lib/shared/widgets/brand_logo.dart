import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 공직플랜 브랜드 로고 — LogoHybrid 스펙(수첩 바디 + 달력 그리드).
///
/// logos.jsx의 LogoHybrid (viewBox 120×120)를 그대로 Flutter로 이식. 골드만
/// 사용하며 배경은 투명하여, AppBar leading이나 온보딩 화면에서 앱 배경색 위에
/// 얹혀 보인다.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: const LogoHybridPainter(),
    );
  }
}

class LogoHybridPainter extends CustomPainter {
  const LogoHybridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // LogoHybrid는 120×120 viewBox 기준으로 설계됨.
    final u = size.width / 120;
    const gold = AppColors.gold;

    final goldFill = Paint()..color = gold;

    // 링 바인딩 3개 — 좌측에 수첩 구멍 느낌
    for (final y in const [34.0, 58.0, 82.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(22 * u, y * u, 8 * u, 5 * u),
          Radius.circular(1.5 * u),
        ),
        goldFill,
      );
    }

    // 바디 — 수첩 외곽선 (stroke only)
    final bodyStroke = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5 * u;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(30 * u, 22 * u, 68 * u, 80 * u),
        Radius.circular(6 * u),
      ),
      bodyStroke,
    );

    // 상단 헤더 바 — 상단 두 모서리만 라운드, 하단은 직각으로 바디 안쪽에 붙음
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        30 * u,
        22 * u,
        98 * u,
        36 * u,
        topLeft: Radius.circular(6 * u),
        topRight: Radius.circular(6 * u),
      ),
      goldFill,
    );

    // 미니 그리드 (4×3 점) — 가운데 오늘 표시는 크고 진하게, 나머지는 0.45 불투명
    for (var c = 0; c < 4; c++) {
      for (var r = 0; r < 3; r++) {
        final isToday = c == 2 && r == 1;
        final dot = Paint()
          ..color = isToday ? gold : gold.withValues(alpha: 0.45);
        canvas.drawCircle(
          Offset((42 + c * 13) * u, (54 + r * 13) * u),
          (isToday ? 4.0 : 2.2) * u,
          dot,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
