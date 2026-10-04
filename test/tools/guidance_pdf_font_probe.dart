// 실행: flutter test test/tools/guidance_pdf_font_probe.dart
// 가변 폰트(PretendardVariable)로 한글 본문·굵은 제목·Courier 해시가 PDF에 제대로 나오는지,
// 한 쪽짜리 PDF가 몇 KB인지 본다. 결과 PDF: build/guidance_pdf_probe.pdf
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('가변 폰트 PDF 실험', () async {
    final font = pw.Font.ttf(File('assets/fonts/PretendardVariable.ttf').readAsBytesSync().buffer.asByteData());
    final bold = pw.Font.ttf(File('assets/fonts/Pretendard-Bold.ttf').readAsBytesSync().buffer.asByteData());
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: bold));
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('지도 기록 — 굵은 제목', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.Text('보통 본문: 복도에서 밀침이 있었고 분리 지도했다. 가나다라마바사 0123', style: const pw.TextStyle(fontSize: 11)),
        pw.Text('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
            style: pw.TextStyle(font: pw.Font.courier(), fontSize: 8)),
      ]),
    ));
    final bytes = await doc.save();
    Directory('build').createSync(recursive: true);
    File('build/guidance_pdf_probe.pdf').writeAsBytesSync(bytes);
    // ignore: avoid_print
    print('PDF 크기: ${(bytes.length / 1024).toStringAsFixed(1)} KB');
  });
}
