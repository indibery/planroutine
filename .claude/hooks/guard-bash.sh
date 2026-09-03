#!/bin/bash
# PreToolUse(Bash) 가드 — 되돌릴 수 없는 것만 막고, 정당한 사용이 있는 것은 전제조건을 본다.
#
# 종료 코드 규약(code.claude.com/docs/en/hooks 확인):
#   0     → 통과. stdout은 디버그 로그로만 간다(Claude도 사용자도 못 본다)
#   2     → 차단. stderr **전문**이 차단 이유로 Claude에게 전달된다
#   그 밖 → 비차단 오류. 실행은 계속되고 transcript에 stderr **첫 줄만** 뜬다 → 경고 전용
#
# 설계 규칙: deny는 "위험한가"가 아니라 **"정당한 사용이 0인가"** 로 정한다.
# 정당한 사용이 있는 명령(beta)을 매번 막으면 마찰이 쌓이고, 마찰은 훅을 지운다.
set -uo pipefail

# ⚠️ 훅은 로그인 셸을 거치지 않아 /opt/homebrew/bin이 PATH에 없다(실측:
#    bare PATH에서 flutter·dart 모두 not found, jq만 /usr/bin에 있다).
export PATH="/opt/homebrew/bin:$PATH"

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -n "$cmd" ] || exit 0

deny() { printf '%s\n' "$@" >&2; exit 2; }

# 명령 문자열에서 **데이터**를 걷어낸다 — 힙독 본문과 인용 문자열.
#
# 이 가드가 처음 오차단한 것은 자기 자신을 커밋하는 명령이었다(2026-08-13).
# 커밋 메시지가 `--no-verify`를 **설명**하기만 해도 플래그로 읽혔다.
# 플래그는 인용 밖에 있고, 인용·힙독 안은 사람이 읽을 글이다.
#
# ⚠️ 힙독은 **첫 `<<` 뒤를 끝까지** 자른다. `cmd <<EOF … EOF && git push --force`
#    같은 조합은 놓친다 — 자르지 않으면 본문 전체가 다시 스캔돼 같은 오차단이 돌아온다.
# ⚠️ 인용 제거는 줄 단위다. 여러 줄에 걸친 `-m "…"` 안의 플래그는 아직 걸린다.
strip_data() {
  local s=${1%%<<*}
  printf '%s' "$s" | sed -e "s/'[^']*'//g" -e 's/"[^"]*"//g'
}
scan=$(strip_data "$cmd")

# ── ① 정당한 사용이 0인 것 — 무조건 차단 ──

case "$scan" in
  *"fastlane.sh bootstrap"*)
    deny "차단: bootstrap은 패키지명 확정용 1회성이고 이미 소진됐습니다(com.planroutine.app이 Play에 등록됨)." \
         "다시 부르면 internal 트랙에 draft가 올라가 versionCode 하나를 영구히 소비합니다(감소 불가)." \
         "비공개 테스트 업로드는 ./android/bin/fastlane.sh beta 입니다."
    ;;
  *"--no-verify"*)
    deny "차단: --no-verify는 전역 규칙상 사전 확인 대상입니다." \
         "정말 필요하면 사용자가 직접 실행하세요 — 프롬프트에 ! 프리픽스를 붙이면 이 세션에서 바로 돕니다."
    ;;
esac

