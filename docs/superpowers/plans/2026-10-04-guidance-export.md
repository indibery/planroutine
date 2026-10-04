# 지도 기록 내보내기 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 지도 기록 한 건을 학교 PC로 옮길 수 있게 `제출용 묶음(ZIP)`(PDF + 원본) 또는 `PDF만`으로 내보낸다.

**Architecture:** 순수 함수(`buildExportPlan`)가 선택된 첨부에 번호와 ZIP 안 이름을 매기고, PDF 생성기와 ZIP 생성기가 같은 목록을 본다. `GuidanceExporter`가 파일을 읽어 바이트를 만들고, 시트가 그 바이트를 공유시트(두 기기) 또는 저장 창(안드로이드)으로 넘긴다. 네트워크는 쓰지 않는다.

**Tech Stack:** Flutter 3.44.8 · Riverpod · `pdf`(새) · `archive` 4.0.9 · `image` 4.8.0(둘 다 지금은 간접 의존 → 직접으로) · `share_plus` 10 · `file_picker` 9.2.3(`saveFile`)

**Spec:** `docs/superpowers/specs/2026-10-04-guidance-export-design.md`

## Global Constraints

- 문자열은 `GuidanceStrings`(`lib/core/constants/strings/guidance_strings.dart`)에 둔다. 화면 문구에 `판`을 쓰지 않는다(`guidance_strings_no_pan_test.dart`).
- 파일 이름에 기록 제목을 넣지 않는다. 기본 이름은 `guidance_records.created_at`의 `yyyyMMdd-HHmm`.
- ZIP 안 이름은 `^[A-Za-z0-9._-]+$`만. ZIP 파일 이름 `지도기록_<기본>.zip`, PDF만 `지도기록_<기본>.pdf`, ZIP 안 PDF `<기본>_record.pdf`, 원본 `<기본>_NN.<원래 확장자>`.
- 원본은 바이트 그대로, ZIP에는 `CompressionType.none`(store)으로.
- 뺀 첨부(`isRemoved`)는 어디에도 나오지 않는다. 번호는 선택한 첨부 안에서 `attachedAt` 순으로 01부터.
- PC 안내 순서는 두 기기 모두 메일 → 카카오톡 → 드라이브, 안드로이드만 ④ USB 케이블. 안내에 `서버`라는 낱말을 쓰지 않는다.
- 안드로이드 버튼: `공유`(주, goldFill + onGold) · `기기에 저장`(보조, 테두리). 아이폰: `공유` 하나.
- 플랫폼 분기는 `bool? isAndroid` 주입점(기본 `Platform.isAndroid`) — `defaultTargetPlatform` 금지.
- 시트·대화상자는 루트 내비게이터에 띄우지 않는다(`showModalBottomSheet` 기본값 유지, `showDialog`류는 `useRootNavigator: false`).
- 스낵바에 기록 내용(제목·이름)을 넣지 않는다.
- 아이콘 버튼 이름은 `Icon(semanticLabel:)` — `tooltip` 금지. 직접 만든 터치 영역은 `ButtonSemantics`.
- `!` 강제 언래핑 금지. 기존 테스트 삭제 금지.
- 위젯 테스트에서 실제 DB·파일 I/O는 `tester.runAsync()` 안에서.

## Review Focus

1. **아이폰 HEIC 사진**(`allowCompression: false`라 원본 HEIC가 들어온다) — `image` 패키지가 못 읽는다. 내보내기는 실패하지 않고, 그 붙임 쪽에 `pdfPhotoUnsupported` 문구가 대신 들어가야 한다 → Task 4 Step 1 `디코드할 수 없는 사진`.
2. **디스크에 없는 첨부**(안드로이드 백업 복원은 첨부 폴더를 빼고 DB만 살린다) — 시트에서 그 줄은 꺼져 있고 선택되지 않으며, 나머지로 내보내기가 된다 → Task 6 Step 1 `파일이 없는 첨부`.
3. **줄바꿈 없는 아주 긴 글**(6000자 붙여넣기) — 한 위젯이 한 쪽을 넘으면 `pdf`가 예외를 던진다. 여러 쪽으로 나뉘어야 한다 → Task 4 Step 1 `줄바꿈 없는 긴 글`.
4. **첨부도 본문도 없는 기록** — ZIP 줄이 없고 `PDF만`이 기본, PDF에 첨부 절이 없다 → Task 4 `빈 기록` · Task 6 `첨부가 없으면`.
5. **만드는 중 두 번 누르기** — 공유가 두 번 뜨거나 임시 파일이 겹치면 안 된다. 만드는 동안 버튼이 꺼진다 → Task 6 Step 1 `만드는 동안 다시 누를 수 없다`.

---

### Task 1: 의존성 추가 + 폰트 실험 (사용자 확인 지점)

**Files:**
- Modify: `pubspec.yaml`
- Create: `test/tools/guidance_pdf_font_probe.dart` (파일명에 `_test`가 없어 자동 스캔 제외)

**Interfaces:**
- Produces: 폰트 결정 — `bold`에 쓸 폰트(가변 폰트 그대로 / 정적 Bold 추가). Task 4의 `loadGuidancePdfFonts()`가 이 결정을 따른다.

- [ ] **Step 1: 의존성 추가**

```bash
cd /Users/kwangsukim/i_code/planroutine
flutter pub add pdf archive image
grep -n -A1 "^  pdf:\|^  archive:\|^  image:" pubspec.lock | grep -E "pdf:|archive:|image:|version"
```

Expected: 세 패키지가 `direct main`이 되고 `archive` 4.0.x, `image` 4.x가 그대로 유지된다. 버전 충돌로 해결이 안 되면 멈추고 보고한다.

- [ ] **Step 2: 실험 도구 작성**

```dart
// test/tools/guidance_pdf_font_probe.dart
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
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: font));
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
```

- [ ] **Step 3: 실행하고 눈으로 확인**

```bash
flutter test test/tools/guidance_pdf_font_probe.dart
qlmanage -t -s 1600 -o build/ build/guidance_pdf_probe.pdf >/dev/null 2>&1; ls -la build/guidance_pdf_probe.pdf*
```

PNG(`build/guidance_pdf_probe.pdf.png`)를 Read 도구로 열어 본다. 판정:
- 한글이 네모(두부)로 나오면 → 가변 폰트를 못 쓴다. 정적 폰트 필요.
- 제목이 본문과 **같은 굵기**면 → 굵게 쓰기가 안 된다.
- 해시가 고정폭으로 나오는지.
- 크기가 1MB를 넘으면 → 서브셋이 안 된다.

- [ ] **Step 4: 결정 (사용자 확인)**

- 한글·굵기·크기 모두 괜찮으면: `bold`도 같은 가변 폰트를 쓴다. 다음 Task로.
- 한글은 되는데 굵기만 안 되면: 사용자에게 묻는다 — "제목을 크기로만 구분(앱 용량 그대로)" vs "정적 Pretendard-Bold.ttf 추가(+약 N MB, 실측)". 답에 따라 `assets/fonts/`에 파일을 두고 `pubspec.yaml`의 `assets:`에 `assets/fonts/Pretendard-Bold.ttf`를 추가한다(폰트 패밀리로 등록하지 않는다 — PDF 전용).
- 한글이 깨지거나 1MB를 넘으면: 정적 Regular·Bold(KS X 1001 서브셋 우선)를 추가하는 안을 용량과 함께 보고하고 답을 기다린다.

결정을 스펙의 `### 첫 단계: 폰트 실험` 절 끝에 한 줄로 적는다(`실측 2026-10-xx: …`).

- [ ] **Step 5: 커밋**

```bash
git add pubspec.yaml pubspec.lock test/tools/guidance_pdf_font_probe.dart docs/superpowers/specs/2026-10-04-guidance-export-design.md
# 폰트 파일을 추가했다면 그것도 add
git commit -m "chore(guidance): 내보내기용 pdf·archive·image 의존성 + PDF 폰트 실험 도구"
```

---

### Task 2: 내보내기 목록(순수 함수) + 문자열

**Files:**
- Create: `lib/features/guidance/domain/guidance_export.dart`
- Modify: `lib/core/constants/strings/guidance_strings.dart` (끝에 `// 내보내기` 절 추가)
- Test: `test/features/guidance/domain/guidance_export_test.dart`

