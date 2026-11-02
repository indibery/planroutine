#!/bin/bash
# 시뮬레이터 부팅 → (필요하면) 빌드 → 깨끗하게 설치 → 실행.
# 사용: launch.sh [--keep-data] [--no-build]
#   기본은 앱을 지우고 다시 설치한다(빈 데이터 = 온보딩부터). --keep-data면 데이터를 남긴다.
set -euo pipefail
source "$(dirname "$0")/env.sh"
KEEP=0; BUILD=1
for a in "$@"; do case "$a" in --keep-data) KEEP=1;; --no-build) BUILD=0;; esac; done

state=$(xcrun simctl list devices | grep "$VERIFY_UDID" | grep -o '(Booted)\|(Shutdown)' || true)
if [ "$state" != "(Booted)" ]; then
  wt 60 xcrun simctl boot "$VERIFY_UDID"
  mkdir -p "$VERIFY_EVIDENCE_ROOT" && touch "$VERIFY_EVIDENCE_ROOT/.booted-by-verify"   # cleanup.sh가 이 표시를 보고 끈다
fi
open -a "Device Hub" 2>/dev/null || open -a Simulator 2>/dev/null || true
wt 180 xcrun simctl bootstatus "$VERIFY_UDID" -b >/dev/null

if [ "$BUILD" = 1 ]; then
  (cd "$VERIFY_REPO" && flutter build ios --simulator --debug 2>&1 | tail -2)
fi
[ -d "$VERIFY_APP" ] || { echo "빌드 산출물이 없다: $VERIFY_APP" >&2; exit 1; }

if [ "$KEEP" = 0 ]; then wt 60 xcrun simctl uninstall "$VERIFY_UDID" "$VERIFY_BUNDLE" 2>/dev/null || [ $? -ne 124 ] || exit 124; fi
wt 120 xcrun simctl install "$VERIFY_UDID" "$VERIFY_APP"
wt 60 xcrun simctl launch "$VERIFY_UDID" "$VERIFY_BUNDLE"
echo "준비 신호: 화면에 온보딩(새 설치) 또는 탭바가 보이면 준비된 것이다 → doctor.sh로 확인"
