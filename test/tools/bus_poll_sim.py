#!/usr/bin/env python3
"""버스 폴링 규칙 시뮬레이션.

지금(30초 고정)과 제안 규칙을 같은 상황에 돌려 두 가지를 잰다.
  ① 호출 수 — 90분 창 기준
  ② 도착 순간의 표시 오차 — 버스가 실제로 온 그 순간 화면이 몇 분이라고 하고 있었나

②가 "놓칠 위험"의 대리 지표다. 0에 가까울수록 화면을 믿고 나가면 버스를 탄다.

⚠️ 서버 예측이 시간에 따라 수정되는 정도(drift)는 **가정**이다. 실측이 아니다.
   그래서 drift 없는 경우(순수 staleness)도 함께 찍는다 — 규칙 자체의 비용과
   가정에서 오는 비용을 분리해서 보기 위해서.
"""
import random
from dataclasses import dataclass

# ── 제안 규칙 상수 (실기기에서 조율할 값) ──────────────────────────
URGENT_UNDER = 3 * 60      # 1차가 이 안이면 임박
ALT_FAR_OVER = 5 * 60      # 대안이 이보다 멀면 "놓치면 비싸다"
IV_URGENT = 45
IV_UNKNOWN = 180
IV_RELAX = 300
BASELINE = 30

WINDOW = 90 * 60           # 90분 창
DT = 1                     # 1초 단위 (앱의 보간 주기와 같다)


AFTER_ARRIVAL = 30         # 보이는 버스가 지나간 뒤 이만큼 지나면 반드시 재조회


def interval_proposed(first, alt, cap_at_arrival=True):
    """제안 규칙. first=1차 남은초(표시값), alt=다음 대안까지 초(None이면 모름)."""
    if first is None:
        return None                      # ① 도착 없음 → 중단
    if alt is None:
        iv = IV_UNKNOWN                  # ③ 대안 모름
    elif first <= URGENT_UNDER and alt > ALT_FAR_OVER:
        iv = IV_URGENT                   # ② 놓치면 비싼 순간
    else:
        iv = IV_RELAX                    # ④ 그 밖

    # ⑤ **보이는 버스가 도착하기 전에 반드시 다시 물어본다.**
    #    이게 없으면 간격이 배차보다 길어질 때 지나간 버스의 카운트다운이
    #    화면에 남고(`arrSec`은 0에서 멈춘다) `곧 도착`이 몇 분씩 붙박이가 된다.
    if cap_at_arrival:
        iv = min(iv, max(20, first + AFTER_ARRIVAL))
    return iv


@dataclass
class Route:
    name: str
    headway: int               # 초
    phase: int = 0


class Stop:
    """선택한 노선들의 도착 시각을 생성한다."""

    def __init__(self, routes, rng, jitter=0.12):
        self.routes = routes
        self.rng = rng
        # 각 노선의 실제 도착 시각들 (창보다 넉넉히)
        self.arrivals = {}
        for r in routes:
            ts, t = [], r.phase
            while t < WINDOW + 3600:
                ts.append(t)
                t += max(60, int(r.headway * (1 + rng.gauss(0, jitter))))
            self.arrivals[r.name] = ts

    def next_two(self, name, now):
        ts = [t for t in self.arrivals[name] if t >= now]
        return (ts[0] - now if ts else None,
                ts[1] - now if len(ts) > 1 else None)


def observe(true_sec, rng, drift):
    """서버가 그 순간 내놓는 예측. drift=0이면 완벽한 서버."""
    if true_sec is None:
        return None
    sigma = min(drift * true_sec, 180)
    return max(0, int(true_sec + rng.gauss(0, sigma)))