**Interfaces:**
- Produces:
  - `enum ExportKind { bundle, pdfOnly }`
  - `class ExportEntry { int no; String innerName; GuidanceAttachment attachment; String get noLabel; }`
  - `class ExportPlan { String baseName; List<ExportEntry> entries; String get zipName; String get pdfName; String get innerPdfName; List<ExportEntry> get images; }`
  - `String exportBaseName(String createdAtIso)`
  - `String formatExportStamp(String iso)` → `2026-10-04 15:30`
  - `ExportPlan buildExportPlan({required String createdAt, required List<GuidanceAttachment> attachments, required Set<int> selectedIds})`
  - `final RegExp exportInnerNamePattern`
  - `GuidanceStrings`의 내보내기 문자열(아래 Step 3 전부)

- [ ] **Step 1: 실패하는 테스트**

```dart
// test/features/guidance/domain/guidance_export_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/domain/guidance_export.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';

GuidanceAttachment att(int id, String fileName, String attachedAt,
        {AttachmentType type = AttachmentType.audio, String? removedAt}) =>
    GuidanceAttachment(
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
    expect(plan.entries.map((e) => e.innerName), ['20261004-1530_01.aac', '20261004-1530_02.jpg']);
    expect(plan.images.map((e) => e.no), [2]);
  });

  test('뺀 첨부는 선택돼 있어도 나오지 않는다', () {
    final plan = buildExportPlan(
      createdAt: '2026-10-04T15:30:00',
      attachments: [att(1, '1.aac', '2026-10-04T15:31:00', removedAt: '2026-10-04T15:50:00')],
      selectedIds: {1},
    );
    expect(plan.entries, isEmpty);
  });

  test('파일 이름 넷 — 바깥은 한글, ZIP 안은 영문·숫자뿐', () {
    final plan = buildExportPlan(
      createdAt: '2026-10-04T15:30:00',
      attachments: [att(1, '1.AAC', '2026-10-04T15:31:00'), att(2, '2.헤익', '2026-10-04T15:32:00')],
      selectedIds: {1, 2},
    );
    expect(plan.zipName, '지도기록_20261004-1530.zip');
    expect(plan.pdfName, '지도기록_20261004-1530.pdf');
    expect(plan.innerPdfName, '20261004-1530_record.pdf');
    // 확장자는 소문자로, 영문·숫자가 아닌 확장자는 bin으로
    expect(plan.entries.map((e) => e.innerName), ['20261004-1530_01.aac', '20261004-1530_02.bin']);
    for (final n in [plan.innerPdfName, ...plan.entries.map((e) => e.innerName)]) {
      expect(exportInnerNamePattern.hasMatch(n), isTrue, reason: n);
    }
  });

  test('ZIP 부제는 선택한 종류별 개수로 조립한다', () {
    expect(GuidanceStrings.exportBundleSubtitle(2, 1), 'PDF + 녹음 2개 · 사진 1개 원본');
    expect(GuidanceStrings.exportBundleSubtitle(0, 1), 'PDF + 사진 1개 원본');
    expect(GuidanceStrings.exportBundleSubtitle(0, 0), 'PDF');
  });

  test('PC 안내는 두 기기 모두 메일로 시작하고, 케이블은 안드로이드 마지막에만 있다', () {
    expect(GuidanceStrings.exportPcGuideIos.first, startsWith('메일'));
    expect(GuidanceStrings.exportPcGuideAndroid.first, startsWith('메일'));
    expect(GuidanceStrings.exportPcGuideAndroid.last, startsWith('USB 케이블'));
    expect(GuidanceStrings.exportPcGuideIos.any((s) => s.contains('케이블')), isFalse);
    for (final s in [...GuidanceStrings.exportPcGuideIos, ...GuidanceStrings.exportPcGuideAndroid]) {
      expect(s.contains('서버'), isFalse, reason: s);
    }
  });
}
```

`GuidanceStrings`는 `package:planroutine/core/constants/app_strings.dart`에서 import 한다(배럴).

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/guidance/domain/guidance_export_test.dart`
Expected: FAIL — `guidance_export.dart` 없음.

- [ ] **Step 3: 문자열 추가** — `guidance_strings.dart`의 클래스 끝(닫는 `}` 앞)에:

```dart
  // 내보내기
  static const export = '내보내기';
  static const exportBundle = '제출용 묶음(ZIP)';
  static String exportBundleSubtitle(int audio, int image) {
    final parts = [
      if (audio > 0) '$attachmentAudio $audio개',
      if (image > 0) '$attachmentImage $image개',
    ];
    return parts.isEmpty ? 'PDF' : 'PDF + ${parts.join(' · ')} 원본';
  }
  static const exportPdfOnly = 'PDF만';
  static const exportPdfOnlySubtitle = '인쇄·내부 보고용';
  static const exportNotice = '학생 이름과 기록 내용이 담깁니다. 받는 사람을 확인하세요.';
  static const exportShare = '공유';
  static const exportSaveToDevice = '기기에 저장';
  static const exportSaved = '다운로드 폴더 등 고른 곳에 저장했어요';
  static const exportFailed = '내보내지 못했어요. 다시 눌러 주세요.';
  static const exportPcGuideTitle = 'PC로 옮기는 방법';
  static const exportPcGuideIos = [
    '메일 — 공유에서 메일 앱을 골라 나에게 보내고, PC에서 웹메일로 받아요.',
    '카카오톡 — 공유에서 카카오톡 나와의 채팅으로 보내고, PC 카카오톡에서 받아요.',
    '드라이브 — 공유에서 "파일에 저장"(iCloud Drive)이나 구글 드라이브로 보내고, PC 브라우저에서 받아요.',
  ];
  static const exportPcGuideAndroid = [
    '메일 — 공유에서 메일 앱을 골라 나에게 보내고, PC에서 웹메일로 받아요.',
    '카카오톡 — 공유에서 카카오톡 나와의 채팅으로 보내고, PC 카카오톡에서 받아요.',
    '드라이브 — 공유에서 구글 드라이브로 보내고, PC 브라우저에서 받아요.',
    'USB 케이블 — 기기에 저장에서 "다운로드"를 고르고, PC에 꽂아 복사해요.',
  ];

  // 내보내기 PDF
  static const pdfTitle = '지도 기록';
  static const pdfLastEdited = '마지막 수정';
  static String pdfEdits(int edits) => edits == 0 ? '수정 없음' : '수정 $edits회';
  static const pdfAttachments = '첨부';
  static const pdfColNo = '번호';
  static const pdfOriginalsInZip = '원본은 제출용 묶음(ZIP)에 같은 이름으로 들어 있습니다.';
  static const pdfOriginalsHint = "원본은 앱에서 '제출용 묶음(ZIP)'으로 내보낼 수 있습니다.";
  static const pdfCertutil = 'Windows에서 대조: certutil -hashfile 파일이름 SHA256';
  static String pdfAppendixTitle(int n, String no) => '붙임 $n (첨부 $no)';
  static const pdfPhotoNote = 'PDF에 넣은 사진은 축소본입니다. 해시는 원본 기준입니다.';
  static const pdfPhotoUnsupported = '이 사진은 PDF에 넣을 수 없는 형식입니다. 원본은 제출용 묶음(ZIP)에 있습니다.';
  static String pdfFooter(String stamp, int page, int pages) => '공직플랜에서 $stamp에 만듦 · $page/$pages쪽';
```

- [ ] **Step 4: 목록 구현**

```dart
// lib/features/guidance/domain/guidance_export.dart
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'guidance_models.dart';
import 'guidance_types.dart';

/// 무엇을 내보내나 — PDF와 원본을 한 파일로 / PDF 한 장.
enum ExportKind { bundle, pdfOnly }

/// ZIP 안의 이름. Windows에서 한글 이름이 깨지는 일을 원천적으로 없앤다(스펙 "파일 이름").
final exportInnerNamePattern = RegExp(r'^[A-Za-z0-9._-]+$');

final _extPattern = RegExp(r'^\.[a-z0-9]+$');

class ExportEntry {
  const ExportEntry({required this.no, required this.innerName, required this.attachment});

  /// 1부터. PDF 첨부 표의 번호와 ZIP 안 이름의 번호가 같다.
  final int no;
  final String innerName;
  final GuidanceAttachment attachment;

  String get noLabel => no.toString().padLeft(2, '0');
}

/// PDF와 ZIP이 함께 보는 목록. 둘이 같은 목록을 봐야 번호가 어긋나지 않는다.
class ExportPlan {
  const ExportPlan({required this.baseName, required this.entries});

  final String baseName;
  final List<ExportEntry> entries;

  /// 제목은 넣지 않는다 — 메신저 목록에도 보이고, 제목에 학생 이름이 있을 수 있다.
  String get zipName => '지도기록_$baseName.zip';
  String get pdfName => '지도기록_$baseName.pdf';
  String get innerPdfName => '${baseName}_record.pdf';

