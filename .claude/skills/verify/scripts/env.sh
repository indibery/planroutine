#!/bin/bash
# verify 스킬 공용 값. 다른 스크립트가 source 한다.
export VERIFY_UDID="${VERIFY_UDID:-832373BE-F5D2-4FDE-BCF7-65A9D8CD6592}"   # iPhone 17 / iOS 27.0
export VERIFY_BUNDLE="com.planroutine.app"
export VERIFY_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
export VERIFY_APP="$VERIFY_REPO/build/ios/iphonesimulator/Runner.app"
export VERIFY_EVIDENCE_ROOT="$HOME/.planroutine/verify"

# wt <초> <명령…>: 시간 제한을 걸어 실행한다(macOS에는 timeout이 없다).
# simctl은 CoreSimulator가 엉키면 오류 없이 멈춘다(2026-11-03 실측: install·uninstall·get_app_container가
# 무기한 대기). 시간 초과가 나면 exit 124와 함께 복구 방법을 알린다.
wt() {
  local s=$1; shift
  "$@" & local p=$!
  for _ in $(seq 1 "$s"); do kill -0 $p 2>/dev/null || { wait $p; return $?; }; sleep 1; done
  kill $p 2>/dev/null
  echo "✗ 시간 초과(${s}초): $* → xcrun simctl shutdown all; killall -9 com.apple.CoreSimulator.CoreSimulatorService 후 launch.sh 다시" >&2
  return 124
}
