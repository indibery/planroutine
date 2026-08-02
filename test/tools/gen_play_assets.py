#!/usr/bin/env python3
"""Play Store 등록정보용 그래픽 자료를 만든다.

    python3 test/tools/gen_play_assets.py

산출물은 `docs/screenshots/playstore/`에 떨어진다.

**왜 스크립트인가** — 세 자료 모두 기존 소재에서 파생된다. 손으로 만들면 브랜드 색이나
로고가 어긋나도 눈으로 봐야 알고, 스크린샷을 다시 찍을 때마다 반복해야 한다.
(아이콘을 `gen_app_icon.dart`가 코드로 렌더하는 것과 같은 이유다.)

**세 자료**

1. `icon_512.png` — Play 스토어 아이콘. `assets/icon/app_icon.png`(1024²) 축소.
2. `feature_graphic.png` — 1024×500. 리포에 대응물이 없어 여기서 처음 만든다.
3. `screenshot_*.png` — **비율만 고친다.** Play는 최대변 ≤ 최소변 × 2를 요구하는데
   기존 App Store 자료는 1284×2778(비 2.163)이라 탈락한다. 크롭하면 내용이 잘리므로
   **좌우에 배경색 여백을 붙여** 1389×2778(정확히 2.0)로 만든다.
   가장자리 색이 전부 #F7F8FB(라이트 배경)라 이음매가 보이지 않는다(실측).

⚠️ 스크린샷은 **iOS 화면이라 임시다.** 지금 목적은 트랙 잠금을 푸는 것이고,
Android 실물은 M2에서 찍어 교체한다(그때 이 스크립트의 SRC만 바꾸면 된다).
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SRC_ICON = ROOT / "assets/icon/app_icon.png"
SRC_SHOTS = sorted((ROOT / "docs/screenshots/appstore/6.5").glob("*.png"))
FONT_PATH = ROOT / "assets/fonts/PretendardVariable.ttf"
OUT = ROOT / "docs/screenshots/playstore"

# lib/core/constants/app_colors.dart 의 다크 팔레트에서 가져온다.
NAVY = (30, 58, 95)        # #1E3A5F  브랜드 네이비
GOLD = (184, 150, 12)      # #B8960C  골드
CREAM = (245, 243, 238)    # #F5F3EE  크림
SHOT_BG = (247, 248, 251)  # #F7F8FB  스크린샷 가장자리 실측색


def _font(size: int, weight: int = 400) -> ImageFont.FreeTypeFont:
    """Pretendard Variable을 굵기와 함께 연다.

    가변 폰트라 축을 지정하지 않으면 Regular로 그려진다. FreeType이 축 설정을
    지원하지 않는 환경에서는 조용히 Regular로 떨어진다 — 글자가 안 나오는 것보다 낫다.
    """
    f = ImageFont.truetype(str(FONT_PATH), size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def make_icon() -> None:
    """512×512 스토어 아이콘. adaptive icon과 별개 자산이다."""
    im = Image.open(SRC_ICON).convert("RGBA").resize((512, 512), Image.LANCZOS)
    im.save(OUT / "icon_512.png")
    print(f"  icon_512.png            512x512")


def make_feature_graphic() -> None:
    """1024×500 그래픽 이미지.

    스토어 상단에 크게 걸리는 배너다. 스크린샷이 라이트 테마라 여기는 **네이비**로 둬서
    목록에서 눈에 띄게 한다 — 브랜드 정체성(네이비+골드)과도 맞는다.
    """
    W, H = 1024, 500
    im = Image.new("RGB", (W, H), NAVY)
    d = ImageDraw.Draw(im)

    # 아래로 갈수록 아주 살짝 어둡게 — 단색보다 깊이가 생긴다.
    for y in range(H):
        k = 1.0 - (y / H) * 0.18
        d.line([(0, y), (W, y)], fill=tuple(int(c * k) for c in NAVY))

    # 로고 + 텍스트를 한 덩어리로 보고 **가로 중앙**에 놓는다.
    # Play는 기기 폭에 따라 이 배너의 좌우를 잘라내므로, 가장자리에 붙은 요소는 사라진다.
    logo_size = 260
    gap = 64
    title_f, sub_f = _font(84, 700), _font(34, 500)
    title, sub = "공직플랜", "교직원 업무 일정 관리"
    text_w = max(d.textlength(title, font=title_f), d.textlength(sub, font=sub_f))
    block_w = logo_size + gap + text_w
    left = int((W - block_w) / 2)

    # app_icon.png는 네이비 배경이 이미 칠해져 있어 그대로 얹으면 사각형이 보인다
    # → 둥근 마스크로 잘라 배지처럼 놓는다.
    logo = Image.open(SRC_ICON).convert("RGBA").resize((logo_size, logo_size), Image.LANCZOS)
    mask = Image.new("L", (logo_size, logo_size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, logo_size - 1, logo_size - 1], radius=int(logo_size * 0.22), fill=255
    )
    im.paste(logo, (left, (H - logo_size) // 2), mask)

    x = left + logo_size + gap
    d.text((x, 178), title, font=title_f, fill=CREAM)
    d.text((x, 286), sub, font=sub_f, fill=(200, 210, 225))

    # 골드 언더라인 — 골드는 이 앱에서 강조 전용이라 얇게만 쓴다.
    d.rounded_rectangle([x, 348, x + 132, 354], radius=3, fill=GOLD)

    im.save(OUT / "feature_graphic.png")
    print(f"  feature_graphic.png    {W}x{H}")


def make_screenshots() -> None:
    """비율만 2.0으로 고친다. 크롭이 아니라 좌우 패딩이라 내용이 안 잘린다."""
    for src in SRC_SHOTS:
        im = Image.open(src).convert("RGB")
        w, h = im.size
        target_w = -(-h // 2)  # ceil(h/2) — 비율이 2.0을 넘지 않는 최소 폭
        if target_w <= w:
            print(f"  {src.name:20} 이미 규격 통과 — 그대로 복사")
            out = im
        else:
            out = Image.new("RGB", (target_w, h), SHOT_BG)
            out.paste(im, ((target_w - w) // 2, 0))
        name = f"screenshot_{src.stem}.png"
        out.save(OUT / name)
        ratio = max(out.size) / min(out.size)
        print(f"  {name:28} {out.size[0]}x{out.size[1]}  비 {ratio:.3f}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    print(f"→ {OUT.relative_to(ROOT)}")
    make_icon()
    make_feature_graphic()
    make_screenshots()
    print("\n⚠️ 스크린샷은 iOS 화면이다. M2에서 Android 실물로 교체할 것.")


if __name__ == "__main__":
    main()
