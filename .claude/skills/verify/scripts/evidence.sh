#!/bin/bash
# 증거 폴더를 만들고 경로를 출력한다. 같은 실행 안에서는 같은 RUN_ID를 쓴다.
# 사용: E=$(evidence.sh <기능-id>)  →  스크린샷: shot.sh "$E" <이름>
source "$(dirname "$0")/env.sh"
RUN_ID="${VERIFY_RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
dir="$VERIFY_EVIDENCE_ROOT/$RUN_ID/${1:-misc}"
mkdir -p "$dir"
(cd "$VERIFY_REPO" && echo "commit $(git rev-parse --short HEAD) $(git status --porcelain | wc -l | tr -d ' ')개 변경") > "$VERIFY_EVIDENCE_ROOT/$RUN_ID/source.txt"
echo "$dir"
