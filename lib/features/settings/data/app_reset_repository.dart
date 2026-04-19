import '../../../core/database/database_helper.dart';

/// 앱 전체 데이터 초기화 저장소
///
/// 3개 테이블(캘린더 이벤트, 확정 일정, 가져온 일정)의 데이터를 한 번에 삭제한다.
/// 실제 DELETE 로직은 [DatabaseHelper.resetAllData]에 위임한다.
class AppResetRepository {
  final DatabaseHelper _dbHelper;

  AppResetRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<void> resetAll() => _dbHelper.resetAllData();
}
