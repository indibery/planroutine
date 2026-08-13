// ignore_for_file: avoid_print
//
// 공공데이터포털 활용사례 신청서의 **대표 이미지(썸네일)** 생성 스크립트.
// 권장 규격 248×93(2.67:1)에 맞춘 가로 배너를 만든다.
//
// `flutter test`의 자동 스캔(`*_test.dart`)을 피하려고 파일명에 `_test`를 붙이지
// 않았다(`gen_app_icon.dart`와 같은 관례). 명시적으로 실행한다:
//
//   flutter test test/tools/gen_usecase_banner.dart
//
// 두 배율을 함께 뽑는다 — 정확히 248×93과 4배(992×372). 포털이 축소해 보여줄 때
// 4배 쪽이 또렷하고, 규격을 엄격히 보는 경우를 위해 1배도 남긴다.
//
// 앱 아이콘(1024 정사각 + LogoHybrid)을 그대로 쓰면 2.67:1 배너에서 좌우 여백만
// 남아 앱 이름이 보이지 않는다. 그래서 로고 마크 + 앱 이름 + 한 줄 설명을 나란히 둔다.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/shared/widgets/brand_logo.dart';

/// 배너 1장을 그린다. [scale]이 1이면 248×93이다.
Future<Uint8List> _render(double scale) async {
  const baseW = 248.0;
  const baseH = 93.0;
  final w = baseW * scale;
  final h = baseH * scale;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

  // 불투명 네이비로 전체를 덮는다 — alpha 채널이 남으면 포털 미리보기에서
  // 배경이 흰색으로 비쳐 골드 글씨가 읽히지 않는다.
  canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = AppColors.navy);

  // 상단 1px 골드 라인(탭바와 같은 신호). 배율에 비례해 굵어진다.
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, scale),
    Paint()..color = AppColors.gold,
  );

  final pad = 10.0 * scale;
  final markSize = h - pad * 2;

  canvas.save();
  canvas.translate(pad, pad);
  const LogoHybridPainter().paint(canvas, Size(markSize, markSize));
  canvas.restore();

  final textLeft = pad + markSize + 9.0 * scale;

  final title = TextPainter(
    text: TextSpan(
      text: '공직플랜',
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 26.0 * scale,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
        letterSpacing: -0.5 * scale,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final subtitle = TextPainter(
    text: TextSpan(
      text: '교사 업무 일정 · 출퇴근 버스',
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 11.0 * scale,
        fontWeight: FontWeight.w600,
        color: AppColors.gold,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  // 두 줄을 하나의 덩어리로 보고 세로 중앙에 놓는다. 각각 중앙에 맞추면
  // 줄 간격이 벌어져 배너가 위아래로 헐거워 보인다.
  final gap = 3.0 * scale;
  final blockH = title.height + gap + subtitle.height;
  final top = (h - blockH) / 2;

  title.paint(canvas, Offset(textLeft, top));
  subtitle.paint(canvas, Offset(textLeft, top + title.height + gap));

  final picture = recorder.endRecording();
  final image = await picture.toImage(w.toInt(), h.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  expect(data, isNotNull);
  return data!.buffer.asUint8List();
}

void main() {
  // `rootBundle`은 바인딩이 있어야 쓸 수 있다 — 폰트를 올리기 전에 초기화한다.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // **실제 Pretendard를 올린다.** 안 올리면 `flutter test`의 폴백 폰트(모든 글자가
    // 1em 고정폭)로 그려져 자간이 실기기와 전혀 다른 그림이 나온다.
    final loader = FontLoader('Pretendard')
      ..addFont(rootBundle.load('assets/fonts/PretendardVariable.ttf'));
    await loader.load();
    AppColors.applyBrightness(Brightness.dark);
  });

  test('generate 248x93 usecase banner PNG (1x + 4x)', () async {
    final dir = Directory('docs/usecase');
    dir.createSync(recursive: true);

    for (final scale in [1.0, 4.0]) {
      final bytes = await _render(scale);
      final n = scale.toInt();
      final file = File('${dir.path}/usecase_banner_${n}x.png');
      file.writeAsBytesSync(bytes);
      print(
        'Wrote ${bytes.length} bytes '
        '(${(248 * scale).toInt()}x${(93 * scale).toInt()}) '
        '→ ${file.absolute.path}',
      );
    }
  });
}
