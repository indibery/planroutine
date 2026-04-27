# 일정 검토 카테고리 필터 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 일정 검토 화면에 단일 선택 카테고리 필터 추가. "전체 확정" pill을 "이 목록 확정"으로 바꿔 카테고리 필터에 한정 동작하게 변경.

**Architecture:** 라벨 가공은 신규 순수 함수 모듈(`category_label.dart`)로 분리해 타일·필터바가 공유. 카테고리 칩 항목은 `getDistinctCategories()`로 DB에서 빈도순 동적 추출. 필터링은 원본 카테고리 문자열 그대로 repository 쿼리에 전달.

**Tech Stack:** Flutter 3.x, Riverpod, sqflite, freezed (기존 그대로). 신규 의존성 없음.

**Spec:** `docs/superpowers/specs/2026-04-27-schedule-category-filter-design.md`

---

## File Structure

| 종류 | 경로 | 책임 |
|------|------|------|
| Create | `lib/features/schedule/presentation/widgets/category_label.dart` | 표시용 짧은 라벨 + 색상 매핑 (순수 함수) |
| Create | `test/features/schedule/presentation/category_label_test.dart` | 라벨/색상 매핑 단위 테스트 |
| Modify | `lib/features/schedule/data/schedule_repository.dart` | `getDistinctCategories()` 추가, `confirmAllPending` 카테고리 인자 추가 |
| Modify | `test/features/schedule/data/schedule_repository_test.dart` | 신규 메서드 테스트 |
| Modify | `lib/features/schedule/presentation/providers/schedule_providers.dart` | `availableCategoriesProvider` 추가, `confirmAllPending` 동작 변경 |
| Modify | `lib/features/schedule/presentation/widgets/schedule_filter_bar.dart` | 카테고리 줄 추가 |
| Modify | `lib/features/schedule/presentation/widgets/schedule_tile.dart` | 사설 라벨/색상 함수 → 신규 모듈 호출로 교체 |
| Modify | `lib/features/schedule/presentation/screens/schedule_screen.dart` | 빈 상태 판정 + 일괄 확정 메시지 갱신 |
| Modify | `lib/core/constants/strings/schedule_strings.dart` | `confirmAll`, `bulkConfirmMessage` 변경 |

---

### Task 1: category_label 순수 함수 모듈

**Files:**
- Create: `lib/features/schedule/presentation/widgets/category_label.dart`
- Test: `test/features/schedule/presentation/category_label_test.dart`

- [ ] **Step 1: 실패 테스트 작성**

```dart
// test/features/schedule/presentation/category_label_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/features/schedule/presentation/widgets/category_label.dart';

void main() {
  group('shortenCategory', () {
    test('알려진 카테고리는 정해진 짧은 라벨로 매핑', () {
      expect(shortenCategory('일과운영관리'), '일과운영');
      expect(shortenCategory('교육과정계획수립운영'), '교육과정');
      expect(shortenCategory('조직및통계관리'), '조직통계');
      expect(shortenCategory('학생학적관리'), '학생학적');
      expect(shortenCategory('학교행사자율활동'), '학교행사');
      expect(shortenCategory('포상수상대장관리'), '포상수상');
      expect(shortenCategory('학교생활세부사항기록부관리'), '학교생활');
      expect(shortenCategory('학교운영계획수립실적관리'), '학교운영');
      expect(shortenCategory('인사징계위원회구성운영'), '인사징계');
    });

    test('매칭 안 되는 카테고리는 4글자 이내면 그대로', () {
      expect(shortenCategory('기타'), '기타');
      expect(shortenCategory('생활지도'), '생활지도');
    });

    test('매칭 안 되는 5글자 이상 카테고리는 4글자 + 말줄임표', () {
      expect(shortenCategory('알수없는분류명'), '알수없는…');
    });

    test('빈 문자열은 빈 문자열', () {
      expect(shortenCategory(''), '');
    });
  });

  group('categoryColor', () {
    test('주요 4개 카테고리는 전용 색상', () {
      expect(categoryColor('일과운영관리'), AppColors.categoryDailyOps);
      expect(categoryColor('교육과정계획수립운영'), AppColors.categoryCurriculum);
      expect(categoryColor('조직및통계관리'), AppColors.categoryOrganization);
      expect(categoryColor('학생학적관리'), AppColors.categoryStudentRecord);
    });

    test('그 외 카테고리는 기본 색상', () {
      expect(categoryColor('학교행사자율활동'), AppColors.categoryDefault);
      expect(categoryColor(''), AppColors.categoryDefault);
    });
  });
}
```

