/// 일정 검토/확정 UI 문자열.
class ScheduleStrings {
  ScheduleStrings._();

  /// 탭 화면 제목. 이 탭은 업무와 행사를 **둘 다** 넣으므로 그냥 '입력'이다.
  static const title = '입력';

  static const confirm = '확정';
  static const delete = '삭제';

  /// 입력 탭 목록은 **검토 대기만** 담으므로 "등록된 일정이 없다"고 말할 수 없다 —
  /// 확정된 일정이 72건 있어도 이 목록은 비어 있을 수 있다.
  static const empty = '검토할 일정이 없습니다';

  // 종류 (업무 / 행사)
  static const kindTask = '업무';
  static const kindEvent = '행사';

  /// 일괄 확정 pill — 종류별로 나눠 성격이 다른 것이 섞여 확정되지 않게 한다.
  ///
  /// 종류 이름은 **인자로 받는다**([EntryKind.label]). 여기에 `업무`/`행사`를 다시
  /// 박으면 다음 용어 변경 때 배지·필터 칩만 따라가고 이 pill만 옛 이름으로 남는다 —
  /// 직전 main이 정확히 그 상태였다(`kindEvent`는 `학교일정`, pill은 `일괄 일정 등록`).
  ///
  /// **동사도 인자로 받는다** — [confirm]을 보간해 pill·다이얼로그가 한 상수에서
  /// 나오게 한다. 한동안 이 pill만 `등록`이었는데, 그 pill이 여는 다이얼로그는
  /// 제목·본문·버튼이 전부 `확정`이라 버튼과 창이 어긋났다. 게다가 `등록`은
  /// 가져오기 스낵바에서 **검토 대기로 넣기**를 가리켜, 한 낱말이 파이프라인의
  /// 두 단계(넣기·확정)를 동시에 지고 있었다.
  ///
  /// 세 리터럴이 **우연히 일치**하던 것을 보간으로 묶었다 — 테스트로 관찰하던 것을
  /// 컴파일러가 지게 만드는 쪽이 한 단 위다.
  ///
  /// ⚠️ **이 규율이 미치는 범위는 "확정 동작을 가리키는 버튼·다이얼로그 낱말"뿐이다.**
  /// [empty]의 `등록된 일정이 없습니다`처럼 파이프라인 단계를 가리키지 않는
  /// 형용사까지 금지하는 뜻이 아니다.
  /// 건수를 뺀 어간. 스토어 문안이 이 버튼을 제대로 부르는지 검사하는 가드가
  /// 쓴다 — `$n건`이 붙어 있으면 문서에서 부분문자열로 찾을 수 없다.
  static String bulkConfirmLabel(String kindLabel) => '일괄 $kindLabel $confirm';

  static String bulkConfirm(String kindLabel, int n) =>
      '${bulkConfirmLabel(kindLabel)} $n건';

  static const bulkConfirmTitle = '일괄 $confirm';
  static String bulkConfirmMessageFor(String scope, int count) =>
      '$scope 검토 대기 $count건을 확정하고 캘린더에 반영합니다.';

  // 일괄 삭제 pill (확정 대칭) — 남은 검토 대기를 한 번에 휴지통으로
  static String deletePending(int count) => '대기 $count건 삭제';
  static const bulkDeleteTitle = '검토 대기 삭제';

  /// 범위 문구가 없다 — 필터를 없앤 뒤 대상은 언제나 대기 전체다.
  static String bulkDeleteMessage(int count) =>
      '검토 대기 $count건을 휴지통으로 보냅니다.\n'
      '30일 후 자동 삭제되며, 그 전엔 설정 > 휴지통에서 복구할 수 있어요.';
  static String bulkDeletedSnack(int count) => '$count건을 휴지통으로 옮겼어요';

  // 스와이프 삭제 알림. **실행취소 액션은 없다** — 다른 삭제 경로에 없어
  // 여기만 예외였다(2026-09-04). 되돌리기는 휴지통이 맡는다.
  static const deletedSnack = '일정을 삭제했어요';

  // 수정 시트
  static const editTitle = '일정 수정';
  static const titleLabel = '제목';
  static const descriptionHint = '설명 (선택사항)';
  static const dateLabel = '일정 날짜';

  // 스와이프 힌트
  static const slideHintConfirm = '오른쪽으로 밀기 — 확정되어 캘린더 적용';
  static const slideHintDelete = '왼쪽으로 밀기 — 삭제';
}
