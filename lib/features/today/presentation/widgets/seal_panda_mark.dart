import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 완료 도장 안에 찍히는 판다 얼굴.
///
/// **왜 직접 그리나**: Material Icons에 판다가 없고, 이모지 `🐼`는 색을 입힐 수 없어
/// 도장의 골드 단색 언어를 깨뜨린다(도장은 테마에 따라 색이 바뀐다).
///
/// **비율은 실제 판다 일러스트에서 가져왔다**(사용자 참조 이미지 2026-07-29):
/// 얼굴이 **가로로 넓고**(폭 16.4 / 높이 14.8), 귀가 머리 위로 **솟아** 있고, 눈 패치가
/// 크고 안쪽으로 기울었다. 처음 시도한 안은 얼굴이 세로로 길어(폭 11.6 / 높이 15.7)
/// 곰·원숭이로 읽혔고, 귀 원 안으로 얼굴 윤곽선이 지나가 확대하면 선이 그어져 보였다.
///
/// **음각(얼굴을 채우고 눈을 파냄)은 쓸 수 없다.** 판다의 정체는 **검은 눈 패치**인데
/// 파내면 그 자리가 밝아져 특징이 정확히 반대로 뒤집힌다 — 판다가 아니라 곰돌이가 된다.
/// 발바닥·엄지처럼 실루엣으로 정의되는 것은 음각이 되지만 판다는 안 된다.
///
/// **입은 넣지 않는다.** `w` 모양 입을 넣어 봤더니 8배 확대에서는 귀엽지만 실제 크기
/// (마크 22px)에서 눈동자와 뭉쳐 지저분했다.
class SealPandaMark extends StatelessWidget {
  const SealPandaMark({super.key, required this.color});

  final Color color;

  /// 마크가 차지하는 한 변. `CompletionSeal.innerWidth`(31.4)보다 작아야 한다 —
  /// 가드 테스트가 지킨다.
  static const size = 22.0;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(size),
      painter: _PandaPainter(color),
    );
  }
}

class _PandaPainter extends CustomPainter {
  const _PandaPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;

    // 눈동자를 **파내야** 하므로 레이어가 필요하다 — `BlendMode.clear`는 레이어 안에서만
    // 아래 칠을 지운다. 레이어 없이 쓰면 도장 테두리까지 지워진다.
    canvas.saveLayer(
      const Rect.fromLTWH(-2, -2, SealPandaMark.size + 4, SealPandaMark.size + 4),
      Paint(),
    );

    // 귀 — 얼굴보다 **먼저** 그려 윤곽선이 귀 위에 얹히지 않게 한다.
    canvas.drawCircle(const Offset(4.3, 4.9), 3.4, fill);
    canvas.drawCircle(const Offset(17.7, 4.9), 3.4, fill);

    // 얼굴 — 가로로 넓은 타원. 선으로 둔다(채우면 눈 패치가 안 보인다).
    _oval(canvas, stroke, 11, 12.2, 8.2, 7.4);

    // 눈 패치 — 판다의 정체. 안쪽으로 기울여 참조 그림의 인상을 따른다.
    _oval(canvas, fill, 7.4, 11.2, 3.0, 3.6, -14);
    _oval(canvas, fill, 14.6, 11.2, 3.0, 3.6, 14);

    // 눈동자 — 파냄. 지름 2.0이 22px에서 살아남는 하한이다(실측).
    final cut = Paint()..blendMode = BlendMode.clear;
    canvas.drawCircle(const Offset(8.3, 9.9), 1.0, cut);
    canvas.drawCircle(const Offset(13.7, 9.9), 1.0, cut);

    // 코
    _oval(canvas, fill, 11, 14.6, 1.6, 1.2);

    canvas.restore();
  }

  void _oval(Canvas c, Paint p, double cx, double cy, double rx, double ry,
      [double deg = 0]) {
    if (deg == 0) {
      c.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
        p,
      );
      return;
    }
    c.save();
    c.translate(cx, cy);
    c.rotate(deg * math.pi / 180);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
      p,
    );
    c.restore();
  }

  @override
  bool shouldRepaint(_PandaPainter old) => old.color != color;
}