- [ ] **Step 2: 테스트 실행해 실패 확인**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter test test/features/schedule/presentation/category_label_test.dart`

Expected: FAIL — `category_label.dart` 파일/심볼 없음

- [ ] **Step 3: 모듈 구현**

```dart
// lib/features/schedule/presentation/widgets/category_label.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// 카테고리 원본 → 표시용 짧은 라벨.
///
/// 매칭 우선순위는 부분 일치 순서대로. 어떤 키워드에도 안 잡히면
/// 4글자 이내면 그대로, 5글자 이상이면 앞 4글자 + `…`.
/// 원본 값은 절대 가공해 저장하지 않음 — 표시 직전에만 호출.
String shortenCategory(String raw) {
  if (raw.isEmpty) return '';
  if (raw.contains('일과운영')) return '일과운영';
  if (raw.contains('교육과정')) return '교육과정';
  if (raw.contains('조직') || raw.contains('통계')) return '조직통계';
  if (raw.contains('학적')) return '학생학적';
  if (raw.contains('학교행사') || raw.contains('자율활동')) return '학교행사';
  if (raw.contains('포상') || raw.contains('수상')) return '포상수상';
  if (raw.contains('학교생활') || raw.contains('생활기록')) return '학교생활';
  if (raw.contains('학교운영') || raw.contains('운영계획')) return '학교운영';
  if (raw.contains('인사') || raw.contains('징계')) return '인사징계';
  if (raw.length <= 4) return raw;
  return '${raw.substring(0, 4)}…';
}

/// 카테고리 원본 → pill/뱃지 색상.
Color categoryColor(String raw) {
  if (raw.contains('일과운영')) return AppColors.categoryDailyOps;
  if (raw.contains('교육과정')) return AppColors.categoryCurriculum;
  if (raw.contains('조직') || raw.contains('통계')) {
    return AppColors.categoryOrganization;
  }
  if (raw.contains('학적')) return AppColors.categoryStudentRecord;
  return AppColors.categoryDefault;
}
```

- [ ] **Step 4: 테스트 실행해 통과 확인**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter test test/features/schedule/presentation/category_label_test.dart`

Expected: PASS — 모든 테스트 통과

- [ ] **Step 5: 커밋**

