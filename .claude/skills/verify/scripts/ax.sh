#!/bin/bash
# iOS 27 시뮬레이터 조작 (MobileBuildMCP snapshot_ui가 "remote automation session" 시간 초과로 안 될 때).
# 번들 AXe만 쓴다. 2026-11-03 포스트잇 검증에서 만든 것.
#   ax.sh ls             라벨 · 타입 · 중심 x · 중심 y · 값 (포인트 단위)
#   ax.sh tap <라벨>      라벨이 그 글자로 시작하는 첫 요소를 짧게 누른다
#   ax.sh xy <x> <y>     좌표를 짧게 누른다
#   ax.sh ko <한글>       한글을 두벌식 자판 키로 바꿔 친다(시뮬 키보드가 한국어일 때). 줄바꿈은 지원하지 않는다
source "$(dirname "$0")/env.sh"
AXE=$(ls ~/.npm/_npx/*/node_modules/mobilebuildmcp/bundled/axe 2>/dev/null | head -1)
[ -x "$AXE" ] || { echo "번들 AXe가 없다 — MobileBuildMCP를 한 번 실행해 npx 캐시를 만든다" >&2; exit 1; }
# 짧은 터치: AXe 기본 tap은 손가락을 오래 붙여 LongPressDraggable(포스트잇 보드)이 끌기로 받는다.
short(){ "$AXE" touch -x "$1" -y "$2" --down --up --delay 0.05 --udid "$VERIFY_UDID" >/dev/null 2>&1; }
dump(){ wt 40 "$AXE" describe-ui --udid "$VERIFY_UDID" 2>/dev/null | python3 -c '
import json,sys
def walk(n):
    f=n.get("frame") or {}; l=(n.get("AXLabel") or "").replace("\n"," / "); v=n.get("AXValue")
    if l or v: print("%s\t%s\t%d\t%d\t%s"%(l,n.get("type"),f.get("x",0)+f.get("width",0)/2,f.get("y",0)+f.get("height",0)/2,v or ""))
    for c in n.get("children") or []: walk(c)
try:
    for r in json.load(sys.stdin): walk(r)
except ValueError: sys.exit("describe-ui 응답이 비었다 — 다시 시도")'; }
case "$1" in
  ls) dump ;;
  tap) line=$(dump | awk -F'\t' -v l="$2" 'index($1,l)==1{print;exit}')
       [ -n "$line" ] || { echo "못 찾음: $2" >&2; exit 1; }
       short "$(echo "$line"|cut -f3)" "$(echo "$line"|cut -f4)"; echo "tap [$(echo "$line"|cut -f1)]" ;;
  xy) short "$2" "$3"; echo "tap ($2,$3)" ;;
  ko) keys=$(python3 -c '
import sys
L="r R s e E f a q Q t T d w W c z x v g".split()
V="k o i O j p u P h hk ho hl y n nj np nl b m ml l".split()
T=[""]+"r R rt s sw sg e f fr fa fq ft fx fv fg a q qt t T d w c z x v g".split()
out=[]
for ch in sys.argv[1]:
    c=ord(ch)-0xAC00
    if 0<=c<11172: out.append(L[c//588]+V[(c%588)//28]+T[c%28])
    else: out.append(ch)
print("".join(out))' "$2")
      "$AXE" type "$keys" --udid "$VERIFY_UDID" >/dev/null && echo "typed: $2" ;;
  *) sed -n '2,8p' "$0"; exit 1 ;;
esac
