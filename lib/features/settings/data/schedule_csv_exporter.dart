import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/database_helper.dart';
import '../../schedule/domain/schedule.dart';

/// 올해 확정 일정(`schedules`)을 자체 포맷 CSV로 내보낸다.
///
/// 컬럼: 제목, 날짜, 카테고리, 설명, 상태.
/// 이 포맷은 플랜루틴 재임포트에 호환되도록 설계되어 있다.
class ScheduleCsvExporter {
  ScheduleCsvExporter({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  /// 내보낸 CSV 파일 경로 + 포함된 일정 수를 반환한다.
  Future<({String filePath, int count})> exportActiveSchedules() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseHelper.tableSchedules,
      where: 'deleted_at IS NULL',
      orderBy: 'scheduled_date ASC',
    );
    final schedules = rows.map(Schedule.fromMap).toList();

    // 컬럼명을 기존 parser와 호환되도록 "등록일자" 사용 → 재임포트 round-trip 가능
    final data = <List<dynamic>>[
      const ['제목', '등록일자', '카테고리', '설명', '상태'],
      for (final s in schedules)
        [
          s.title,
          s.scheduledDate,
          s.category ?? '',
          s.description ?? '',
          s.status.value,
        ],
    ];

    final csv = const ListToCsvConverter().convert(data);

    // 임시 디렉토리에 파일명 타임스탬프로 저장
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final ts =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final path = '${dir.path}/planroutine_일정_$ts.csv';

    // UTF-8 BOM + UTF-8 본문 바이트로 저장.
    // (String.codeUnits는 UTF-16이라 writeAsBytes에 쓰면 한글이 깨지므로
    //  반드시 utf8.encode()로 바이트 변환)
    final bytes = <int>[
      0xEF, 0xBB, 0xBF, // UTF-8 BOM (Excel 한글 자동 인식)
      ...utf8.encode(csv),
    ];
    await File(path).writeAsBytes(bytes);

    return (filePath: path, count: schedules.length);
  }
}
