#!/bin/bash
# PostToolUse(Edit|Write) — 편집한 .dart 파일 **하나만** 정적 분석한다.
#
# 실측: 단일 파일 `dart analyze` 0.25초 / 전체 `flutter analyze` 16.8초.
# 그래서 매 편집에 붙일 수 있다. CLAUDE.md의 "analyze 실행해 검증 후 보고"를 산문에서 코드로 옮긴 것.
#
# PostToolUse의 exit 2는 **차단이 아니다**(도구가 이미 실행됨) — stderr를 Claude에게 보여줄 뿐이다.
# 그게 여기서 원하는 동작이다: 방금 만든 오류를 즉시 되돌려 받는다.
#
# ⚠️ `dart format`은 여기 붙이지 않는다. 실측으로 273개 중 177개가 바뀐다
#    (이 리포는 Dart 3.7+ tall-style로 포맷된 적이 없다) — 편집 파일만 포맷해도
#    실제 변경과 포맷 잡음이 한 커밋에 섞인다. 포맷은 훅이 아니라 전용 커밋 1회로.
set -uo pipefail

export PATH="/opt/homebrew/bin:$PATH"

input=$(cat)
f=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
[ -n "$f" ] || exit 0

case "$f" in
  *.freezed.dart|*.g.dart) exit 0 ;;   # build_runner 산출물 — 손으로 고치지 않는다
  *.dart) ;;
  *) exit 0 ;;
esac
[ -f "$f" ] || exit 0                  # 삭제됐거나 경로가 어긋난 경우

# 편의 훅이라 fail-closed가 아니다(배포 게이트와 다른 판단이다). 다만 조용히 죽지도
# 않는다 — 한 줄 경고 + exit 1(비차단)로 "훅이 꺼져 있다"는 사실이 보이게 한다.
command -v dart >/dev/null 2>&1 || {
  echo "경고: dart를 찾지 못해 편집 파일 분석을 건너뜁니다(PATH=$PATH)." >&2
  exit 1
}

out=$(dart analyze "$f" 2>&1) || {
  printf '%s\n' "$out" >&2
  exit 2
}

exit 0
