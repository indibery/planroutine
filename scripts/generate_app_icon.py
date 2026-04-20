"""Generate PlanRoutine app icon (1024x1024) — calendar + check motif.

Output: assets/icon/app_icon.png

Design:
  - Rounded-square gradient background (primary blue → primaryLight)
  - Simplified calendar (top tabs + grid with the one "check" cell)
  - Green check mark over the calendar
  - Flat, iOS-friendly aesthetic (no text, no shadows)

Re-run after tweaking constants:
  python3 scripts/generate_app_icon.py
"""
from PIL import Image, ImageDraw

SIZE = 1024
OUT = "assets/icon/app_icon.png"

PRIMARY = (74, 111, 165)         # AppColors.primary 0xFF4A6FA5
PRIMARY_LIGHT = (123, 157, 212)  # 0xFF7B9DD4
PRIMARY_DARK = (27, 68, 120)     # 0xFF1B4478
ACCENT = (16, 185, 129)          # success green 0xFF10B981
WHITE = (255, 255, 255)


def _gradient_bg(size: int) -> Image.Image:
    img = Image.new("RGB", (size, size), PRIMARY)
    for y in range(size):
        t = y / (size - 1)
        r = int(PRIMARY_LIGHT[0] * (1 - t) + PRIMARY_DARK[0] * t)
        g = int(PRIMARY_LIGHT[1] * (1 - t) + PRIMARY_DARK[1] * t)
        b = int(PRIMARY_LIGHT[2] * (1 - t) + PRIMARY_DARK[2] * t)
        ImageDraw.Draw(img).line([(0, y), (size, y)], fill=(r, g, b))
    return img


def _rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size, size), radius=radius, fill=255
    )
    return mask


def _draw_calendar(img: Image.Image) -> None:
    d = ImageDraw.Draw(img)

    # Calendar card — centered white rounded rect
    card_w, card_h = 640, 620
    cx, cy = SIZE // 2, SIZE // 2 + 30
    x0, y0 = cx - card_w // 2, cy - card_h // 2
    x1, y1 = cx + card_w // 2, cy + card_h // 2
    d.rounded_rectangle((x0, y0, x1, y1), radius=60, fill=WHITE)

    # Top bar (month strip)
    bar_h = 120
    d.rounded_rectangle(
        (x0, y0, x1, y0 + bar_h), radius=60, fill=PRIMARY_DARK
    )
    # Cover bottom corners of top bar so only top two stay rounded
    d.rectangle((x0, y0 + bar_h - 60, x1, y0 + bar_h), fill=PRIMARY_DARK)

    # Binding rings on top
    ring_r = 24
    ring_y = y0 - 10
    for rx in (x0 + 140, x1 - 140):
        d.rounded_rectangle(
            (rx - ring_r, ring_y, rx + ring_r, ring_y + 90),
            radius=ring_r,
            fill=PRIMARY_DARK,
        )

    # Grid (4 cols x 4 rows of date cells)
    grid_top = y0 + bar_h + 50
    grid_bottom = y1 - 50
    grid_left = x0 + 50
    grid_right = x1 - 50
    cols, rows = 4, 4
    cell_w = (grid_right - grid_left) / cols
    cell_h = (grid_bottom - grid_top) / rows
    dot_r = 16
    for r in range(rows):
        for c in range(cols):
            px = grid_left + cell_w * c + cell_w / 2
            py = grid_top + cell_h * r + cell_h / 2
            d.ellipse(
                (px - dot_r, py - dot_r, px + dot_r, py + dot_r),
                fill=(210, 215, 225),
            )


def _draw_check(img: Image.Image) -> None:
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy = SIZE // 2 + 140, SIZE // 2 + 90
    r = 180
    # Accent circle
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=ACCENT + (255,))
    # Check mark (3-point polyline, thick)
    stroke = 46
    p1 = (cx - 90, cy + 8)
    p2 = (cx - 18, cy + 76)
    p3 = (cx + 96, cy - 58)
    d.line([p1, p2, p3], fill=WHITE, width=stroke, joint="curve")
    # Round end caps
    for pt in (p1, p2, p3):
        d.ellipse(
            (pt[0] - stroke // 2, pt[1] - stroke // 2,
             pt[0] + stroke // 2, pt[1] + stroke // 2),
            fill=WHITE,
        )


def main() -> None:
    bg = _gradient_bg(SIZE)
    # Round the outer corners slightly — iOS masks automatically but a small
    # inset keeps the gradient visually clean.
    _draw_calendar(bg)
    _draw_check(bg)
    bg.save(OUT, "PNG")
    print(f"Wrote {OUT} ({SIZE}x{SIZE})")


if __name__ == "__main__":
    main()
