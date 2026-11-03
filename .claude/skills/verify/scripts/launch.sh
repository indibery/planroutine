#!/bin/bash
# 시뮬레이터 부팅 → (필요하면) 빌드 → 깨끗하게 설치 → 실행.
# 사용: launch.sh [--keep-data] [--no-build]
#   기본은 앱을 지우고 다시 설치한다(빈 데이터 = 온보딩부터). --keep-data면 데이터를 남긴다.
set -euo pipefail
source "$(dirname "$0")/env.sh"
KEEP=0; BUILD=1
for a in "$@"; do case "$a" in --keep-data) KEEP=1;; --no-build) BUILD=0;; esac; done

state=$(xcrun simctl list devices | grep "$VERIFY_UDID" | grep -o '(Booted)\|(Shutdown)' || true)
BOOTED_NOW=0
if [ "$state" != "(Booted)" ]; then
  wt 60 xcrun simctl boot "$VERIFY_UDID"; BOOTED_NOW=1
  mkdir -p "$VERIFY_EVIDENCE_ROOT" && touch "$VERIFY_EVIDENCE_ROOT/.booted-by-verify"   # cleanup.sh가 이 표시를 보고 끈다
fi
open -a "Device Hub" 2>/dev/null || open -a Simulator 2>/dev/null || true
wt 180 xcrun simctl bootstatus "$VERIFY_UDID" -b >/dev/null

if [ "$BUILD" = 1 ]; then
  (cd "$VERIFY_REPO" && flutter build ios --simulator --debug 2>&1 | tail -2)
fi
[ -d "$VERIFY_APP" ] || { echo "빌드 산출물이 없다: $VERIFY_APP" >&2; exit 1; }

# 부팅 직후 폭주가 가라앉기를 기다린다. 이 상태에서는 시뮬 안 설치가 1초에 끝나도 simctl이 응답을 못 받고 멈춘다.
# 부팅 명령이 끝난 직후에는 폭주가 아직 시작되지 않아 부하가 낮다 — 그 틈에 통과하면 곧 설치가 멈춘다(2026-11-03 실측).
ncpu=$(sysctl -n hw.ncpu)
[ "$BOOTED_NOW" = 1 ] && { echo "방금 부팅했다 — 폭주가 올라올 시간을 90초 준다"; sleep 90; }
for i in $(seq 1 60); do
  load=$(sysctl -n vm.loadavg | awk '{print int($2)}')
  [ "$load" -le "$ncpu" ] && break
  [ $((i % 4)) = 1 ] && echo "CPU 부하 ${load} — 부팅 직후 폭주가 가라앉기를 기다린다 (코어 ${ncpu} 이하까지, 최대 15분)"
  sleep 15
done

# 설치돼 있지 않으면 uninstall이 실패하는데 그건 괜찮다. 시간 초과(124)만 멈춘다.
# simctl 오류만 버리고 wt의 시간 초과 안내는 남긴다(2>/dev/null을 wt 밖에 두면 안내까지 사라진다).
if [ "$KEEP" = 0 ]; then
  rc=0; wt 60 sh -c 'xcrun simctl uninstall "$1" "$2" 2>/dev/null' _ "$VERIFY_UDID" "$VERIFY_BUNDLE" || rc=$?
  [ $rc -ne 124 ] || exit 124
fi
wt 120 xcrun simctl install "$VERIFY_UDID" "$VERIFY_APP"
wt 60 xcrun simctl launch "$VERIFY_UDID" "$VERIFY_BUNDLE"
echo "준비 신호: 화면에 온보딩(새 설치) 또는 탭바가 보이면 준비된 것이다 → doctor.sh로 확인"
