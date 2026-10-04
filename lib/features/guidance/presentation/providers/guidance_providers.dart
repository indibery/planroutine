import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/guidance_file_store.dart';
import '../../data/guidance_people_repository.dart';
import '../../data/guidance_repository.dart';
import '../../data/recording_marker_store.dart';
import '../../domain/adts.dart';
import '../../domain/guidance_content.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../../domain/guidance_types.dart';
import '../../domain/participant.dart';

final guidanceRepositoryProvider = Provider<GuidanceRepository>((ref) => GuidanceRepository());

final guidancePeopleRepositoryProvider = Provider<GuidancePeopleRepository>(
  (ref) => GuidancePeopleRepository(),
);

final guidanceFileStoreProvider = Provider<GuidanceFileStore>((ref) => GuidanceFileStore());

/// "녹음 중" 표시 — 방전·강제 종료로 끊긴 녹음을 다음 실행 때 되살린다.
final recordingMarkerStoreProvider = Provider<RecordingMarkerStore>((ref) => RecordingMarkerStore());

/// 지도 기록이 바뀌었다는 신호. 목록·보기·이력이 watch해 다시 읽는다.
final guidanceChangedProvider = StateProvider<int>((ref) => 0);

final guidanceRecordsProvider = FutureProvider.autoDispose<List<GuidanceRecord>>((ref) {
  ref.watch(guidanceChangedProvider);
  return ref.watch(guidanceRepositoryProvider).getActive();
});

final guidanceDeletedRecordsProvider = FutureProvider.autoDispose<List<GuidanceRecord>>((ref) {
  ref.watch(guidanceChangedProvider);
  return ref.watch(guidanceRepositoryProvider).getDeleted();
});

final guidanceRecordProvider = FutureProvider.autoDispose.family<GuidanceRecord?, int>((ref, id) {
  ref.watch(guidanceChangedProvider);
  return ref.watch(guidanceRepositoryProvider).getRecord(id);
});

final guidanceRevisionsProvider =
    FutureProvider.autoDispose.family<List<GuidanceRevision>, int>((ref, id) {
      ref.watch(guidanceChangedProvider);
      return ref.watch(guidanceRepositoryProvider).getRevisions(id);
    });

final guidanceAttachmentsProvider =
    FutureProvider.autoDispose.family<List<GuidanceAttachment>, int>((ref, id) {
      ref.watch(guidanceChangedProvider);
      return ref.watch(guidanceRepositoryProvider).getAttachments(id);
    });

final guidancePeopleProvider = FutureProvider.autoDispose<List<GuidancePerson>>((ref) {
  ref.watch(guidanceChangedProvider);
  return ref.watch(guidancePeopleRepositoryProvider).getActive();
});

/// 목록의 구분 필터. null = 전체. 탭을 떠나면 풀린다(autoDispose).
final guidanceKindFilterProvider = StateProvider.autoDispose<GuidanceKind?>((ref) => null);

/// 목록의 사람 필터. null = 전체.
final guidancePersonFilterProvider = StateProvider.autoDispose<Participant?>((ref) => null);

final visibleGuidanceRecordsProvider =
    Provider.autoDispose<AsyncValue<List<GuidanceRecord>>>((ref) {
      final kind = ref.watch(guidanceKindFilterProvider);
      final person = ref.watch(guidancePersonFilterProvider);
      return ref
          .watch(guidanceRecordsProvider)
          .whenData((list) => filterRecords(sortRecords(list), kind: kind, person: person));
    });

final guidanceActionsProvider = Provider<GuidanceActions>((ref) => GuidanceActions(ref));

/// 지도 기록의 모든 변경은 여기를 거친다 — 끝에 신호를 올려 화면들이 다시 읽게 한다.
class GuidanceActions {
  GuidanceActions(this._ref);

  final Ref _ref;

  GuidanceRepository get _repo => _ref.read(guidanceRepositoryProvider);
  GuidancePeopleRepository get _people => _ref.read(guidancePeopleRepositoryProvider);
  GuidanceFileStore get _files => _ref.read(guidanceFileStoreProvider);
  RecordingMarkerStore get _marker => _ref.read(recordingMarkerStoreProvider);

  void _changed() => _ref.read(guidanceChangedProvider.notifier).state++;

  /// 관련인 이름을 명단에 기억하고(이름 추천용) 그 id를 `personId`로 채운다.
  /// 같은 이름 = 같은 사람. 판에 들어가는 것은 여전히 저장 시점의 사본이다.
  Future<GuidanceContent> _remember(GuidanceContent content) async {
    final names = [for (final x in content.participants) x.name];
    if (names.every((n) => n.trim().isEmpty)) return content;
    final ids = await _people.remember(names);
    return content.copyWith(
      participants: [
        for (final x in content.participants) x.copyWith(personId: ids[x.name.trim()] ?? x.personId),
      ],
    );
  }

