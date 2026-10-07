import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/guidance/domain/guidance_export.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';

GuidanceAttachment att(
  int id,
  String fileName,
  String attachedAt, {
  AttachmentType type = AttachmentType.audio,
  String? removedAt,
}) => GuidanceAttachment(
  id: id,
  recordId: 1,
  type: type,
  source: AttachmentSource.recorded,
  fileName: fileName,
  sha256: 'a' * 64,
  byteSize: 10,
  attachedAt: attachedAt,
  removedAt: removedAt,
);

void main() {
  test('기본 이름은 기록 시각의 yyyyMMdd-HHmm이다', () {
    expect(exportBaseName('2026-10-04T15:30:12.345678'), '20261004-1530');
  });

  test('기록 시각을 읽을 수 없으면 record로 떨어진다', () {
    expect(exportBaseName('엉망'), 'record');
  });

  test('내보내기 시각은 연도까지 붙은 고정 형식이다', () {
    expect(formatExportStamp('2026-10-04T09:05:00'), '2026-10-04 09:05');
    expect(formatExportStamp('엉망'), '엉망');
  });

  test('선택한 첨부만 attachedAt 순으로 01부터 번호를 받는다', () {
    final plan = buildExportPlan(
      createdAt: '2026-10-04T15:30:00',
      attachments: [
        att(3, '333.jpg', '2026-10-04T16:00:00', type: AttachmentType.image),
        att(1, '111.aac', '2026-10-04T15:31:00'),
        att(2, '222.m4a', '2026-10-04T15:40:00'),
      ],
      selectedIds: {1, 3},
    );
    expect(plan.entries.map((e) => e.attachment.id), [1, 3]);
    expect(plan.entries.map((e) => e.noLabel), ['01', '02']);
    expect(plan.entries.map((e) => e.innerName), [
      '20261004-1530_01.aac',
      '20261004-1530_02.jpg',
    ]);
    expect(plan.images.map((e) => e.no), [2]);
  });

  test('뺀 첨부는 선택돼 있어도 나오지 않는다', () {
    final plan = buildExportPlan(
      createdAt: '2026-10-04T15:30:00',
      attachments: [
        att(
          1,
          '1.aac',
          '2026-10-04T15:31:00',
          removedAt: '2026-10-04T15:50:00',
        ),
      ],
      selectedIds: {1},
    );
    expect(plan.entries, isEmpty);
  });

  test('파일 이름 넷 — 바깥은 한글, ZIP 안은 영문·숫자뿐', () {
    final plan = buildExportPlan(
      createdAt: '2026-10-04T15:30:00',
      attachments: [
        att(1, '1.AAC', '2026-10-04T15:31:00'),
        att(2, '2.헤익', '2026-10-04T15:32:00'),
      ],
      selectedIds: {1, 2},
    );
    expect(plan.zipName, '지도기록_20261004-1530.zip');
    expect(plan.pdfName, '지도기록_20261004-1530.pdf');
    expect(plan.innerPdfName, '20261004-1530_record.pdf');
    // 확장자는 소문자로, 영문·숫자가 아닌 확장자는 bin으로
    expect(plan.entries.map((e) => e.innerName), [
      '20261004-1530_01.aac',
      '20261004-1530_02.bin',
    ]);
    for (final n in [
      plan.innerPdfName,
      ...plan.entries.map((e) => e.innerName),
    ]) {
      expect(exportInnerNamePattern.hasMatch(n), isTrue, reason: n);
    }
  });

  test('ZIP 부제는 선택한 종류별 개수로 조립한다', () {
    expect(
      GuidanceStrings.exportBundleSubtitle(2, 1),
      'PDF + 녹음 2개 · 사진 1개 원본',
    );
    expect(GuidanceStrings.exportBundleSubtitle(0, 1), 'PDF + 사진 1개 원본');
    expect(GuidanceStrings.exportBundleSubtitle(0, 0), 'PDF');
  });

  test('PC 안내는 두 기기 모두 메일로 시작하고, 케이블은 안드로이드 마지막에만 있다', () {
    expect(GuidanceStrings.exportPcGuideIos.first, startsWith('메일'));
    expect(GuidanceStrings.exportPcGuideAndroid.first, startsWith('메일'));
    expect(GuidanceStrings.exportPcGuideAndroid.last, startsWith('USB 케이블'));
    expect(
      GuidanceStrings.exportPcGuideIos.any((s) => s.contains('케이블')),
      isFalse,
    );
    for (final s in [
      ...GuidanceStrings.exportPcGuideIos,
      ...GuidanceStrings.exportPcGuideAndroid,
    ]) {
      expect(s.contains('서버'), isFalse, reason: s);
    }
  });

  group('buildAudioOnlyFiles', () {
    test('고른 녹음만, 고른 것 사이 순번으로, 지도기록_ 접두 + 원래 확장자', () {
      final files = buildAudioOnlyFiles(
        createdAt: '2026-10-04T15:30:00',
        attachments: [
          att(1, 'p.heic', '2026-10-04T15:31:00', type: AttachmentType.image),
          att(2, 'r.aac', '2026-10-04T15:32:00'),
          att(3, 'r2.M4A', '2026-10-04T15:33:00'),
        ],
        selectedIds: {1, 2, 3},
      );
      expect(files.map((f) => f.outName), ['지도기록_20261004-1530_01.aac', '지도기록_20261004-1530_02.m4a']);
    });

    test('뺀 첨부·고르지 않은 녹음은 빠진다', () {
      final files = buildAudioOnlyFiles(
        createdAt: '2026-10-04T15:30:00',
        attachments: [
          att(2, 'a.aac', '2026-10-04T15:32:00', removedAt: '2026-10-05T00:00:00'),
          att(3, 'b.aac', '2026-10-04T15:33:00'),
          att(4, 'c.aac', '2026-10-04T15:34:00'),
        ],
        selectedIds: {2, 4},
      );
      expect(files.map((f) => f.attachment.id), [4]);
    });
  });
}
