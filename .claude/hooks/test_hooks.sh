#!/bin/bash
# 훅 3종 회귀 테스트. 실행: bash .claude/hooks/test_hooks.sh
#
# 훅은 `flutter test`가 스캔하지 않는 자리에 있어 스스로 지켜야 한다. 특히
# **오차단(false positive)** 케이스가 자산이다 — 실제로 밟은 것만 들어 있다:
#   · `rm -f x && git push`          → -f 가 force push로 읽혔다
#   · `rm -f x && flutter test test/` → test/ 가 테스트 삭제로 읽혔다
#   · 커밋 메시지가 위험 플래그를 설명 → 플래그로 읽혔다(2026-08-13, 자기 자신을 막았다)
# 차단 규칙을 손볼 때 이 여섯 건이 먼저 깨지는지 본다.
set -uo pipefail

H="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CLAUDE_PROJECT_DIR="$(cd "$H/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# 기존 테스트 파일 하나를 Write 축소 케이스에 쓴다.
FIXTURE="$CLAUDE_PROJECT_DIR/test/features/today/today_view_test.dart"
[ -f "$FIXTURE" ] || { echo "픽스처가 없습니다: $FIXTURE"; exit 1; }

run() { # run <label> <expected> <script> <json>
  local label="$1" expect="$2" script="$3" json="$4" out code
  out=$(printf '%s' "$json" | "$script" 2>&1); code=$?
  if [ "$code" = "$expect" ]; then
    printf '  ok   %-46s exit %s\n' "$label" "$code"; pass=$((pass+1))
  else
    printf '  FAIL %-46s exit %s (기대 %s)\n       %s\n' \
      "$label" "$code" "$expect" "$(printf '%s' "$out" | head -2)"; fail=$((fail+1))
  fi
}

bash_json()  { jq -n --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}'; }
edit_json()  { jq -n --arg f "$1" --arg o "$2" --arg n "$3" \
                 '{tool_name:"Edit",tool_input:{file_path:$f,old_string:$o,new_string:$n}}'; }
write_json() { jq -n --arg f "$1" --arg c "$2" \
                 '{tool_name:"Write",tool_input:{file_path:$f,content:$c}}'; }
post_json()  { jq -n --arg f "$1" '{tool_name:"Edit",tool_input:{file_path:$f}}'; }

echo "-- guard-bash.sh --"
run "평범한 명령"                     0 "$H/guard-bash.sh" "$(bash_json 'ls -la')"
run "bootstrap (정당한 사용 0)"        2 "$H/guard-bash.sh" "$(bash_json './android/bin/fastlane.sh bootstrap')"
run "--no-verify 플래그"               2 "$H/guard-bash.sh" "$(bash_json 'git commit --no-verify -m x')"
run "git push --force"                2 "$H/guard-bash.sh" "$(bash_json 'git push --force origin main')"
run "git push -f"                     2 "$H/guard-bash.sh" "$(bash_json 'git push -f')"
run "평범한 git push"                 0 "$H/guard-bash.sh" "$(bash_json 'git push origin main')"
run "internal 업로드는 게이트를 탄다"   0 "$H/guard-bash.sh" "$(bash_json './android/bin/fastlane.sh internal')"
run "rm -rf test/"                    2 "$H/guard-bash.sh" "$(bash_json 'rm -rf test/features/bus')"
run "rm -rf build (정상 절차)"         0 "$H/guard-bash.sh" "$(bash_json 'rm -rf build ios/Pods ios/Podfile.lock')"
run "rm -rf ~"                        2 "$H/guard-bash.sh" "$(bash_json 'rm -rf ~')"
# ↓ 오차단 회귀 6건
run "[오차단] rm -f 후 git push"       0 "$H/guard-bash.sh" "$(bash_json 'rm -f tmp.txt && git push origin main')"
run "[오차단] rm 후 flutter test"      0 "$H/guard-bash.sh" "$(bash_json 'rm -f tmp.txt && flutter test test/deploy')"
run "[오차단] 힙독이 플래그 설명"      0 "$H/guard-bash.sh" \
  "$(bash_json "$(printf 'git commit -F - <<%sMSG%s\n- 차단 대상: --no-verify\n- fastlane.sh bootstrap 도 막는다\nMSG' "'" "'")")"
run "[오차단] -m 이 플래그 설명"       0 "$H/guard-bash.sh" \
  "$(bash_json 'git commit -m "docs: --no-verify 를 막는 이유를 적는다"')"
run "[오차단] -m 이 bootstrap 언급"    0 "$H/guard-bash.sh" \
  "$(bash_json 'git commit -m "chore: fastlane.sh bootstrap 문서화"')"

# 프로덕션 승격도 같은 게이트를 탄다. **게이트를 실제로 돌기 때문에 느리다(~15초).**
# 라우팅만 소스로 확인하면 "case에 문자열이 있다"까지만 보이고, 그 아래 fail-closed가
# 실제로 걸리는지는 모른다 — 이 리포에서 스캐너가 언급과 사용을 못 가른 사례가 넷이다.
run "android production (게이트 통과)" 0 "$H/guard-bash.sh" \
  "$(bash_json './android/bin/fastlane.sh production status:completed')"

echo "-- protect-tests.sh --"
run "test 2개 → 1개 (감소)"            2 "$H/protect-tests.sh" \
  "$(edit_json "$FIXTURE" "test('a', () {}); test('b', () {});" "test('a', () {});")"
run "test 1개 → 2개 (증가)"            0 "$H/protect-tests.sh" \
  "$(edit_json "$FIXTURE" "test('a', () {});" "test('a', () {}); test('b', () {});")"
run "개수 동일 (본문만 수정)"          0 "$H/protect-tests.sh" \
  "$(edit_json "$FIXTURE" "test('a', () { expect(1,1); });" "test('a', () { expect(2,2); });")"
run "testWidgets/group 감소"           2 "$H/protect-tests.sh" \
  "$(edit_json "$FIXTURE" "group('g', () { testWidgets('w', (t) async {}); });" "group('g', () {});")"
run "Write 로 통째 축소"               2 "$H/protect-tests.sh" "$(write_json "$FIXTURE" "void main() {}")"
run "새 테스트 파일 (검사 제외)"       0 "$H/protect-tests.sh" \
  "$(write_json "$CLAUDE_PROJECT_DIR/test/features/none_yet_test.dart" "void main() {}")"
run "lib 파일 (대상 아님)"             0 "$H/protect-tests.sh" \
  "$(write_json "$CLAUDE_PROJECT_DIR/lib/main.dart" "void main() {}")"

echo "-- analyze-edited.sh --"
printf 'void main() { int x = ; }\n' > "$TMP/broken.dart"
run "정상 dart 파일"                   0 "$H/analyze-edited.sh" \
  "$(post_json "$CLAUDE_PROJECT_DIR/lib/features/bus/domain/bus_poll_interval.dart")"
run "구문 오류 있는 파일"              2 "$H/analyze-edited.sh" "$(post_json "$TMP/broken.dart")"
run "생성물(.freezed.dart) 건너뜀"     0 "$H/analyze-edited.sh" \
  "$(post_json "$CLAUDE_PROJECT_DIR/lib/features/calendar/domain/calendar_event.freezed.dart")"
run "존재하지 않는 파일"               0 "$H/analyze-edited.sh" "$(post_json "$CLAUDE_PROJECT_DIR/nope.dart")"
run "dart 아닌 파일"                   0 "$H/analyze-edited.sh" "$(post_json "$CLAUDE_PROJECT_DIR/README.md")"

echo
echo "합계: 통과 $pass · 실패 $fail"
[ "$fail" = 0 ]