  List<ExportEntry> get images => [
    for (final e in entries)
      if (e.attachment.type == AttachmentType.image) e,
  ];
}

String exportBaseName(String createdAtIso) {
  final d = DateTime.tryParse(createdAtIso);
  return d == null ? 'record' : DateFormat('yyyyMMdd-HHmm').format(d);
}

/// 제출 문서용 시각 — 앱 화면과 달리 올해여도 연도를 붙인다.
String formatExportStamp(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : DateFormat('yyyy-MM-dd HH:mm').format(d);
}

ExportPlan buildExportPlan({
  required String createdAt,
  required List<GuidanceAttachment> attachments,
  required Set<int> selectedIds,
}) {
  final base = exportBaseName(createdAt);
  final picked = [
    for (final a in attachments)
      if (!a.isRemoved && selectedIds.contains(a.id)) a,
  ]..sort((a, b) {
      final byTime = a.attachedAt.compareTo(b.attachedAt);
      return byTime != 0 ? byTime : (a.id ?? 0).compareTo(b.id ?? 0);
    });
  return ExportPlan(
    baseName: base,
    entries: [
      for (var i = 0; i < picked.length; i++)
        ExportEntry(
          no: i + 1,
          innerName: '${base}_${(i + 1).toString().padLeft(2, '0')}${_safeExt(picked[i].fileName)}',
          attachment: picked[i],
        ),
    ],
  );
}

String _safeExt(String fileName) {
  final ext = p.extension(fileName).toLowerCase();
  return _extPattern.hasMatch(ext) ? ext : '.bin';
}
```

- [ ] **Step 5: 통과 확인**

Run: `flutter test test/features/guidance/domain/guidance_export_test.dart test/features/guidance/guidance_strings_no_pan_test.dart`
Expected: PASS

- [ ] **Step 6: 커밋**

```bash
git add lib/features/guidance/domain/guidance_export.dart lib/core/constants/strings/guidance_strings.dart test/features/guidance/domain/guidance_export_test.dart
git commit -m "feat(guidance): 내보내기 목록 — 번호·ZIP 안 이름(영문·숫자)·문자열"
```

---

### Task 3: ZIP 생성기

**Files:**
- Create: `lib/features/guidance/data/guidance_zip_builder.dart`
- Test: `test/features/guidance/data/guidance_zip_builder_test.dart`

**Interfaces:**
- Consumes: 없음(바이트만 받는다)
- Produces: `Uint8List buildGuidanceZip(List<(String name, List<int> bytes)> files)`

- [ ] **Step 1: 실패하는 테스트**

```dart
// test/features/guidance/data/guidance_zip_builder_test.dart
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/data/guidance_zip_builder.dart';

