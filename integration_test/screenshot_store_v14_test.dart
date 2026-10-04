// ignore_for_file: avoid_print
//
// 1.4.0 스토어 스크린샷용 **원본 화면** 촬영 — 지도 기록·내보내기·기능 관리·포스트잇 + 오늘·캘린더.
// 홍보 문구와 배경은 이 화면 위에 따로 합성한다(docs/screenshots/store_v14/).
//
// 실행:
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshot_store_v14_test.dart -d <UDID>
//
// 결과: docs/screenshots/raw/*.png
// 데이터는 전부 가상의 예시다(실제 학생·학교 이름 금지).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:planroutine/app.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/core/dev/screenshot_seed.dart';
import 'package:planroutine/core/modules/app_module.dart';
import 'package:planroutine/core/modules/installed_modules_provider.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/domain/participant.dart';
import 'package:planroutine/features/guidance/presentation/lock/device_authenticator.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_detail_screen.dart';
import 'package:planroutine/features/memo/data/memo_repository.dart';
import 'package:planroutine/features/memo/domain/memo_color.dart';
import 'package:planroutine/features/settings/presentation/providers/stamp_settings_provider.dart';
import 'package:planroutine/shared/widgets/floating_tab_bar.dart';

/// 촬영 중 잠금은 통과시킨다 — 시뮬레이터에 Face ID 창을 띄우지 않는다.
class _PassAuth implements DeviceAuthenticator {
  @override
  Future<AuthOutcome> authenticate(String reason) async => AuthOutcome.success;
}

