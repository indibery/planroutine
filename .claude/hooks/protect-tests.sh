#!/bin/bash
# PreToolUse(Edit|Write) — 테스트 **선언 개수가 줄어드는** 변경만 막는다.
#
# 왜 "테스트 파일 Write 자체 금지"가 아닌가: 전면 재작성은 정당한 사용이 있다
# (큰 리팩터 뒤 구조 변경). 막아야 하는 것은 재작성이 아니라 **감소**다.
# 그래서 선언 수를 세어 비교한다 — 이 리포가 문서↔코드를 기계적으로 대조하는 방식과 같다.
set -uo pipefail

input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')
f=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
[ -n "$f" ] || exit 0

case "$f" in
  */test/*|*/integration_test/*) ;;
  *) exit 0 ;;
esac
case "$f" in
  *.dart) ;;
  *) exit 0 ;;
esac

# testWidgets를 먼저 둔다 — 대안 순서에 의존하는 엔진에서도 긴 쪽이 먼저 물린다.
# ('test(' 는 'testWidgets(' 안에서는 매칭되지 않는다 — test 다음 문자가 W라서.)
count() { printf '%s' "${1:-}" | grep -oE '(testWidgets|test|group)\(' | wc -l | tr -d ' '; }

case "$tool" in
  Write)
    [ -f "$f" ] || exit 0                 # 새 파일은 검사 대상이 아니다
    before=$(count "$(cat "$f")")
    after=$(count "$(printf '%s' "$input" | jq -r '.tool_input.content // empty')")
    ;;
  Edit)
    before=$(count "$(printf '%s' "$input" | jq -r '.tool_input.old_string // empty')")
    after=$(count "$(printf '%s' "$input" | jq -r '.tool_input.new_string // empty')")
    ;;
  *) exit 0 ;;
esac

if [ "$after" -lt "$before" ]; then
  {
    echo "차단: 테스트 선언이 줄어듭니다 (${before} → ${after}) — ${f}"
    echo "'기존 테스트 삭제 절대 금지'가 전역 규칙입니다."
    echo "줄이려던 게 아니라면 Edit 범위를 좁히세요(무관한 test/group 블록을 old_string에 넣지 말 것)."
    echo "정말 정리해야 한다면 사용자에게 먼저 확인하세요."
  } >&2
  exit 2
fi

exit 0