void main() {
  test('다시 풀면 같은 이름·같은 바이트이고, 원본은 store로 들어간다', () {
    final audio = utf8.encode('abc'); // SHA-256 표준 시험 벡터
    final pdf = utf8.encode('%PDF-1.4 fake');
    final zip = buildGuidanceZip([('20261004-1530_record.pdf', pdf), ('20261004-1530_01.aac', audio)]);

    final archive = ZipDecoder().decodeBytes(zip);
    expect(archive.files.map((f) => f.name), ['20261004-1530_record.pdf', '20261004-1530_01.aac']);
    final a = archive.files.firstWhere((f) => f.name.endsWith('.aac'));
    expect(sha256.convert(a.readBytes() ?? const []).toString(),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    for (final f in archive.files) {
      expect(f.compression, CompressionType.none, reason: f.name);
    }
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/guidance/data/guidance_zip_builder_test.dart`
Expected: FAIL — 파일 없음.

- [ ] **Step 3: 구현**

```dart
// lib/features/guidance/data/guidance_zip_builder.dart
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// PDF와 원본을 한 ZIP으로. 원본은 바이트 그대로 **store**로 넣는다 — 녹음·사진은 이미 압축된
/// 형식이라 다시 압축해 얻는 것이 없고, 받는 쪽이 해시를 대조할 바이트가 그대로 남는다.
Uint8List buildGuidanceZip(List<(String, List<int>)> files) {
  final archive = Archive();
  for (final (name, bytes) in files) {
    archive.addFile(ArchiveFile.bytes(name, bytes)..compression = CompressionType.none);
  }
  return ZipEncoder().encodeBytes(archive);
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/guidance/data/guidance_zip_builder_test.dart`
Expected: PASS. 디코드 결과의 `compression`이 store를 반영하지 않으면(디코더가 값을 채우지 않는 경우) 같은 테스트에서 ZIP 로컬 헤더의 압축 방식(오프셋 8, 2바이트 LE)이 0인지로 바꿔 검사한다.

- [ ] **Step 5: 커밋**

```bash
git add lib/features/guidance/data/guidance_zip_builder.dart test/features/guidance/data/guidance_zip_builder_test.dart
git commit -m "feat(guidance): 내보내기 ZIP 생성기 — 원본은 store, 이름·바이트 그대로"
```

---

### Task 4: PDF 생성기 + 사진 축소

**Files:**
- Create: `lib/features/guidance/data/guidance_pdf_builder.dart`
- Test: `test/features/guidance/data/guidance_pdf_builder_test.dart`

**Interfaces:**
- Consumes: `ExportPlan`, `ExportKind`, `formatExportStamp`(Task 2), `formatOccurred`(`domain/guidance_logic.dart`), `GuidanceRecord`
- Produces:
  - `class GuidancePdfFonts { pw.Font base; pw.Font bold; }`
  - `Future<GuidancePdfFonts> loadGuidancePdfFonts()` — `rootBundle`에서. Task 1 결정대로 `bold`를 고른다.
  - `Uint8List? shrinkPhotoForPdf(Uint8List bytes, {int maxSide = 2000})` — 못 읽으면 `null`
  - `Future<Uint8List> buildGuidancePdf({required GuidanceRecord record, required ExportPlan plan, required ExportKind kind, required Map<int, Uint8List?> photos, required DateTime generatedAt, required GuidancePdfFonts fonts, bool compress = true})` — `photos`의 키는 `ExportEntry.no`, 값은 축소본(못 읽으면 null)

- [ ] **Step 1: 실패하는 테스트**

```dart
// test/features/guidance/data/guidance_pdf_builder_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:planroutine/features/guidance/data/guidance_pdf_builder.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_export.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';

GuidanceRecord record(GuidanceContent c, {int revisions = 1}) => GuidanceRecord(
  id: 1,
  createdAt: '2026-10-04T15:30:00',
  revisionCount: revisions,
  latest: GuidanceRevision(recordId: 1, revisionNo: revisions, savedAt: '2026-10-05T09:12:00', content: c),
);

GuidanceAttachment image(int id) => GuidanceAttachment(
  id: id, recordId: 1, type: AttachmentType.image, source: AttachmentSource.imported,
  fileName: '$id.jpg', sha256: 'b' * 64, byteSize: 100, attachedAt: '2026-10-04T15:4$id:00',
);

/// 압축하지 않은 PDF에서 쪽 객체를 센다(`/Type /Pages`는 빼고).
int pageCount(Uint8List pdf) => RegExp(r'/Type\s*/Page(?!s)').allMatches(latin1.decode(pdf)).length;

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  late GuidancePdfFonts fonts;
  setUpAll(() {
    final f = pw.Font.ttf(File('assets/fonts/PretendardVariable.ttf').readAsBytesSync().buffer.asByteData());
    fonts = GuidancePdfFonts(base: f, bold: f);
  });

  Future<Uint8List> build(GuidanceRecord r, ExportPlan plan, Map<int, Uint8List?> photos,
          {ExportKind kind = ExportKind.bundle}) =>
      buildGuidancePdf(record: r, plan: plan, kind: kind, photos: photos,
          generatedAt: DateTime(2026, 10, 6, 8), fonts: fonts, compress: false);

  test('빈 기록 — 제목만 있어도 한 쪽짜리 PDF가 나온다', () async {
    final pdf = await build(record(const GuidanceContent(title: '확인')),
        buildExportPlan(createdAt: '2026-10-04T15:30:00', attachments: const [], selectedIds: const {}), const {},
        kind: ExportKind.pdfOnly);
    expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
    expect(pageCount(pdf), 1);
  });

  test('사진마다 붙임 한 쪽이 더해진다', () async {
    final jpg = Uint8List.fromList(img.encodeJpg(img.Image(width: 40, height: 30)));
    final plan = buildExportPlan(createdAt: '2026-10-04T15:30:00', attachments: [image(1), image(2)], selectedIds: {1, 2});
    final pdf = await build(record(const GuidanceContent(title: '사진 둘', facts: '경과')), plan,
        {1: shrinkPhotoForPdf(jpg), 2: shrinkPhotoForPdf(jpg)});
    expect(pageCount(pdf), 3);
  });

  test('디코드할 수 없는 사진(HEIC 등)은 축소 결과가 null이고, 그래도 붙임 쪽은 생긴다', () async {
    expect(shrinkPhotoForPdf(Uint8List.fromList(utf8.encode('not an image'))), isNull);
    final plan = buildExportPlan(createdAt: '2026-10-04T15:30:00', attachments: [image(1)], selectedIds: {1});
    final pdf = await build(record(const GuidanceContent(title: 'heic')), plan, {1: null});
    expect(pageCount(pdf), 2);
  });

  test('줄바꿈 없는 긴 글은 예외 없이 여러 쪽으로 나뉜다', () async {
    final pdf = await build(record(GuidanceContent(title: '긴 글', facts: '가' * 6000)),
        buildExportPlan(createdAt: '2026-10-04T15:30:00', attachments: const [], selectedIds: const {}), const {},
        kind: ExportKind.pdfOnly);
    expect(pageCount(pdf), greaterThan(1));
  });

  test('축소본은 긴 변이 maxSide를 넘지 않고 EXIF 방향을 반영한다', () {
    final tall = img.Image(width: 3000, height: 1000);
    tall.exif.imageIfd.orientation = 6; // 90도 회전해서 보여야 하는 사진
    final out = img.decodeJpg(shrinkPhotoForPdf(Uint8List.fromList(img.encodeJpg(tall))) ?? Uint8List(0));
    expect(out, isNotNull);
    expect(out?.height, 2000); // 돌린 뒤 세로가 긴 변
    expect(out?.width, closeTo(667, 1));
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/guidance/data/guidance_pdf_builder_test.dart`
Expected: FAIL — 파일 없음.

- [ ] **Step 3: 구현**

```dart
// lib/features/guidance/data/guidance_pdf_builder.dart
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_strings.dart';
import '../domain/guidance_export.dart';
import '../domain/guidance_logic.dart';
import '../domain/guidance_models.dart';
import '../domain/guidance_types.dart';

class GuidancePdfFonts {
  const GuidancePdfFonts({required this.base, required this.bold});
  final pw.Font base;
  final pw.Font bold;
}

/// 폰트 선택은 Task 1 실측으로 정했다 — 구현할 때 이 주석을 그 결과 한 줄로 바꾼다.
Future<GuidancePdfFonts> loadGuidancePdfFonts() async {
  final base = pw.Font.ttf(await rootBundle.load('assets/fonts/PretendardVariable.ttf'));
  // 정적 Bold를 추가하기로 했으면: pw.Font.ttf(await rootBundle.load('assets/fonts/Pretendard-Bold.ttf'))
  return GuidancePdfFonts(base: base, bold: base);
}

/// PDF에 넣을 축소본. 원본은 손대지 않는다 — 해시는 원본 기준이다.
/// 읽을 수 없는 형식(아이폰 HEIC 등)이면 null.
Uint8List? shrinkPhotoForPdf(Uint8List bytes, {int maxSide = 2000}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final upright = img.bakeOrientation(decoded);
  final landscape = upright.width >= upright.height;
  final longest = landscape ? upright.width : upright.height;
  final resized = longest <= maxSide
      ? upright
      : img.copyResize(upright, width: landscape ? maxSide : null, height: landscape ? null : maxSide);
  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
}

/// 한 위젯이 한 쪽을 넘으면 pdf가 예외를 던진다 — 줄로 나누고, 긴 줄은 다시 자른다.
List<String> _chunks(String text, {int size = 300}) => [
  for (final line in text.split('\n'))
    if (line.length <= size)
      line
    else
      for (var i = 0; i < line.length; i += size) line.substring(i, (i + size).clamp(0, line.length)),
];

Future<Uint8List> buildGuidancePdf({
  required GuidanceRecord record,
  required ExportPlan plan,
  required ExportKind kind,
  required Map<int, Uint8List?> photos,
  required DateTime generatedAt,
  required GuidancePdfFonts fonts,
  bool compress = true,
}) async {
  final c = record.content;
  final mono = pw.Font.courier();
  final small = pw.TextStyle(fontSize: 9, color: PdfColors.grey800);
  final label = pw.TextStyle(fontSize: 10, color: PdfColors.grey800);
  final heading = pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold);
  final stamp = formatExportStamp(generatedAt.toIso8601String());

  pw.Widget infoRow(String k, String v) => pw.TableRow(children: [
    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(k, style: label)),
    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(v)),
  ]);

  pw.Widget section(String title, String? body) => body == null
      ? pw.SizedBox()
      : pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(height: 12),
          pw.Text(title, style: heading),
          pw.SizedBox(height: 4),
          for (final line in _chunks(body)) pw.Text(line),
        ]);

  final edits = record.revisionCount - 1;
  // formatOccurred는 올해면 연도를 뺀다 — 제출 문서는 늘 연도를 붙이려고 기준 연도를 0으로 준다.
  final occurred = formatOccurred(c, now: DateTime(0));

  final doc = pw.Document(compress: compress, theme: pw.ThemeData.withFont(base: fonts.base, bold: fonts.bold));
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(GuidanceStrings.pdfFooter(stamp, ctx.pageNumber, ctx.pagesCount), style: small),
      ),
      build: (ctx) => [
        pw.Text(GuidanceStrings.pdfTitle, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.Text('${c.kind.label} · ${c.status.label}', style: label),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
          columnWidths: const {0: pw.FixedColumnWidth(80), 1: pw.FlexColumnWidth()},
          children: [
            infoRow(GuidanceStrings.labelTitle, c.title.isEmpty ? GuidanceStrings.untitled : c.title),
            infoRow(GuidanceStrings.labelOccurred, occurred),
            if (c.place case final place?) infoRow(GuidanceStrings.labelPlace, place),
            if (c.participants.isNotEmpty)
              infoRow(GuidanceStrings.labelParticipants, c.participants.map((p) => p.name).join(', ')),
            infoRow(GuidanceStrings.labelCreated, formatExportStamp(record.createdAt)),
            infoRow(GuidanceStrings.pdfLastEdited,
                edits == 0 ? GuidanceStrings.pdfEdits(0) : '${formatExportStamp(record.latest.savedAt)} · ${GuidanceStrings.pdfEdits(edits)}'),
          ],
        ),
        section(GuidanceStrings.labelFacts, c.facts),
        section(GuidanceStrings.labelQuotes, c.quotes),
        section(GuidanceStrings.labelActions, c.actions),
        if (plan.entries.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text(GuidanceStrings.pdfAttachments, style: heading),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
            columnWidths: const {0: pw.FixedColumnWidth(32), 1: pw.FlexColumnWidth()},
            children: [
              for (final e in plan.entries)
                pw.TableRow(children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(e.noLabel)),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(_entryLine(e)),
                      pw.Text('SHA-256 ${e.attachment.sha256}', style: pw.TextStyle(font: mono, fontSize: 7.5)),
                    ]),
                  ),
                ]),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(kind == ExportKind.bundle ? GuidanceStrings.pdfOriginalsInZip : GuidanceStrings.pdfOriginalsHint, style: small),
          pw.Text(GuidanceStrings.pdfCertutil, style: small),
        ],
        for (final (i, e) in plan.images.indexed) ...[
          pw.NewPage(),
          pw.Text(GuidanceStrings.pdfAppendixTitle(i + 1, e.noLabel), style: heading),
          pw.SizedBox(height: 8),
          if (photos[e.no] case final bytes?)
            pw.Container(height: 560, alignment: pw.Alignment.topCenter,
                child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain))
          else
            pw.Text(GuidanceStrings.pdfPhotoUnsupported),
          pw.SizedBox(height: 8),
          pw.Text(GuidanceStrings.pdfPhotoNote, style: small),
        ],
      ],
    ),
  );
  return doc.save();
}

String _entryLine(ExportEntry e) {
  final a = e.attachment;
  final ms = a.durationMs;
  final size = ms == null ? GuidanceStrings.sizeLabel(a.byteSize) : GuidanceStrings.durationLabel(ms);
  final at = a.capturedAt ?? a.attachedAt;
  return '${a.type.label}(${a.source.label}) · ${e.innerName} · $size · ${formatExportStamp(at)}';
}
```

그리고 Task 1에서 정적 Bold를 넣기로 했다면 `loadGuidancePdfFonts`의 주석 줄을 실제 코드로 바꾸고, 테스트의 `fonts`도 같은 파일을 읽게 한다.

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/guidance/data/guidance_pdf_builder_test.dart`
Expected: PASS. `pageCount` 정규식이 0을 돌려주면(`pdf`가 `/Type/Page`처럼 공백 없이 쓰는 경우까지 `\s*`가 덮는다) 출력 앞부분을 찍어 실제 표기를 확인하고 정규식만 고친다.