  Future<int> create(GuidanceContent content) async {
    final id = await _repo.create(await _remember(content));
    _changed();
    return id;
  }

  /// 같은 내용이면 판을 만들지 않고 false. `personId`만 달라진 것은 같은 내용이다([sameContent]).
  Future<bool> save(int id, GuidanceContent content) async {
    final saved = await _repo.saveRevision(id, await _remember(content));
    if (saved) _changed();
    return saved;
  }

  Future<void> delete(int id) async {
    await _repo.softDelete(id);
    _changed();
  }

  Future<void> restore(int id) async {
    await _repo.restore(id);
    _changed();
  }

  /// DB를 먼저 지우고 그 기록의 파일만 지운다.
  Future<void> permanentDelete(int id) async {
    final names = await _repo.permanentDelete(id);
    await _files.deleteFiles(names);
    _changed();
  }

  /// 가져온 파일을 첨부 폴더로 그대로 복사하고 해시를 남긴다.
  /// `captured_at`은 비운다 — 고르기 창이 넘겨주는 것은 임시 사본이라 그 파일의 시각은
  /// 원본의 시각이 아니다. 원래 파일 이름은 남긴다.
  Future<GuidanceAttachment> attachImported({
    required int recordId,
    required String sourcePath,
    required AttachmentType type,
    String? originalName,
  }) async {
    final stored = await _files.importCopy(sourcePath);
    final a = await _repo.addAttachment(
      GuidanceAttachment(
        recordId: recordId,
        type: type,
        source: AttachmentSource.imported,
        fileName: stored.fileName,
        originalName: originalName,
        sha256: stored.sha256,
        byteSize: stored.byteSize,
        attachedAt: DateTime.now().toIso8601String(),
      ),
    );
    _changed();
    return a;
  }

  /// 녹음을 시작하기 **직전에** 남긴다. 앱이 마무리할 틈 없이 꺼지면 이 표시가 남는다.
  Future<void> markRecording({required int recordId, required String path, required DateTime startedAt}) =>
      _marker.save(RecordingMarker(recordId: recordId, fileName: p.basename(path), startedAt: startedAt));

  /// 녹음을 시작하지 못했을 때 표시를 거둔다.
  Future<void> clearRecordingMarker() => _marker.clear();

  /// 지난 실행에서 끊긴 녹음을 그 기록에 붙이고 기록 번호를 돌려준다. 되살릴 것이 없으면 null.
  ///
  /// 녹음은 ADTS AAC라 끊겨도 그때까지는 재생된다 — 마지막 잘린 프레임만 잘라 내고 붙인다.
  /// 기록이 지워졌거나, 파일이 없거나, 이미 붙은 파일이면 표시만 지운다(파일은 지우지 않는다).
  Future<int?> recoverInterruptedRecording() async {
    final m = await _marker.read();
    if (m == null) return null;
    try {
      final record = await _repo.getRecord(m.recordId);
      if (record == null || record.deletedAt != null) return null;
      final attached = await _repo.getAttachments(m.recordId);
      if (attached.any((a) => a.fileName == m.fileName)) return null;
      final file = await _files.fileOf(m.fileName);
      if (!await file.exists()) return null;
      final scan = scanAdts(await file.readAsBytes());
      if (scan.frames == 0) return null;
      final raf = await file.open(mode: FileMode.append);
      await raf.truncate(scan.completeLength);
      await raf.close();
      await attachRecording(
        recordId: m.recordId,
        path: file.path,
        durationMs: scan.durationMs,
        startedAt: m.startedAt,
      );
      return m.recordId;
    } finally {
      await _marker.clear();
    }
  }

  /// 녹음은 처음부터 첨부 폴더 안에 쓰인다([GuidanceFileStore.newRecordingPath]).
  Future<GuidanceAttachment> attachRecording({
    required int recordId,
    required String path,
    required int durationMs,
    required DateTime startedAt,
  }) async {
    final stored = await _files.describe(p.basename(path));
    final a = await _repo.addAttachment(
      GuidanceAttachment(
        recordId: recordId,
        type: AttachmentType.audio,
        source: AttachmentSource.recorded,
        fileName: stored.fileName,
        sha256: stored.sha256,
        byteSize: stored.byteSize,
        durationMs: durationMs,
        capturedAt: startedAt.toIso8601String(),
        attachedAt: DateTime.now().toIso8601String(),
      ),
    );
    // 붙었으면 "녹음 중" 표시는 할 일을 다했다 — 같은 파일일 때만 지운다(다른 녹음의 표시를 지우지 않게).
    // 표시는 보조 수단이다 — 읽거나 지우다 실패해도 첨부는 이미 끝났으니 막지 않는다.
    try {
      if ((await _marker.read())?.fileName == stored.fileName) await _marker.clear();
    } catch (_) {}
    _changed();
    return a;
  }

  Future<void> removeAttachment(int attachmentId) async {
    await _repo.removeAttachment(attachmentId);
    _changed();
  }
}