# ⚠️ 아래 둘은 **명령 세그먼트 단위**로 본다. 명령 전체를 통으로 grep하면
#    `rm -f tmp && flutter test test/foo`가 "rm + test/ 경로"로 읽혀 오차단된다
#    (같은 이유로 `rm -f x && git push`의 `-f`가 force push로 읽힌다).
#    구분자로 쪼갠 뒤 해당 세그먼트만 검사한다.
while IFS= read -r seg; do
  [ -n "$seg" ] || continue

  # force push — 개인 프로젝트도 확인 대상(전역 규칙)
  tail_after_push=${seg#*git push}
  if [ "$tail_after_push" != "$seg" ] \
     && printf '%s' "$tail_after_push" | grep -qE '(--force|--force-with-lease|(^|[[:space:]])-f([[:space:]]|$))'; then
    deny "차단: force push는 되돌릴 수 없습니다(개인 프로젝트도 확인 대상)." \
         "필요하면 사용자가 직접 실행하세요 — ! 프리픽스."
  fi

  # 소스·테스트를 지우는 rm.
  # build/·.dart_tool/·ios/Pods 정리는 이 리포의 정상 절차(수동 캐시 리셋)라 건드리지 않는다.
  if printf '%s' "$seg" | grep -qE '(^|[[:space:]])rm[[:space:]]'; then
    if printf '%s' "$seg" | grep -qE '(^|[[:space:]/"'"'"'])(test|integration_test|lib)/'; then
      deny "차단: rm이 소스/테스트 경로를 가리킵니다(test·integration_test·lib)." \
           "'기존 테스트 삭제 절대 금지'가 전역 규칙입니다." \
           "삭제가 정말 의도라면 사용자가 직접 실행하세요."
    fi
    if printf '%s' "$seg" | grep -qE 'rm[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*(/|~|\$HOME)([[:space:]]|$)'; then
      deny "차단: rm 대상이 루트(/) 또는 홈 디렉터리입니다."
    fi
  fi
done <<EOF
$(printf '%s' "$scan" | tr ';&|' '\n\n\n')
EOF

# ── ② 정당한 사용이 있는 것 — 전제조건 검사 (안 C: analyze + 배포 가드 테스트) ──
#
# iOS beta도 빌드번호를 소비하지만 이 게이트는 Android만 본다(요청 범위).
# 넓히려면 아래 case에 *"ios/bin/fastlane.sh beta"* 를 더한다.
case "$scan" in
  *"android/bin/fastlane.sh beta"*) ;;
  # 프로덕션 승격은 beta보다 더 되돌리기 어렵다 — 같은 게이트를 건다.
  # 기본이 draft라 레인 자체가 한 걸음 남기지만, `status:completed`가 붙으면
  # 그대로 수십억 명에게 열린다.
  *"android/bin/fastlane.sh production"*) ;;
  *) exit 0 ;;
esac

cd "${CLAUDE_PROJECT_DIR:-.}" || deny "차단: 프로젝트 디렉터리로 이동할 수 없습니다."

# fail-closed. 게이트를 돌릴 수 없으면 통과시키지 않는다 —
# 여기서 조용히 통과하면 "게이트가 걸려 있다고 믿는데 안 걸린" 상태가 된다.
command -v flutter >/dev/null 2>&1 || \
  deny "차단: 게이트를 돌릴 수 없습니다 — flutter를 찾지 못했습니다." \
       "PATH=$PATH" \
       "업로드는 release_status: completed 라 즉시 Play 심사로 가고 versionCode는 되돌릴 수 없습니다."

out=$(flutter analyze 2>&1) || deny "차단: flutter analyze 실패 — 업로드는 되돌릴 수 없습니다." "" "$out"

# 문서↔코드 가드만 돈다(실측 12.8초). 전체 926건은 배포 리듬을 해쳐 뺐다 —
# 기능 회귀는 이 게이트가 잡지 않는다는 뜻이다(의도된 한계).
out=$(flutter test test/deploy test/features/settings/data_source_credit_test.dart 2>&1) \
  || deny "차단: 배포 가드 테스트 실패 — 문서·설정·소스가 어긋난 상태입니다." "" \
          "$(printf '%s' "$out" | tail -30)"

# 릴리즈 노트는 **경고만** 한다. 레인이 의도적으로 막지 않는 지점이라(M1 껍데기 업로드를
# 문구 작성에 걸리게 하지 않으려고) 훅이 그 설계 결정을 뒤집지 않는다.
version=$(grep -m1 '^version:' pubspec.yaml | sed -E 's/^version:[[:space:]]*([0-9.]+)\+.*/\1/')
if [ -n "$version" ] \
   && [ ! -f "docs/release_notes/${version}-android.ko.txt" ] \
   && [ ! -f "docs/release_notes/${version}.ko.txt" ]; then
  # exit 1 = 비차단 오류. transcript에 첫 줄만 뜨므로 한 줄에 담는다.
  echo "경고: docs/release_notes/${version}(-android).ko.txt 가 없어 changelog 없이 올라갑니다 — 14일 opt-in 안내가 테스터에게 닿지 않습니다." >&2
  exit 1
fi

exit 0