- [ ] **Step 5: 눈으로 한 번** — Task 1 도구처럼 실제 PDF를 하나 뽑아 PNG로 본다(테스트 끝에 임시로 `File('build/guidance_pdf_sample.pdf').writeAsBytesSync(pdf)`를 넣고 `qlmanage -t`, 확인 뒤 그 줄은 지운다). 표가 넘치지 않는지, 해시가 한 줄에 들어가는지, 흑백에서 읽히는지.

- [ ] **Step 6: 커밋**

```bash
git add lib/features/guidance/data/guidance_pdf_builder.dart test/features/guidance/data/guidance_pdf_builder_test.dart
git commit -m "feat(guidance): 내보내기 PDF — 기본 정보·본문·첨부 해시 표·사진 붙임(A4)"
```

---

### Task 5: 내보내기 서비스

**Files:**
- Create: `lib/features/guidance/data/guidance_exporter.dart`
- Modify: `lib/features/guidance/presentation/providers/guidance_providers.dart` (provider 하나 추가)
- Test: `test/features/guidance/data/guidance_exporter_test.dart`

**Interfaces:**
- Consumes: `GuidanceFileStore.fileOf(String)`(기존), `buildExportPlan`·`ExportKind`(Task 2), `buildGuidanceZip`(Task 3), `buildGuidancePdf`·`shrinkPhotoForPdf`·`loadGuidancePdfFonts`(Task 4)
- Produces:
  - `class ExportOutput { String fileName; Uint8List bytes; }`
  - `class GuidanceExporter { Future<Set<int>> availableIds(List<GuidanceAttachment>); Future<ExportOutput> build({required GuidanceRecord record, required List<GuidanceAttachment> attachments, required Set<int> selectedIds, required ExportKind kind}); }`
  - `final guidanceExporterProvider = Provider<GuidanceExporter>(...)`

- [ ] **Step 1: 실패하는 테스트**

```dart
// test/features/guidance/data/guidance_exporter_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:planroutine/features/guidance/data/guidance_exporter.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';
import 'package:planroutine/features/guidance/data/guidance_pdf_builder.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_export.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  late Directory base;
  late GuidanceFileStore store;
  late GuidanceExporter exporter;

  setUp(() async {
    base = await Directory.systemTemp.createTemp('guidance_export');
    store = GuidanceFileStore(baseDir: () async => base);
    final f = pw.Font.ttf(File('assets/fonts/PretendardVariable.ttf').readAsBytesSync().buffer.asByteData());
    exporter = GuidanceExporter(
      fileStore: store,
      loadFonts: () async => GuidancePdfFonts(base: f, bold: f),
      clock: () => DateTime(2026, 10, 6, 8),
    );
  });
  tearDown(() async => base.delete(recursive: true));

  final record = GuidanceRecord(
    id: 1,
    createdAt: '2026-10-04T15:30:00',
    latest: const GuidanceRevision(recordId: 1, revisionNo: 1, savedAt: '2026-10-04T15:30:00',
        content: GuidanceContent(title: '복도 다툼')),
  );

  Future<GuidanceAttachment> stored(int id, String content, {String ext = 'aac'}) async {
    final src = File('${base.path}/src_$id.$ext')..writeAsStringSync(content);
    final s = await store.importCopy(src.path);
    return GuidanceAttachment(id: id, recordId: 1, type: AttachmentType.audio, source: AttachmentSource.recorded,
        fileName: s.fileName, sha256: s.sha256, byteSize: s.byteSize, attachedAt: '2026-10-04T15:3$id:00');
  }

  test('묶음은 ZIP 이름이고, 풀면 PDF와 원본이 영문 이름·원래 해시로 들어 있다', () async {
    final a = await stored(1, 'abc');
    final out = await exporter.build(record: record, attachments: [a], selectedIds: {1}, kind: ExportKind.bundle);
    expect(out.fileName, '지도기록_20261004-1530.zip');
    final files = ZipDecoder().decodeBytes(out.bytes).files;
    expect(files.map((f) => f.name), ['20261004-1530_record.pdf', '20261004-1530_01.aac']);
    for (final f in files) {
      expect(exportInnerNamePattern.hasMatch(f.name), isTrue);
    }
    expect(sha256.convert(files[1].readBytes() ?? const []).toString(), a.sha256);
    expect(latin1.decode((files[0].readBytes() ?? const []).take(5).toList()), '%PDF-');
  });

  test('PDF만은 PDF 바이트 하나다', () async {
    final out = await exporter.build(record: record, attachments: const [], selectedIds: const {}, kind: ExportKind.pdfOnly);
    expect(out.fileName, '지도기록_20261004-1530.pdf');
    expect(latin1.decode(out.bytes.sublist(0, 5)), '%PDF-');
  });

  test('디스크에 파일이 있는 첨부만 고를 수 있다', () async {
    final a = await stored(1, 'abc');
    final missing = a.copyWith(id: 2, fileName: 'gone.aac');
    expect(await exporter.availableIds([a, missing]), {1});
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/guidance/data/guidance_exporter_test.dart`
Expected: FAIL — 파일 없음.

- [ ] **Step 3: 구현**

```dart
// lib/features/guidance/data/guidance_exporter.dart
import 'dart:isolate';
import 'dart:typed_data';

import '../domain/guidance_export.dart';
import '../domain/guidance_models.dart';
import '../domain/guidance_types.dart';
import 'guidance_file_store.dart';
import 'guidance_pdf_builder.dart';
import 'guidance_zip_builder.dart';

class ExportOutput {
  const ExportOutput({required this.fileName, required this.bytes});
  final String fileName;
  final Uint8List bytes;
}

/// 기록 한 건을 내보낼 바이트로 만든다. 파일을 쓰거나 공유하지는 않는다 — 그건 시트의 몫이다.
class GuidanceExporter {
  GuidanceExporter({
    required this.fileStore,
    Future<GuidancePdfFonts> Function()? loadFonts,
    DateTime Function()? clock,
  })  : _loadFonts = loadFonts ?? loadGuidancePdfFonts,
        _clock = clock ?? DateTime.now;

  final GuidanceFileStore fileStore;
  final Future<GuidancePdfFonts> Function() _loadFonts;
  final DateTime Function() _clock;

  /// 안드로이드 백업 복원은 첨부 폴더를 빼고 DB만 살린다 — 파일이 없는 첨부는 고를 수 없다.
  Future<Set<int>> availableIds(List<GuidanceAttachment> attachments) async => {
    for (final a in attachments)
      if (a.id case final id? when !a.isRemoved && await (await fileStore.fileOf(a.fileName)).exists()) id,
  };

  Future<ExportOutput> build({
    required GuidanceRecord record,
    required List<GuidanceAttachment> attachments,
    required Set<int> selectedIds,
    required ExportKind kind,
  }) async {
    final plan = buildExportPlan(createdAt: record.createdAt, attachments: attachments, selectedIds: selectedIds);
    final originals = <int, Uint8List>{
      for (final e in plan.entries) e.no: await (await fileStore.fileOf(e.attachment.fileName)).readAsBytes(),
    };
    final photos = <int, Uint8List?>{};
    for (final e in plan.images) {
      final bytes = originals[e.no];
      // 축소가 가장 무겁다 — 화면이 멈추지 않게 다른 isolate에서.
      photos[e.no] = bytes == null ? null : await Isolate.run(() => shrinkPhotoForPdf(bytes));
    }
    final pdf = await buildGuidancePdf(
      record: record, plan: plan, kind: kind, photos: photos, generatedAt: _clock(), fonts: await _loadFonts(),
    );
    if (kind == ExportKind.pdfOnly) return ExportOutput(fileName: plan.pdfName, bytes: pdf);
    return ExportOutput(
      fileName: plan.zipName,
      bytes: buildGuidanceZip([
        (plan.innerPdfName, pdf),
        for (final e in plan.entries) (e.innerName, originals[e.no] ?? Uint8List(0)),
      ]),
    );
  }
}
```

`if (a.id case final id? when … await …)` 안의 `await`가 컬렉션 if 패턴 가드에서 컴파일되지 않으면 일반 `for` 루프로 풀어 쓴다:

