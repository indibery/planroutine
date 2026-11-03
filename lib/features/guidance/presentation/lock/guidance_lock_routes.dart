/// 잠금 없이 볼 수 있는 지도 기록 경로 — 목록과 새 기록 쓰기뿐이다.
/// 예전 기록을 여는 그 밖의 모든 경로는 잠금을 푼 뒤에만 보인다.
const _openPaths = {'/guidance', '/guidance/new'};

/// [path]는 `Uri.path`(쿼리 없음). 끝 슬래시는 무시한다.
bool guidanceRouteRequiresUnlock(String path) {
  final trimmed = path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  return !_openPaths.contains(trimmed);
}
