import '../../../core/database/database_helper.dart';
import '../../guidance/data/guidance_file_store.dart';

/// 앱 전체 데이터 초기화 저장소
///
/// 테이블(캘린더 이벤트, 확정 일정, 가져온 일정, 포스트잇, 지도 기록 넷)의 데이터를 한 번에
/// 삭제하고, 지도 기록 첨부 폴더도 비운다. DELETE 로직은 [DatabaseHelper.resetAllData]에 위임한다.
class AppResetRepository {
  final DatabaseHelper _dbHelper;
  final GuidanceFileStore _guidanceFiles;

  AppResetRepository({DatabaseHelper? dbHelper, GuidanceFileStore? guidanceFiles})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance,
      _guidanceFiles = guidanceFiles ?? GuidanceFileStore();

  /// DB를 먼저 비운다 — 파일을 먼저 지우고 DB가 실패하면 행만 남고 파일이 없는 첨부가 생긴다.
  Future<void> resetAll() async {
    await _dbHelper.resetAllData();
    await _guidanceFiles.wipe();
  }
}