def run(stop, rule, rng, drift):
    """한 창을 시뮬레이션. (호출 수, 도착 순간 오차 리스트) 반환."""
    calls = 0
    next_poll = 0
    snapshot = {}        # name -> (관측 1차, 관측 2차, 관측 시각)
    errors = []

    # 도착 순간을 미리 모아 둔다(선택 노선의 실제 도착만 본다)
    moments = sorted(
        (t, r.name) for r in stop.routes for t in stop.arrivals[r.name]
        if 0 <= t < WINDOW
    )
    mi = 0

    for now in range(0, WINDOW, DT):
        if next_poll is not None and now >= next_poll:
            calls += 1
            for r in stop.routes:
                t1, t2 = stop.next_two(r.name, now)
                snapshot[r.name] = (observe(t1, rng, drift),
                                    observe(t2, rng, drift), now)
            # 표시값(보간)으로 다음 간격을 정한다 — 앱이 보는 것과 같다
            roll = rule == 'rollover'
            first, alt = _shown(snapshot, now, roll)
            if rule == 'proposed':
                iv = interval_proposed(first, alt)
            elif rule == 'nocap':
                iv = interval_proposed(first, alt, cap_at_arrival=False)
            elif rule == 'rollover':
                # 굴릴 수 있으면 도착 전 재조회 강제를 풀어도 목록이 안 썩는다.
                iv = interval_proposed(first, alt, cap_at_arrival=False)
            else:
                # 지금 동작: 도착이 있든 없든 30초마다 계속 물어본다
                iv = BASELINE
            next_poll = None if iv is None else now + iv

        # 실제 도착 순간마다 화면이 뭐라고 하고 있었는지 기록
        while mi < len(moments) and moments[mi][0] == now:
            name = moments[mi][1]
            snap = snapshot.get(name)
            if snap:
                a, _ = displayed(snap, now, rule == 'rollover')
                if a is not None:
                    errors.append(abs(a))       # 0이어야 정확
            mi += 1

    return calls, errors


def displayed(snap, now, rollover):
    """한 노선이 지금 화면에 내놓는 (1차, 2차). 없으면 (None, None).

    rollover=True면 **지나간 버스를 요청 없이 2차로 갈아끼운다** — 2차를 이미
    받아 뒀으므로 목록을 로컬에서 한 칸 굴릴 수 있다.
    """
    s1, s2, at = snap
    if s1 is None:
        return (None, None)
    e = now - at
    a, b = s1 - e, (s2 - e if s2 is not None else None)
    if a > -20:
        return (a, b)
    if rollover and b is not None and b > -20:
        return (b, None)      # 한 칸 굴렸다. 그 다음은 모른다
    return (None, None)


def _shown(snapshot, now, rollover=False):
    """지금 화면에 뜨는 1차와 다음 대안까지의 간격."""
    vis = []
    for name, snap in snapshot.items():
        a, b = displayed(snap, now, rollover)
        if a is not None:
            vis.append((a, b))
    if not vis:
        return (None, None)
    vis.sort(key=lambda v: v[0])
    first = max(0, vis[0][0])
    if len(vis) >= 2:
        alt = max(0, vis[1][0]) - first
    elif vis[0][1] is not None:
        alt = max(0, vis[0][1]) - first
    else:
        alt = None
    return (first, alt)


SCENARIOS = [
    ('도심 간선 · 3대 선택', [Route('A', 4 * 60), Route('B', 6 * 60, 90), Route('C', 8 * 60, 200)]),
    ('아파트 앞 · 2대 선택', [Route('A', 8 * 60), Route('B', 15 * 60, 300)]),
    ('마을버스 · 1대 선택', [Route('A', 20 * 60)]),
    ('실측 A정류장 · 4대', [Route('5623', 5 * 60), Route('15', 3 * 60, 60),
                            Route('6501', 5 * 60, 150), Route('87', 26 * 60, 400)]),
    ('실측 B정류장 · 3대', [Route('92', 9 * 60), Route('82-1', 24 * 60, 120),
                            Route('61', 18 * 60, 300)]),
    ('배차 긴 1대 · 30분', [Route('A', 30 * 60)]),
]


def main():
    for drift, label in [(0.0, 'drift 없음 (순수 staleness)'), (0.12, 'drift 12% (가정)')]:
        print(f'\n{"═" * 78}\n  {label}\n{"═" * 78}')
        print(f'{"시나리오":<22}{"30초":>6}{"⑤강제":>8}{"굴리기":>8}'
              f'{"오차 ⑤":>10}{"오차 굴리기":>13}{"p90 굴리기":>12}')
        print('─' * 78)
        for name, routes in SCENARIOS:
            res = {k: ([], []) for k in ('baseline', 'proposed', 'rollover')}
            for seed in range(40):
                for k in res:
                    stop = Stop(routes, random.Random(seed))
                    c, e = run(stop, k, random.Random(seed + 1000), drift)
                    res[k][0].append(c); res[k][1].extend(e)

            def avg(xs):
                return sum(xs) / len(xs) if xs else 0

            bc = avg(res['baseline'][0])
            pc, rc = avg(res['proposed'][0]), avg(res['rollover'][0])
            pe, re_ = avg(res['proposed'][1]), avg(res['rollover'][1])
            errs = sorted(res['rollover'][1])
            p90 = errs[int(len(errs) * 0.9)] if errs else 0
            print(f'{name:<22}{bc:>6.0f}{pc:>8.0f}{rc:>8.0f}'
                  f'{pe:>9.0f}초{re_:>12.0f}초{p90:>11.0f}초')


if __name__ == '__main__':
    main()