```dart
  Future<Set<int>> availableIds(List<GuidanceAttachment> attachments) async {
    final ids = <int>{};
    for (final a in attachments) {
      final id = a.id;
      if (id == null || a.isRemoved) continue;
      if (await (await fileStore.fileOf(a.fileName)).exists()) ids.add(id);
    }
    return ids;
  }
```

`AttachmentType` import는 쓰지 않으면 지운다(analyze가 잡는다).

provider 추가 — `guidance_providers.dart`의 `guidanceFileStoreProvider` 아래:

```dart
final guidanceExporterProvider = Provider<GuidanceExporter>(
  (ref) => GuidanceExporter(fileStore: ref.watch(guidanceFileStoreProvider)),
);
```

(파일 위쪽에 `import '../../data/guidance_exporter.dart';`)

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/guidance/data/ && flutter analyze lib/features/guidance`
Expected: PASS, 문제 0.

- [ ] **Step 5: 커밋**

```bash
git add lib/features/guidance/data/guidance_exporter.dart lib/features/guidance/presentation/providers/guidance_providers.dart test/features/guidance/data/guidance_exporter_test.dart
git commit -m "feat(guidance): 내보내기 서비스 — 원본 읽기·사진 축소·PDF/ZIP 조립"
```

---

### Task 6: 내보내기 시트 + PC 안내

**Files:**
- Create: `lib/features/guidance/presentation/widgets/guidance_export_sheet.dart`
- Test: `test/features/guidance/presentation/guidance_export_sheet_test.dart`

**Interfaces:**
- Consumes: `GuidanceExporter`·`ExportOutput`·`guidanceExporterProvider`(Task 5), `ExportKind`(Task 2), `SystemSheetGuard.run`(`presentation/lock/system_sheet_guard.dart`), `SheetTitle`(`lib/shared/widgets/sheet_title.dart`), `ButtonSemantics`(`lib/shared/widgets/button_semantics.dart`)
- Produces:
  - `typedef ShareExport = Future<void> Function(ExportOutput out, Rect? origin);`
  - `typedef SaveExport = Future<bool> Function(ExportOutput out);` — 저장했으면 true, 취소면 false
  - `class GuidanceExportSheet extends ConsumerStatefulWidget { GuidanceExportSheet({super.key, required GuidanceRecord record, required List<GuidanceAttachment> attachments, required Set<int> availableIds, bool? isAndroid, ShareExport? share, SaveExport? save}); static const bundleKey, pdfOnlyKey, shareKey, saveKey, guideKey; static Key attachmentKey(int id); }`
  - `Future<void> showGuidanceExportSheet(BuildContext context, WidgetRef ref, {required GuidanceRecord record, required List<GuidanceAttachment> attachments})`

- [ ] **Step 1: 실패하는 테스트**

```dart
// test/features/guidance/presentation/guidance_export_sheet_test.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/guidance/data/guidance_exporter.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_export.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/widgets/guidance_export_sheet.dart';

class FakeExporter extends GuidanceExporter {
  FakeExporter() : super(fileStore: GuidanceFileStore());
  final calls = <(Set<int>, ExportKind)>[];
  @override
  Future<ExportOutput> build({
    required GuidanceRecord record,
    required List<GuidanceAttachment> attachments,
    required Set<int> selectedIds,
    required ExportKind kind,
  }) async {
    calls.add((selectedIds, kind));
    return ExportOutput(fileName: kind == ExportKind.bundle ? 'a.zip' : 'a.pdf', bytes: Uint8List(1));
  }
}

const record = GuidanceRecord(
  id: 1,
  createdAt: '2026-10-04T15:30:00',
  latest: GuidanceRevision(recordId: 1, revisionNo: 1, savedAt: '2026-10-04T15:30:00',
      content: GuidanceContent(title: '복도 다툼')),
);

GuidanceAttachment att(int id, AttachmentType type) => GuidanceAttachment(
  id: id, recordId: 1, type: type, source: AttachmentSource.recorded,
  fileName: '$id', sha256: 'a' * 64, byteSize: 10, durationMs: 1000, attachedAt: '2026-10-04T15:3$id:00',
);

