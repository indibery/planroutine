#!/bin/bash
# fastlane 실행 래퍼.
#
# 사용자 shell 전역 설정을 건드리지 않고, 이 스크립트 내부에서만 Homebrew Ruby
# (/opt/homebrew/opt/ruby/bin)를 PATH 앞에 둬서 Gemfile에 고정한 fastlane +
# cocoapods 짝을 동일 Ruby 환경에서 실행한다.
#
# 사용:
#   ./ios/bin/fastlane.sh beta       # TestFlight 업로드
#   ./ios/bin/fastlane.sh release    # App Store 업로드
set -euo pipefail

RUBY_BIN="/opt/homebrew/opt/ruby/bin"
if [[ ! -x "$RUBY_BIN/bundle" ]]; then
  echo "Homebrew Ruby가 없습니다: $RUBY_BIN" >&2
  echo "brew install ruby 를 먼저 실행하세요." >&2
  exit 1
fi
export PATH="$RUBY_BIN:$PATH"

cd "$(dirname "$0")/.."

if [[ ! -f "Gemfile.lock" ]]; then
  echo "Gemfile.lock이 없습니다. 최초 1회 셋업을 진행합니다."
  bundle config set --local path 'vendor/bundle'
  bundle install
fi

exec bundle exec fastlane "$@"
