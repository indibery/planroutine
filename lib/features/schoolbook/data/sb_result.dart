/// 스쿨북 요청의 결과 갈래. 화면은 이 값으로 문구를 고른다.
enum SbOutcome {
  ok,

  /// `400` — 입력이 규칙에 안 맞거나 자리가 없다. `detail`을 그대로 보여 준다.
  rejected,

  /// `401` — 학교 코드가 없거나 틀렸다(학교가 지워졌을 수도 있다).
  unauthorized,

  /// `403`, 또는 로그인했는데 교시가 하나도 없다 — 스쿨북에서 교시를 먼저 등록해야 한다.
  noPeriods,

  /// `404` — 없는 대상(지워진 교실·예약). 서버 문구가 영어라 보여 주지 않는다.
  notFound,

  /// 시간 초과 · 연결 실패 · `429` · `5xx` · 형식이 다른 응답. **예약·취소에서는 결과를 모른다.**
  network,
}

/// 던지지 않는 결과. 버스 기능의 `TagoResult`처럼 `isOk` 게터를 두지 않는다 —
/// 부르는 쪽이 갈래를 모두 다루게 하려는 것이다.
class SbResult<T> {
  const SbResult(this.outcome, {this.value, this.detail});

  final SbOutcome outcome;
  final T? value;
  final String? detail;
}
