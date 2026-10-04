import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';
import 'package:planroutine/features/guidance/data/guidance_people_repository.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/data/recording_marker_store.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

/// ADTS 프레임 하나(44.1kHz 모노).
List<int> frame(int length) {
  final h = List<int>.filled(length, 0);
  h[0] = 0xFF;
  h[1] = 0xF1;
  h[2] = (1 << 6) | (4 << 2);
  h[3] = (1 << 6) | ((length >> 11) & 0x03);
  h[4] = (length >> 3) & 0xFF;
  h[5] = ((length & 0x07) << 5) | 0x1F;
  h[6] = 0xFC;
  return h;
}

/// 녹음 도중 방전·강제 종료되면 앱이 마무리할 틈이 없다. 녹음을 시작할 때 "녹음 중" 표시를
/// 남겨 두고, 다음에 앱을 열면 그 파일을 기록에 붙인다(사용자 요청 2026-10-04).
void main() {
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late Directory base;
  late ProviderContainer c;
  late GuidanceFileStore files;
  late GuidanceRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = freshDatabaseHelper();
    repo = GuidanceRepository(dbHelper: db);
    base = await Directory.systemTemp.createTemp('guidance_recovery');
    files = GuidanceFileStore(baseDir: () async => base);
    c = ProviderContainer(
      overrides: [
        guidanceRepositoryProvider.overrideWithValue(repo),
        guidancePeopleRepositoryProvider.overrideWithValue(
          GuidancePeopleRepository(dbHelper: db),
        ),
        guidanceFileStoreProvider.overrideWithValue(files),
      ],
    );
  });
  tearDown(() async {
    c.dispose();
    await db.close();
    await base.delete(recursive: true);
  });

  RecordingMarkerStore store() => c.read(recordingMarkerStoreProvider);

  /// 녹음을 시작한 뒤 앱이 꺼진 상태 — 기록은 있고, 파일은 반쯤 쓰였고, 표시가 남아 있다.
  Future<(int, String)> interrupted({List<int>? bytes}) async {
    final actions = c.read(guidanceActionsProvider);
    final id = await actions.create(
      const GuidanceContent(title: '10월 4일 지도 기록 1'),
    );
    final path = await files.newRecordingPath();
    File(path).writeAsBytesSync(
      bytes ?? [...frame(200), ...frame(200), ...frame(200).sublist(0, 30)],
    );
    await actions.markRecording(
      recordId: id,
      path: path,
      startedAt: DateTime(2026, 10, 4, 15, 30),
    );
    return (id, path);
  }

  test('남은 녹음을 그 기록에 붙이고 기록 번호를 돌려준다 — 잘린 꼬리는 버린다', () async {
    final (id, path) = await interrupted();
    final recovered = await c
        .read(guidanceActionsProvider)
        .recoverInterruptedRecording();
    expect(recovered, id);
    final atts = await repo.getAttachments(id);
    expect(atts, hasLength(1));
    expect(atts.single.source, AttachmentSource.recorded);
    expect(atts.single.byteSize, 400, reason: '온전한 프레임 둘만 남긴다');
    expect(atts.single.durationMs, (2 * 1024 * 1000 / 44100).round());
    expect(
      atts.single.capturedAt,
      DateTime(2026, 10, 4, 15, 30).toIso8601String(),
    );
    expect(File(path).lengthSync(), 400);
    expect(await store().read(), isNull, reason: '되살렸으면 표시를 지운다');
  });

  test('녹음 중 표시가 없으면 아무것도 하지 않는다', () async {
    expect(
      await c.read(guidanceActionsProvider).recoverInterruptedRecording(),
      isNull,
    );
  });

  test('정상적으로 붙은 녹음은 표시가 지워져 다시 붙지 않는다', () async {
    final (id, path) = await interrupted(bytes: [...frame(200)]);
    final actions = c.read(guidanceActionsProvider);
    await actions.attachRecording(
      recordId: id,
      path: path,
      durationMs: 23,
      startedAt: DateTime(2026, 10, 4),
    );
    expect(await store().read(), isNull);
    expect(await actions.recoverInterruptedRecording(), isNull);
    expect(await repo.getAttachments(id), hasLength(1));
  });

  test('표시는 남았지만 이미 붙은 파일이면 다시 붙이지 않고 표시만 지운다', () async {
    final (id, path) = await interrupted(bytes: [...frame(200)]);
    final actions = c.read(guidanceActionsProvider);
    // 붙인 직후 표시를 지우기 전에 꺼진 경우
    await actions.attachRecording(
      recordId: id,
      path: path,
      durationMs: 23,
      startedAt: DateTime(2026, 10, 4),
    );
    await actions.markRecording(
      recordId: id,
      path: path,
      startedAt: DateTime(2026, 10, 4),
    );
    expect(await actions.recoverInterruptedRecording(), isNull);
    expect(await repo.getAttachments(id), hasLength(1));
    expect(await store().read(), isNull);
  });

  test('기록이 지워졌으면 붙이지 않고 표시만 지운다', () async {
    final (id, _) = await interrupted();
    await c.read(guidanceActionsProvider).delete(id);
    expect(
      await c.read(guidanceActionsProvider).recoverInterruptedRecording(),
      isNull,
    );
    expect(await store().read(), isNull);
  });

  test('파일이 없거나 온전한 프레임이 하나도 없으면 표시만 지운다', () async {
    final (id, _) = await interrupted(bytes: frame(200).sublist(0, 5));
    expect(
      await c.read(guidanceActionsProvider).recoverInterruptedRecording(),
      isNull,
    );
    expect(await repo.getAttachments(id), isEmpty);
    expect(await store().read(), isNull);
  });

  test('앱을 열면 끊긴 녹음을 되살리고 그 기록의 쓰기 화면으로 간다', () {
    // 시작 배선은 위젯 테스트로 앱 전체를 띄우기 무거워 소스로 묶는다(SystemOverlayRegion 가드와 같은 방식).
    final code = File('lib/app.dart').readAsStringSync();
    expect(code, contains('recoverInterruptedRecording()'));
    expect(code, contains('AppRoutes.guidanceEdit('));
    expect(
      code,
      contains('ModuleIds.guidance'),
      reason: '지도 기록을 끈 사용자는 화면을 옮기지 않는다',
    );
  });
}