```bash
git add lib/features/schedule/presentation/widgets/category_label.dart test/features/schedule/presentation/category_label_test.dart
git commit -m "$(cat <<'EOF'
feat(schedule): 카테고리 표시 라벨/색상 모듈 추가

타일·필터바가 공유할 순수 함수 shortenCategory/categoryColor를
widgets/category_label.dart로 분리. 알려진 9개 카테고리에 짧은 라벨 매핑.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: schedule_tile에서 사설 함수 제거하고 신규 모듈 사용

**Files:**
- Modify: `lib/features/schedule/presentation/widgets/schedule_tile.dart`

리팩토링 — 동작 변경 없음, 테스트 동일 통과.

- [ ] **Step 1: import 추가, 사설 메서드 호출을 모듈 함수 호출로 교체**

`schedule_tile.dart` 상단 import 블록에 추가:

```dart
import 'category_label.dart';
```

`_buildCategoryBadge` 메서드 내부 색상/라벨 호출을 모듈 함수로 변경. 변경 전:

```dart
Widget _buildCategoryBadge(String category) {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSizes.spacing8,
      vertical: AppSizes.spacing4,
    ),
    decoration: BoxDecoration(
      color: _categoryColor(category).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppSizes.radius8),
    ),
    child: Text(
      _shortenCategory(category),
      style: TextStyle(
        fontSize: 11,
        color: _categoryColor(category),
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
```

변경 후:

```dart
Widget _buildCategoryBadge(String category) {
  final color = categoryColor(category);
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSizes.spacing8,
      vertical: AppSizes.spacing4,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppSizes.radius8),
    ),
    child: Text(
      shortenCategory(category),
      style: TextStyle(
        fontSize: 11,
        color: color,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
```

그리고 클래스 하단의 사설 메서드 두 개를 **삭제**:

```dart
// 삭제 대상
Color _categoryColor(String category) { ... }
String _shortenCategory(String category) { ... }
```

- [ ] **Step 2: analyze 실행**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter analyze`

Expected: PASS, 새 경고 없음

- [ ] **Step 3: 기존 테스트 회귀 확인**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter test test/features/schedule/`

Expected: PASS — 기존 schedule_repository_test, schedule_test, 신규 category_label_test 모두 통과

- [ ] **Step 4: 커밋**

```bash
git add lib/features/schedule/presentation/widgets/schedule_tile.dart
git commit -m "$(cat <<'EOF'
refactor(schedule): 타일에서 카테고리 라벨 함수 외부 모듈로 이동

사설 _shortenCategory/_categoryColor 제거. 동작 변경 없음.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: ScheduleRepository.getDistinctCategories 추가

**Files:**
- Modify: `lib/features/schedule/data/schedule_repository.dart`
- Test: `test/features/schedule/data/schedule_repository_test.dart`

- [ ] **Step 1: 실패 테스트 작성**

`schedule_repository_test.dart`의 마지막 group 뒤에 추가:

```dart
  group('getDistinctCategories', () {
    test('활성 일정의 카테고리만 빈도 내림차순으로 반환', () async {
      final id1 = await seedImportedSchedule(title: 'A1', category: '일과운영관리');
      final id2 = await seedImportedSchedule(title: 'A2', category: '일과운영관리');
      final id3 = await seedImportedSchedule(title: 'A3', category: '일과운영관리');
      final id4 = await seedImportedSchedule(title: 'B1', category: '학생학적관리');
      final id5 = await seedImportedSchedule(title: 'C1', category: '교육과정계획수립운영');
      final id6 = await seedImportedSchedule(title: 'C2', category: '교육과정계획수립운영');
      await repo.createFromImported(id1, DateTime(2026, 1, 1));
      await repo.createFromImported(id2, DateTime(2026, 1, 2));
      await repo.createFromImported(id3, DateTime(2026, 1, 3));
      await repo.createFromImported(id4, DateTime(2026, 2, 1));
      await repo.createFromImported(id5, DateTime(2026, 3, 1));
      await repo.createFromImported(id6, DateTime(2026, 3, 2));

      final categories = await repo.getDistinctCategories();
      expect(categories, [
        '일과운영관리',
        '교육과정계획수립운영',
        '학생학적관리',
      ]);
    });

    test('NULL/빈 문자열 카테고리는 제외', () async {
      final database = await db.database;
      final now = DateTime.now().toIso8601String();
      await database.insert(DatabaseHelper.tableSchedules, {
        'title': 'no-cat',
        'scheduled_date': '2026-01-01',
        'category': null,
        'status': 'pending',
        'created_at': now,
        'updated_at': now,
      });
      await database.insert(DatabaseHelper.tableSchedules, {
        'title': 'empty-cat',
        'scheduled_date': '2026-01-02',
        'category': '',
        'status': 'pending',
        'created_at': now,
        'updated_at': now,
      });
      final id = await seedImportedSchedule(category: '학생학적관리');
      await repo.createFromImported(id, DateTime(2026, 1, 3));

      final categories = await repo.getDistinctCategories();
      expect(categories, ['학생학적관리']);
    });

    test('soft-delete된 일정은 제외', () async {
      final id = await seedImportedSchedule(category: '일과운영관리');
      final sid = await repo.createFromImported(id, DateTime(2026, 1, 1));
      await repo.deleteSchedule(sid);

      expect(await repo.getDistinctCategories(), isEmpty);
    });
  });
```

- [ ] **Step 2: 테스트 실행해 실패 확인**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter test test/features/schedule/data/schedule_repository_test.dart -p vm`

Expected: FAIL — `getDistinctCategories` 메서드 없음

- [ ] **Step 3: 메서드 구현**

`schedule_repository.dart`의 `getSchedules` 메서드 바로 아래(약 137행 다음)에 추가:

```dart
  /// 활성 일정에서 사용 중인 카테고리를 빈도 내림차순으로 반환.
  /// NULL/빈 문자열은 제외. 휴지통 항목은 제외.
  Future<List<String>> getDistinctCategories() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT category, COUNT(*) AS cnt FROM ${DatabaseHelper.tableSchedules} '
      "WHERE deleted_at IS NULL AND category IS NOT NULL AND category != '' "
      'GROUP BY category '
      'ORDER BY cnt DESC, category ASC',
    );
    return result.map((row) => row['category'] as String).toList();
  }
```

- [ ] **Step 4: 테스트 실행해 통과 확인**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter test test/features/schedule/data/schedule_repository_test.dart -p vm`

Expected: PASS — 신규 3 테스트 + 기존 테스트 모두 통과

- [ ] **Step 5: 커밋**

```bash
git add lib/features/schedule/data/schedule_repository.dart test/features/schedule/data/schedule_repository_test.dart
git commit -m "$(cat <<'EOF'
feat(schedule): getDistinctCategories 추가

활성 일정의 카테고리를 빈도 내림차순으로 추출. NULL/빈/휴지통 제외.
필터 칩 항목 동적 구성에 사용.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: confirmAllPending 카테고리 인자 추가

**Files:**
- Modify: `lib/features/schedule/data/schedule_repository.dart`
- Test: `test/features/schedule/data/schedule_repository_test.dart`

- [ ] **Step 1: 실패 테스트 작성**

`schedule_repository_test.dart`의 `deleteAll / confirmAllPending` 그룹 끝(약 255행 직전)에 추가:

```dart
    test('confirmAllPending(category:)는 그 카테고리의 pending만 확정', () async {
      final id1 = await seedImportedSchedule(title: 'A', category: '일과운영관리');
      final id2 = await seedImportedSchedule(title: 'B', category: '일과운영관리');
      final id3 = await seedImportedSchedule(title: 'C', category: '학생학적관리');
      await repo.createFromImported(id1, DateTime(2026, 1, 1));
      await repo.createFromImported(id2, DateTime(2026, 1, 2));
      await repo.createFromImported(id3, DateTime(2026, 2, 1));

      await repo.confirmAllPending(category: '일과운영관리');

      final dailyOps = await repo.getSchedules(category: '일과운영관리');
      expect(dailyOps.every((s) => s.status == ScheduleStatus.confirmed), isTrue);
      final studentRec = await repo.getSchedules(category: '학생학적관리');
      expect(studentRec.first.status, ScheduleStatus.pending);
    });

    test('confirmAllPending(category: null)은 모든 pending 확정 (기존 동작)', () async {
      final id1 = await seedImportedSchedule(title: 'A', category: '일과운영관리');
      final id2 = await seedImportedSchedule(title: 'B', category: '학생학적관리');
      await repo.createFromImported(id1, DateTime(2026, 1, 1));
      await repo.createFromImported(id2, DateTime(2026, 2, 1));

      await repo.confirmAllPending();

      final all = await repo.getSchedules(status: ScheduleStatus.confirmed);
      expect(all.length, 2);
    });
```

- [ ] **Step 2: 테스트 실행해 실패 확인**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter test test/features/schedule/data/schedule_repository_test.dart -p vm`

Expected: FAIL — `confirmAllPending`에 `category` 인자 없음

- [ ] **Step 3: confirmAllPending 시그니처 변경**

`schedule_repository.dart`의 기존 `confirmAllPending`(약 266행) 통째로 교체:

```dart
  /// 검토 대기 상태 일정 일괄 확정.
  /// [category]가 null이면 전체, 값이 있으면 그 카테고리에 한정.
  Future<int> confirmAllPending({String? category}) async {
    final db = await _dbHelper.database;
    final where = <String>[
      'status = ?',
      'deleted_at IS NULL',
    ];
    final whereArgs = <dynamic>[ScheduleStatus.pending.value];
    if (category != null) {
      where.add('category = ?');
      whereArgs.add(category);
    }
    return db.update(
      DatabaseHelper.tableSchedules,
      {
        'status': ScheduleStatus.confirmed.value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: where.join(' AND '),
      whereArgs: whereArgs,
    );
  }
```

- [ ] **Step 4: 테스트 실행해 통과 확인**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter test test/features/schedule/data/schedule_repository_test.dart -p vm`

Expected: PASS — 신규 2 테스트 + 기존 테스트 모두 통과 (`confirmAllPending()` 호출은 인자 없이 그대로 동작)

- [ ] **Step 5: 커밋**

```bash
git add lib/features/schedule/data/schedule_repository.dart test/features/schedule/data/schedule_repository_test.dart
git commit -m "$(cat <<'EOF'
feat(schedule): confirmAllPending에 category 인자 추가

null이면 전역(기존 동작), 값 있으면 해당 카테고리 pending만 확정.
"이 목록 확정" 동작 구현의 backend.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: provider 갱신 — availableCategoriesProvider + confirmAllPending 카테고리 전달

**Files:**
- Modify: `lib/features/schedule/presentation/providers/schedule_providers.dart`

테스트는 통합 테스트로 충분(다음 Task의 화면 단위에서 검증). provider 자체는 얇은 어댑터이므로 단위 테스트 추가 안 함.

- [ ] **Step 1: availableCategoriesProvider 추가**

`schedule_providers.dart`의 `schedulesProvider` 정의(약 22행) 바로 위에 추가:

```dart
/// 현재 활성 일정에서 사용 중인 카테고리 목록 (빈도순).
/// schedulesProvider 변경에 반응해 갱신된다.
final availableCategoriesProvider = FutureProvider<List<String>>((ref) async {
  // schedulesProvider invalidate 시 같이 갱신되도록 의존
  await ref.watch(schedulesProvider.future);
  final repository = ref.watch(scheduleRepositoryProvider);
  return repository.getDistinctCategories();
});
```

- [ ] **Step 2: SchedulesNotifier.confirmAllPending이 카테고리 필터 전달**

기존 `confirmAllPending`(약 78행) 통째로 교체:

```dart
  /// 검토 대기 일정 일괄 확정 (캘린더 이벤트 일괄 생성).
  /// 카테고리 필터가 켜져 있으면 그 카테고리만 대상.
  Future<void> confirmAllPending() async {
    final repository = ref.read(scheduleRepositoryProvider);
    final category = ref.read(scheduleCategoryFilterProvider);

    // 확정 전에 대상 pending 일정 ID를 미리 조회
    final pendingSchedules = await repository.getSchedules(
      status: ScheduleStatus.pending,
      category: category,
    );

    await repository.confirmAllPending(category: category);

    // 각 확정된 일정에 대해 캘린더 이벤트 생성
    final calendarRepo = ref.read(calendarRepositoryProvider);
    for (final schedule in pendingSchedules) {
      if (schedule.id != null) {
        await calendarRepo.createFromSchedule(schedule.id!);
      }
    }
    ref.invalidate(selectedMonthEventsProvider);

    ref.invalidateSelf();
  }
```

- [ ] **Step 3: analyze + test 실행**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter analyze && flutter test test/features/schedule/`

Expected: PASS, 새 경고 없음

- [ ] **Step 4: 커밋**

```bash
git add lib/features/schedule/presentation/providers/schedule_providers.dart
git commit -m "$(cat <<'EOF'
feat(schedule): availableCategoriesProvider + 카테고리 한정 일괄 확정

schedulesProvider에 의존해 변동 시 자동 갱신. confirmAllPending이
현재 카테고리 필터를 읽어 repository에 전달.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: 문자열 변경 — confirmAll, bulkConfirmMessage

**Files:**
- Modify: `lib/core/constants/strings/schedule_strings.dart`

- [ ] **Step 1: 두 상수 변경**

`schedule_strings.dart`의 라인 7과 라인 16을 변경.

변경 전:
```dart
  static const confirmAll = '전체 확정';
```
변경 후:
```dart
  static const confirmAll = '이 목록 확정';
```

변경 전:
```dart
  static const bulkConfirmMessage = '검토 대기 중인 일정을 모두 확정하시겠습니까?';
```
변경 후:
```dart
  static const bulkConfirmMessage = '현재 목록의 검토 대기 일정을 확정하시겠습니까?';
```

- [ ] **Step 2: analyze 실행**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter analyze`

Expected: PASS

- [ ] **Step 3: 커밋**

```bash
git add lib/core/constants/strings/schedule_strings.dart
git commit -m "$(cat <<'EOF'
copy(schedule): "전체 확정" → "이 목록 확정"

카테고리 필터 도입에 맞춰 pill 라벨/다이얼로그 문구 갱신.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: ScheduleFilterBar에 카테고리 줄 추가

**Files:**
- Modify: `lib/features/schedule/presentation/widgets/schedule_filter_bar.dart`

기존 1줄을 2줄로 확장. 카테고리 줄은 `availableCategoriesProvider`를 watch해서 동적으로 pill을 그린다.

- [ ] **Step 1: 파일 통째로 교체**

```dart
// lib/features/schedule/presentation/widgets/schedule_filter_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/pill_chip.dart';
import '../../domain/schedule.dart';
import '../providers/schedule_providers.dart';
import 'category_label.dart';

/// 일정 검토 화면 필터 바.
///
/// 1줄: 상태 필터 (전체/검토 대기/확정됨)
/// 2줄: 카테고리 필터 (전체 + DB에서 동적 추출, 빈도순). 카테고리가 0개면 줄 자체 숨김.
class ScheduleFilterBar extends ConsumerWidget {
  const ScheduleFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _StatusRow(),
        _CategoryRow(),
      ],
    );
  }
}

/// 상태 필터 1줄 (기존 동작 그대로)
class _StatusRow extends ConsumerWidget {
  const _StatusRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStatus = ref.watch(scheduleStatusFilterProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing8,
      ),
      child: Row(
        children: [
          PillChip(
            label: ScheduleStrings.all,
            selected: currentStatus == null,
            onTap: () {
              ref.read(scheduleStatusFilterProvider.notifier).state = null;
            },
          ),
          const SizedBox(width: AppSizes.spacing8),
          PillChip(
            label: ScheduleStrings.pending,
            selected: currentStatus == ScheduleStatus.pending,
            onTap: () {
              ref.read(scheduleStatusFilterProvider.notifier).state =
                  ScheduleStatus.pending;
            },
          ),
          const SizedBox(width: AppSizes.spacing8),
          PillChip(
            label: ScheduleStrings.confirmed,
            selected: currentStatus == ScheduleStatus.confirmed,
            onTap: () {
              ref.read(scheduleStatusFilterProvider.notifier).state =
                  ScheduleStatus.confirmed;
            },
          ),
        ],
      ),
    );
  }
}

/// 카테고리 필터 1줄 (신규).
/// 항목이 0개면 SizedBox.shrink로 줄 자체를 숨김.
class _CategoryRow extends ConsumerWidget {
  const _CategoryRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(availableCategoriesProvider);
    final currentCategory = ref.watch(scheduleCategoryFilterProvider);

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacing16,
            vertical: AppSizes.spacing4,
          ),
          child: Row(
            children: [
              PillChip(
                label: ScheduleStrings.all,
                selected: currentCategory == null,
                onTap: () {
                  ref.read(scheduleCategoryFilterProvider.notifier).state =
                      null;
                },
              ),
              for (final raw in categories) ...[
                const SizedBox(width: AppSizes.spacing8),
                PillChip(
                  label: shortenCategory(raw),
                  selected: currentCategory == raw,
                  onTap: () {
                    ref.read(scheduleCategoryFilterProvider.notifier).state =
                        raw;
                  },
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
```

- [ ] **Step 2: analyze 실행**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter analyze`

Expected: PASS, 새 경고 없음

- [ ] **Step 3: 커밋**

```bash
git add lib/features/schedule/presentation/widgets/schedule_filter_bar.dart
git commit -m "$(cat <<'EOF'
feat(schedule): 필터 바에 카테고리 줄 추가

availableCategoriesProvider에서 빈도순으로 가져온 카테고리를
짧은 라벨로 PillChip 렌더. 단일 선택, "전체"가 필터 해제.
카테고리 0개면 줄 자체 숨김.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: ScheduleScreen 빈 상태 판정 갱신

**Files:**
- Modify: `lib/features/schedule/presentation/screens/schedule_screen.dart`

빈 상태 메시지가 카테고리 필터에도 반응하도록 `hasFilter` 판정을 두 provider 합산으로 변경.

- [ ] **Step 1: _buildEmptyState 수정**

`schedule_screen.dart`의 `_buildEmptyState`(라인 161~186) 통째로 교체:

```dart
  Widget _buildEmptyState(WidgetRef ref) {
    final hasFilter = ref.watch(scheduleStatusFilterProvider) != null
        || ref.watch(scheduleCategoryFilterProvider) != null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_note,
            size: 64,
            color: AppColors.faint,
          ),
          const SizedBox(height: AppSizes.spacing16),
          Text(
            hasFilter
                ? ScheduleStrings.emptyFiltered
                : ScheduleStrings.empty,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: AppColors.sub,
            ),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 2: analyze + 전체 테스트 실행**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter analyze && flutter test`

Expected: PASS — analyze 깨끗, 모든 단위 테스트(109+) 통과

- [ ] **Step 3: 커밋**

```bash
git add lib/features/schedule/presentation/screens/schedule_screen.dart
git commit -m "$(cat <<'EOF'
feat(schedule): 빈 상태 메시지가 카테고리 필터에도 반응

상태 필터 또는 카테고리 필터 중 하나라도 켜졌으면 emptyFiltered.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: 통합 회귀 + 수동 검증

**Files:** 변경 없음

- [ ] **Step 1: 단위 테스트 전체 실행**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter test`

Expected: PASS — 109개 + 신규 5+ 테스트 모두 통과

- [ ] **Step 2: analyze 전체**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter analyze`

Expected: PASS — `No issues found!`

- [ ] **Step 3: 통합 테스트 실행 (시뮬레이터 필요)**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter test integration_test/app_test.dart`

Expected: 11개 시나리오 PASS

⚠️ 통합 테스트 직후 release IPA 빌드를 시도하면 simulator slice가 framework에 남아 altool 91169 에러가 발생함 (CLAUDE.md 알려진 빌드 이슈). Task 10 진입 전 반드시 `flutter clean && rm -rf ios/Pods ios/Podfile.lock ios/build && flutter pub get && (cd ios && pod install)` 순으로 정리.

만약 시뮬레이터 부팅·통합 테스트가 비싸 보이면 Step 3을 건너뛰고 Step 4로 — 이번 변경은 schedule 화면에 한정된 위젯/리포지토리 변경이라 단위 테스트로 회귀가 충분히 잡힌다.

- [ ] **Step 4: clean 빌드 환경 정리** (Step 3 실행한 경우만)

Run:
```bash
cd /Users/kwangsukim/i_code/planroutine
flutter clean
rm -rf ios/Pods ios/Podfile.lock ios/build
flutter pub get
(cd ios && pod install)
```

Expected: 의존성 재설치 정상 완료

---

### Task 10: TestFlight 배포

**Files:** 변경 없음

CLAUDE.md의 **배포 플로우 정책**에 따라 analyze + test 통과 시 사용자 승인 없이 바로 진행.

- [ ] **Step 1: TestFlight 배포**

Run: `cd /Users/kwangsukim/i_code/planroutine && ./ios/bin/fastlane.sh beta`

Expected: build_number 자동 증가 → IPA 빌드 → TestFlight 업로드 성공

배포 실패 시(91169, 인증서 등) 멈춰서 사용자에 보고. 그 외는 다음 단계 진행.

- [ ] **Step 2: 원격 push**

Run: `git push origin main`

Expected: 원격 main에 본 작업의 커밋들이 반영

---

## Self-Review

### Spec coverage

| Spec 요건 | 구현 Task |
|-----------|-----------|
| 카테고리 필터 추가 (단일 선택) | Task 7 |
| DB 동적 추출 (빈도순) | Task 3 + Task 5 |
| 짧은 라벨 표시 (원본 보존) | Task 1 + Task 7 |
| 수정 시트 변경 없음 | (의도적 미수정 — 어떤 Task에서도 schedule_edit_sheet.dart 손대지 않음) |
| "전체 확정" → "이 목록 확정" | Task 6 |
| 카테고리 필터 한정 확정 | Task 4 + Task 5 |
| 다이얼로그 메시지 갱신 | Task 6 |
| 빈 상태 판정 갱신 | Task 8 |
| AND 조건 합성 | Repository 기존 동작(`getSchedules`)이 그대로 처리 — 추가 작업 불필요 |
| 카테고리 0개 시 줄 숨김 | Task 7 (`if (categories.isEmpty) return SizedBox.shrink()`) |
| Repository/라벨 단위 테스트 | Task 1 + Task 3 + Task 4 |

모든 spec 요건이 Task에 매핑됨. 빈 항목 없음.

### Placeholder scan

전체 plan에 "TBD", "TODO", "implement later", 추상 지시문 없음. 모든 코드 step에 실제 코드 포함. 모든 명령에 expected 결과 명시.

### Type consistency

- `getDistinctCategories()` (Task 3) → `availableCategoriesProvider` (Task 5) → `_CategoryRow` (Task 7) 모두 `List<String>`/`Future<List<String>>` 일관.
- `confirmAllPending({String? category})` (Task 4) → `SchedulesNotifier.confirmAllPending` (Task 5)이 동일 시그니처로 호출.
- `shortenCategory(String)` (Task 1) → `schedule_tile.dart` (Task 2) + `_CategoryRow` (Task 7)에서 동일 시그니처로 호출.

타입/시그니처 충돌 없음.