/// 칠판 사진처럼 보이는 첨부 — 실제 사진을 쓰지 않는다.
List<int> _boardPhoto() {
  final im = img.Image(width: 1200, height: 900);
  img.fill(im, color: img.ColorRgb8(46, 84, 64));
  img.fillRect(im, x1: 0, y1: 820, x2: 1200, y2: 900, color: img.ColorRgb8(150, 110, 70));
  for (var i = 0; i < 6; i++) {
    final y = 150 + i * 105;
    img.drawLine(im, x1: 140, y1: y, x2: 520 + (i * 90) % 400, y2: y, color: img.ColorRgb8(232, 236, 230), thickness: 6);
  }
  img.drawCircle(im, x: 960, y: 300, radius: 110, color: img.ColorRgb8(240, 220, 160));
  return img.encodeJpg(im, quality: 88);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('1.4.0 스토어 원본 화면 촬영', (tester) async {
    await DatabaseHelper.instance.resetAllData();
    final container = ProviderContainer(
      overrides: [deviceAuthenticatorProvider.overrideWithValue(_PassAuth())],
    );
    await seedScreenshotData(container);
    await container.read(stampSettingsProvider.notifier).setDimPreviousStamps(false);

    // 포스트잇
    final memos = MemoRepository();
    final now = DateTime.now();
    final memoSeed = [
      ('학년 협의회 안건 — 현장체험학습 장소 후보 두 곳 비교해 오기', MemoColor.yellow, now.add(const Duration(days: 2))),
      ('방과후 강사 연락처 받기', MemoColor.green, null),
      ('2학기 상담 주간 안내장 초안\n보호자 회신 마감일 함께 적기', MemoColor.blue, now.add(const Duration(days: 5))),
      ('과학실 실험 도구 대여 신청', MemoColor.pink, null),
    ];
    for (final (text, color, date) in memoSeed.reversed) {
      final m = await memos.add(text);
      await memos.update(m.copyWith(color: color, memoDate: date));
    }

    // 지도 기록 — 가상의 세 건
    final repo = GuidanceRepository();
    final store = GuidanceFileStore();
    final today = DateTime(now.year, now.month, now.day);
    await repo.create(GuidanceContent(
      kind: GuidanceKind.guidance,
      status: GuidanceStatus.closedAtSchool,
      title: '쉬는 시간 교실 물건 다툼',
      occurredAt: today.subtract(const Duration(days: 6)).add(const Duration(hours: 10, minutes: 40)),
      place: '4학년 2반 교실',
      participants: const [Participant(name: '정유나'), Participant(name: '한지우')],
      facts: '지우개를 두고 말다툼. 담임이 분리 후 각각 이야기를 들음.',
      actions: '서로 사과하고 마무리.',
    ));
    await repo.create(GuidanceContent(
      kind: GuidanceKind.infringement,
      status: GuidanceStatus.open,
      title: '하교 후 학부모 항의 전화',
      occurredAt: today.subtract(const Duration(days: 2)).add(const Duration(hours: 16, minutes: 20)),
      place: '교무실(학교 전화)',
      participants: const [Participant(name: '이도윤 보호자')],
      facts: '모둠 활동 역할 배정에 대해 약 25분간 항의함.',
      quotes: '"선생님이 우리 애만 미워하는 거 아니에요?"',
      actions: '통화 직후 교감 선생님께 보고.',
    ));
    final mainId = await repo.create(GuidanceContent(
      kind: GuidanceKind.guidance,
      status: GuidanceStatus.open,
      title: '점심시간 복도 다툼',
      occurredAt: today.add(const Duration(hours: 12, minutes: 40)),
      place: '3층 복도',
      participants: const [Participant(name: '김하늘'), Participant(name: '박서준')],
      facts: '점심시간 복도에서 줄 서는 순서로 말다툼을 하다 서로 어깨를 밀침.\n옆 반 학생이 알려 와 현장에서 분리함. 다친 곳은 없음.',
      quotes: '김하늘: "내가 먼저 서 있었는데 밀고 들어왔어요."\n박서준: "자리 맡아 둔 거라고 했잖아."',
      actions: '두 학생 각각 면담 후 사과하도록 지도함.\n오후 알림장으로 양쪽 보호자에게 경위 안내.',
    ));
    final tmp = await getTemporaryDirectory();
    Future<void> attach(String name, List<int> bytes, AttachmentType type, AttachmentSource src, int? ms) async {
      final f = File('${tmp.path}/$name')..writeAsBytesSync(bytes);
      final s = await store.importCopy(f.path);
      await repo.addAttachment(GuidanceAttachment(
        recordId: mainId, type: type, source: src, fileName: s.fileName, sha256: s.sha256,
        byteSize: s.byteSize, durationMs: ms, attachedAt: DateTime.now().toIso8601String(),
      ));
    }
    await attach('voice.aac', base64Decode(_voiceAac), AttachmentType.audio, AttachmentSource.recorded, 192000);
    await attach('board.jpg', _boardPhoto(), AttachmentType.image, AttachmentSource.imported, null);

    // 선택 기능 둘을 켠다 — 탭이 늘어난 모습이 곧 '기능 관리'의 결과다.
    final modules = container.read(installedModulesProvider.notifier);
    await modules.setEnabled(ModuleIds.memo, true);
    await modules.setEnabled(ModuleIds.guidance, true);

    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const PlanRoutineApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    var surfaceReady = false;
    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      if (!surfaceReady) {
        await binding.convertFlutterSurfaceToImage();
        surfaceReady = true;
      }
      // 마지막 포인터 위치의 조준선이 찍히지 않게 한 프레임 더(screenshot_test.dart 참고).
      await tester.pumpAndSettle();
      await binding.takeScreenshot('raw/$name');
    }

    Finder tab(String label) => find.descendant(of: find.byType(FloatingTabBar), matching: find.text(label));

    await shot('today');

    await tester.tap(tab(AppStrings.tabCalendar));
    await shot('calendar');

    await tester.tap(tab(MemoStrings.tabLabel));
    await shot('memo');

    await tester.tap(tab(GuidanceStrings.tabLabel));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await shot('guidance_list');

    await tester.tap(find.text('점심시간 복도 다툼'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await shot('guidance_detail');

    await tester.tap(find.byKey(GuidanceDetailScreen.exportKey));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await shot('guidance_export');

    // 시트를 닫고 설정 › 기능 관리
    await tester.tapAt(const Offset(20, 80));
    await tester.pumpAndSettle();
    await tester.tap(tab(SettingsStrings.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(SettingsStrings.modulesTitle).first);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await shot('modules');
  });
}

const _voiceAac = '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';