void main() {
  late FakeExporter exporter;
  late List<String> shared;
  late List<String> saved;

  setUp(() {
    exporter = FakeExporter();
    shared = [];
    saved = [];
  });

  Future<void> pump(WidgetTester tester, {
    List<GuidanceAttachment> attachments = const [],
    Set<int>? available,
    bool isAndroid = false,
    Duration shareDelay = Duration.zero,
  }) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [guidanceExporterProvider.overrideWithValue(exporter)],
      child: MaterialApp(
        home: Scaffold(
          body: GuidanceExportSheet(
            key: ValueKey(isAndroid),
            record: record,
            attachments: attachments,
            availableIds: available ?? {for (final a in attachments) a.id ?? -1},
            isAndroid: isAndroid,
            share: (out, _) async {
              shared.add(out.fileName);
              await Future<void>.delayed(shareDelay);
            },
            save: (out) async {
              saved.add(out.fileName);
              return true;
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('첨부가 있으면 ZIP이 기본이고 첨부가 전부 골라져 있다', (tester) async {
    await pump(tester, attachments: [att(1, AttachmentType.audio), att(2, AttachmentType.image)]);
    expect(find.text(GuidanceStrings.exportBundleSubtitle(1, 1)), findsOneWidget);
    await tester.tap(find.byKey(GuidanceExportSheet.shareKey));
    await tester.pumpAndSettle();
    expect(exporter.calls.single, ({1, 2}, ExportKind.bundle));
    expect(shared, ['a.zip']);
  });

  testWidgets('첨부가 없으면 ZIP 줄이 없고 PDF만이 기본이다', (tester) async {
    await pump(tester);
    expect(find.byKey(GuidanceExportSheet.bundleKey), findsNothing);
    await tester.tap(find.byKey(GuidanceExportSheet.shareKey));
    await tester.pumpAndSettle();
    expect(exporter.calls.single.$2, ExportKind.pdfOnly);
  });

  testWidgets('ZIP에서 첨부를 다 빼면 보내기가 꺼지고, PDF만으로 바꾸면 다시 켜진다', (tester) async {
    await pump(tester, attachments: [att(1, AttachmentType.audio)]);
    await tester.tap(find.byKey(GuidanceExportSheet.attachmentKey(1)));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(GuidanceExportSheet.shareKey)).onPressed, isNull);
    await tester.tap(find.byKey(GuidanceExportSheet.pdfOnlyKey));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(GuidanceExportSheet.shareKey)).onPressed, isNotNull);
  });

  testWidgets('파일이 없는 첨부는 꺼져 있고 고를 수 없다', (tester) async {
    await pump(tester, attachments: [att(1, AttachmentType.audio), att(2, AttachmentType.audio)], available: {1});
    expect(find.text(GuidanceStrings.attachmentMissing), findsOneWidget);
    await tester.tap(find.byKey(GuidanceExportSheet.attachmentKey(2)));
    await tester.tap(find.byKey(GuidanceExportSheet.shareKey));
    await tester.pumpAndSettle();
    expect(exporter.calls.single.$1, {1});
  });

  testWidgets('만드는 동안 다시 누를 수 없다', (tester) async {
    await pump(tester, shareDelay: const Duration(seconds: 1));
    await tester.tap(find.byKey(GuidanceExportSheet.shareKey));
    await tester.pump();
    await tester.tap(find.byKey(GuidanceExportSheet.shareKey), warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(shared, hasLength(1));
  });

  testWidgets('아이폰은 공유 하나와 아이폰 안내, 안드로이드는 기기에 저장과 안드로이드 안내', (tester) async {
    await pump(tester, isAndroid: false);
    expect(find.byKey(GuidanceExportSheet.saveKey), findsNothing);
    await tester.tap(find.byKey(GuidanceExportSheet.guideKey));
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.exportPcGuideIos.first, findRichText: true), findsOneWidget);
    expect(find.textContaining('USB 케이블'), findsNothing);

    await pump(tester, isAndroid: true);
    await tester.tap(find.byKey(GuidanceExportSheet.saveKey));
    await tester.pumpAndSettle();
    expect(saved, ['a.pdf']);
    expect(find.text(GuidanceStrings.exportSaved), findsOneWidget);
    await tester.tap(find.byKey(GuidanceExportSheet.guideKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('USB 케이블'), findsOneWidget);
  });

  testWidgets('안내 한 줄이 있다', (tester) async {
    await pump(tester);
    expect(find.text(GuidanceStrings.exportNotice), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/guidance/presentation/guidance_export_sheet_test.dart`
Expected: FAIL — 파일 없음.

- [ ] **Step 3: 구현**

```dart
// lib/features/guidance/presentation/widgets/guidance_export_sheet.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/sheet_title.dart';
import '../../data/guidance_exporter.dart';
import '../../domain/guidance_export.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../../domain/guidance_types.dart';
import '../lock/system_sheet_guard.dart';
import '../providers/guidance_providers.dart';

typedef ShareExport = Future<void> Function(ExportOutput out, Rect? origin);
typedef SaveExport = Future<bool> Function(ExportOutput out);

/// 임시 폴더에 쓰고 공유시트를 연 뒤, 닫히면(결과와 무관) 지운다 — 기록 내용이 담긴 파일이다.
Future<void> _shareViaSheet(ExportOutput out, Rect? origin) async {
  final dir = Directory(p.join((await getTemporaryDirectory()).path, 'guidance_export'));
  await dir.create(recursive: true);
  final file = File(p.join(dir.path, out.fileName));
  await file.writeAsBytes(out.bytes, flush: true);
  try {
    await Share.shareXFiles([XFile(file.path)], sharePositionOrigin: origin);
  } finally {
    try {
      await file.delete();
    } catch (_) {}
  }
}

/// 안드로이드 저장 위치 선택 창(SAF). 공유시트에는 "파일로 저장"하는 공통 항목이 없다.
Future<bool> _saveViaPicker(ExportOutput out) async {
  final path = await SystemSheetGuard.run(
    () => FilePicker.platform.saveFile(fileName: out.fileName, bytes: out.bytes),
  );
  return path != null;
}

Future<void> showGuidanceExportSheet(
  BuildContext context,
  WidgetRef ref, {
  required GuidanceRecord record,
  required List<GuidanceAttachment> attachments,
}) async {
  final available = await ref.read(guidanceExporterProvider).availableIds(attachments);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => GuidanceExportSheet(record: record, attachments: attachments, availableIds: available),
  );
}

class GuidanceExportSheet extends ConsumerStatefulWidget {
  const GuidanceExportSheet({
    super.key,
    required this.record,
    required this.attachments,
    required this.availableIds,
    this.isAndroid,
    this.share,
    this.save,
  });

  final GuidanceRecord record;
  final List<GuidanceAttachment> attachments;
  final Set<int> availableIds;
  final bool? isAndroid;
  final ShareExport? share;
  final SaveExport? save;

  static const bundleKey = Key('guidance_export_bundle');
  static const pdfOnlyKey = Key('guidance_export_pdf_only');
  static const shareKey = Key('guidance_export_share');
  static const saveKey = Key('guidance_export_save');
  static const guideKey = Key('guidance_export_guide');
  static Key attachmentKey(int id) => Key('guidance_export_attachment_$id');

  @override
  ConsumerState<GuidanceExportSheet> createState() => _GuidanceExportSheetState();
}

class _GuidanceExportSheetState extends ConsumerState<GuidanceExportSheet> {
  late final List<GuidanceAttachment> _visible = [
    for (final a in widget.attachments)
      if (!a.isRemoved) a,
  ];
  late final Set<int> _selected = {...widget.availableIds};
  late ExportKind _kind = widget.availableIds.isEmpty ? ExportKind.pdfOnly : ExportKind.bundle;
  final _shareButton = GlobalKey();
  var _busy = false;

  bool get _android => widget.isAndroid ?? Platform.isAndroid;
  bool get _canSend => !_busy && (_kind == ExportKind.pdfOnly || _selected.isNotEmpty);

  Rect? _origin() {
    final box = _shareButton.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _run(Future<void> Function(ExportOutput out) send) async {
    if (!_canSend) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final out = await ref.read(guidanceExporterProvider).build(
        record: widget.record,
        attachments: _visible,
        selectedIds: _selected,
        kind: _kind,
      );
      await send(out);
    } catch (_) {
      // 스낵바에 기록 내용을 넣지 않는다 — 잠금 덮개 밖에 뜬다.
      messenger?.showSnackBar(const SnackBar(content: Text(GuidanceStrings.exportFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() => _run((out) => (widget.share ?? _shareViaSheet)(out, _origin()));

  Future<void> _save() => _run((out) async {
    final ok = await (widget.save ?? _saveViaPicker)(out);
    if (ok && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text(GuidanceStrings.exportSaved)));
    }
  });

  @override
  Widget build(BuildContext context) {
    final audio = _visible.where((a) => a.type == AttachmentType.audio && _selected.contains(a.id)).length;
    final image = _visible.where((a) => a.type == AttachmentType.image && _selected.contains(a.id)).length;
    final now = DateTime.now();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.spacing20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetTitle(GuidanceStrings.export),
            const SizedBox(height: AppSizes.spacing12),
            if (_visible.isNotEmpty)
              RadioListTile<ExportKind>(
                key: GuidanceExportSheet.bundleKey,
                value: ExportKind.bundle,
                groupValue: _kind,
                onChanged: widget.availableIds.isEmpty ? null : (v) => setState(() => _kind = v ?? _kind),
                title: const Text(GuidanceStrings.exportBundle),
                subtitle: Text(GuidanceStrings.exportBundleSubtitle(audio, image)),
              ),
            RadioListTile<ExportKind>(
              key: GuidanceExportSheet.pdfOnlyKey,
              value: ExportKind.pdfOnly,
              groupValue: _kind,
              onChanged: (v) => setState(() => _kind = v ?? _kind),
              title: const Text(GuidanceStrings.exportPdfOnly),
              subtitle: const Text(GuidanceStrings.exportPdfOnlySubtitle),
            ),
            if (_visible.isNotEmpty) ...[
              const SizedBox(height: AppSizes.spacing8),
              Text(GuidanceStrings.labelAttachments, style: AppTextStyles.fieldLabel),
              for (final a in _visible) _attachmentRow(a, now),
            ],
            const SizedBox(height: AppSizes.spacing8),
            _PcGuide(isAndroid: _android),
            const SizedBox(height: AppSizes.spacing12),
            Text(GuidanceStrings.exportNotice, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
            const SizedBox(height: AppSizes.spacing12),
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: AppSizes.spacing8),
            Row(
              children: [
                if (_android) ...[
                  Expanded(
                    child: OutlinedButton(
                      key: GuidanceExportSheet.saveKey,
                      onPressed: _canSend ? _save : null,
                      child: const Text(GuidanceStrings.exportSaveToDevice),
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacing8),
                ],
                Expanded(
                  child: FilledButton(
                    key: GuidanceExportSheet.shareKey,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.goldFill,
                      foregroundColor: AppColors.onGold,
                    ),
                    onPressed: _canSend ? _share : null,
                    child: Text(GuidanceStrings.exportShare, key: _shareButton),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachmentRow(GuidanceAttachment a, DateTime now) {
    final id = a.id;
    final present = id != null && widget.availableIds.contains(id);
    final ms = a.durationMs;
    final size = ms == null ? GuidanceStrings.sizeLabel(a.byteSize) : GuidanceStrings.durationLabel(ms);
    return CheckboxListTile(
      key: GuidanceExportSheet.attachmentKey(id ?? -1),
      value: present && _selected.contains(id),
      onChanged: present
          ? (v) => setState(() => (v ?? false) ? _selected.add(id) : _selected.remove(id))
          : null,
      secondary: Icon(a.type == AttachmentType.audio ? Icons.mic_none : Icons.image_outlined),
      title: Text('${a.type.label} · $size'),
      subtitle: Text(present ? formatStamp(a.capturedAt ?? a.attachedAt, now: now) : GuidanceStrings.attachmentMissing),
    );
  }
}

/// PC로 옮기는 방법 — 기기마다 자기 안내만. 배경·테두리는 Material이 진다(ListTile 위 색 컨테이너 금지).
class _PcGuide extends StatelessWidget {
  const _PcGuide({required this.isAndroid});
  final bool isAndroid;

  @override
  Widget build(BuildContext context) {
    final steps = isAndroid ? GuidanceStrings.exportPcGuideAndroid : GuidanceStrings.exportPcGuideIos;
    return Material(
      color: AppColors.surfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMedium)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: GuidanceExportSheet.guideKey,
        title: const Text(GuidanceStrings.exportPcGuideTitle),
        childrenPadding: const EdgeInsets.fromLTRB(AppSizes.spacing16, 0, AppSizes.spacing16, AppSizes.spacing12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, s) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.spacing4),
              child: Text('${i + 1}. $s', style: AppTextStyles.bodyS),
            ),
        ],
      ),
    );
  }
}
```

구현 메모:
- `AppColors.surfaceVariant`·`AppSizes.radiusMedium`·`AppTextStyles.bodyS`·`AppTextStyles.fieldLabel`이 실제 이름과 다르면 `grep -n "static" lib/core/constants/app_sizes.dart` 등으로 가장 가까운 기존 토큰을 쓴다. 새 토큰은 만들지 않는다.
- `RadioListTile`의 `groupValue`/`onChanged`가 Flutter 3.44에서 deprecated 경고를 내면 `RadioGroup<ExportKind>`으로 감싸는 새 API로 바꾼다(analyze 경고 0이 기준).
- 테스트의 PC 안내 확인에서 `'1. '` 접두 때문에 `find.text(…first)`가 안 걸리면 `find.textContaining(GuidanceStrings.exportPcGuideIos.first)`로 바꾼다.
- `_shareButton` 키를 `Text`에 달아 공유 위치를 구한다(아이패드에서 `sharePositionOrigin` 없으면 예외 — `export_list_tile.dart`와 같은 이유).

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/guidance/presentation/guidance_export_sheet_test.dart && flutter analyze lib/features/guidance`
Expected: PASS, 문제 0.

- [ ] **Step 5: 기존 가드 확인**

Run: `flutter test test/features/guidance/ test/shared/ test/core/`
Expected: PASS — 특히 `guidance_root_navigator_guard_test.dart`(이 파일에 `showDialog`류가 없다), `guidance_isolation_test.dart`, `button_semantics_guard_test.dart`, `no_tooltip_guard_test.dart`, `segmented_button_semantics_test.dart`.

- [ ] **Step 6: 커밋**

```bash
git add lib/features/guidance/presentation/widgets/guidance_export_sheet.dart test/features/guidance/presentation/guidance_export_sheet_test.dart
git commit -m "feat(guidance): 내보내기 시트 — ZIP/PDF만, 첨부 선택, 기기별 PC 안내·저장"
```

---

### Task 7: 기록 보기 연결 + 문서 + 실제 기기 확인

**Files:**
- Modify: `lib/features/guidance/presentation/screens/guidance_detail_screen.dart` (앱바 `actions`)
- Modify: `test/features/guidance/presentation/guidance_detail_screen_test.dart` (테스트 추가)
- Modify: `docs/privacy_policy.md` (§6 한 줄 + 변경 이력)
- Modify: `CLAUDE.md` (기술 스택 표 · 지도 기록 절 · 테스트 수)

**Interfaces:**
- Consumes: `showGuidanceExportSheet`(Task 6)
- Produces: `GuidanceDetailScreen.exportKey`

- [ ] **Step 1: 실패하는 테스트** — `guidance_detail_screen_test.dart`의 `main()` 안 끝에 추가:

```dart
  testWidgets('앱바에 이름 있는 내보내기 버튼이 있고 누르면 시트가 열린다', (tester) async {
    final id = await tester.runAsync(() => repo.create(const GuidanceContent(title: '복도 다툼')));
    await pump(tester, id ?? -1);
    expect(find.bySemanticsLabel(GuidanceStrings.export), findsOneWidget);
    await tester.tap(find.byKey(GuidanceDetailScreen.exportKey));
    await settle(tester);
    expect(find.text(GuidanceStrings.exportPdfOnly), findsOneWidget);
  });
```

`availableIds`가 실제 파일 저장소(`getApplicationSupportDirectory`)를 부르면 테스트에서 멈출 수 있다 — 첨부가 없는 기록이라 `fileOf`가 불리지 않으므로 이 테스트는 플랫폼 채널을 타지 않는다.

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/guidance/presentation/guidance_detail_screen_test.dart`
Expected: FAIL — `exportKey` 없음.

- [ ] **Step 3: 구현** — `GuidanceDetailScreen`에 키와 버튼 추가. `editKey` 아래:

```dart
  static const exportKey = Key('guidance_detail_export');
```

`actions`의 `FilledButton`(수정)과 삭제 `IconButton` 사이에:

```dart
          IconButton(
            key: exportKey,
            icon: const Icon(Icons.ios_share, semanticLabel: GuidanceStrings.export),
            onPressed: record == null
                ? null
                : () => showGuidanceExportSheet(context, ref, record: record, attachments: attachments),
          ),
```

import 추가: `import '../widgets/guidance_export_sheet.dart';`

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/guidance/ && flutter analyze`
Expected: PASS, 문제 0.

- [ ] **Step 5: 개인정보처리방침** — `docs/privacy_policy.md` §6의 `**지도 기록 잠금**` 항목 바로 아래에:

```markdown
- **지도 기록 내보내기**: 지도 기록은 사용자가 기록 보기에서 `내보내기`를 눌러 직접 공유하거나
  기기에 저장할 때만 기기 밖으로 나갑니다. 앱은 파일을 만들어 기기의 공유 화면에 넘길 뿐,
  어떤 서버로도 보내지 않습니다.
```

변경 이력 끝에:

```markdown
- 2026-10-xx: §6에 지도 기록 내보내기(사용자가 직접 공유·저장할 때만 기기 밖으로 나간다)를 추가.
  수집 항목·외부 전송 경로는 그대로다.
```

(`xx`는 실제 날짜로.)

- [ ] **Step 6: 시뮬레이터 확인(iOS)** — `driving-ios-simulator` 스킬을 따른다. 지도 기록을 켜고 잠금을 푼 뒤(꺼진 기능·잠금을 이유로 건너뛰지 않는다):
  1. 사진 하나·녹음 하나가 붙은 기록에서 `내보내기` → 시트(ZIP 기본, 첨부 둘 체크, 안내 한 줄, `공유` 하나, PC 안내에 케이블 없음).
  2. `공유` → 공유시트가 뜨는지. `파일에 저장`으로 저장 → 시뮬레이터 Files에서 ZIP 확인. 공유시트가 떠 있는 동안 지도 기록 가림 면이 앱을 덮는지 스크린샷으로 기록.
  3. 저장된 ZIP을 호스트로 꺼내(`xcrun simctl get_app_container booted com.apple.DocumentsApp data` 또는 Files 앱 경로) `unzip -l`로 이름, `shasum -a 256`으로 원본 해시를 앱의 `첨부 정보` 값과 대조. PDF는 `qlmanage -t`로 PNG를 만들어 한글·표·붙임 사진 확인.
  4. `PDF만`으로도 한 번.

- [ ] **Step 7: 에뮬레이터 확인(안드로이드)** — `api36_pixel7`(메모리 `android_api36_emulator` 참고: `-no-window -no-audio -memory 2048`). 시뮬레이터를 먼저 끈다.
  1. 시트에 `공유`(채움)·`기기에 저장`(테두리), PC 안내 ④ USB 케이블.
  2. `기기에 저장` → 저장 창에서 `Download` → `adb shell ls -la /sdcard/Download/`에 `지도기록_…zip`.
  3. `adb pull`로 꺼내 `unzip -l` · `shasum -a 256` 대조. 저장 창에서 돌아온 뒤 잠금이 다시 걸리지 않는지(15분 안).

  Windows에서 ZIP 풀기·녹음 재생은 사용자 PC 확인 항목으로 보고에 적는다.

- [ ] **Step 8: CLAUDE.md** —
  - 기술 스택 표에 행 추가: `| 내보내기 | pdf <버전> · archive <버전> · image <버전> | 지도 기록 PDF·ZIP 전용(pubspec.lock 실측) |`
  - `### 지도 기록 (선택 탭)` 절 끝에 `- **내보내기**` 항목: 목적지는 학교 PC, ZIP 안 이름 영문·숫자(Windows 한글 깨짐 회피), 원본 store·바이트 그대로, 뺀 첨부 제외, 안드로이드만 `기기에 저장`(SAF), PC 안내 순서와 `서버` 낱말 금지, 스펙 경로, 가드 파일 이름, 시뮬·에뮬 실측 결과(가림 면 여부 포함).
  - 테스트 칸의 숫자를 `flutter test` 실측값으로 고치고 이번에 더한 건수를 적는다.

- [ ] **Step 9: 전체 검증**

Run: `flutter analyze && flutter test`
Expected: 문제 0, 전부 PASS(10월이라 E2E `전체 초기화 플로우`가 실패하는 것은 알려진 일이고 `flutter test`에는 포함되지 않는다).

- [ ] **Step 10: 커밋**

```bash
git add lib/features/guidance/presentation/screens/guidance_detail_screen.dart test/features/guidance/presentation/guidance_detail_screen_test.dart docs/privacy_policy.md CLAUDE.md
git commit -m "feat(guidance): 기록 보기에 내보내기 연결 + 처리방침 §6 + 문서"
```
