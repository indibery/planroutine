#!/usr/bin/env python3
"""
Claude Design HTML → Flutter app_colors.dart 초안 추출 스크립트

사용법:
  python3 scripts/parse_design_html.py <design.html>

출력:
  - 콘솔: 추출된 색상/폰트/간격 목록
  - lib/core/constants/app_colors.dart.draft: 초안 (검토 후 교체)
"""

import re
import sys
from pathlib import Path


def extract_css_vars(html: str) -> dict:
    """CSS :root 또는 인라인 style에서 CSS custom properties 추출"""
    pattern = r'--([\w-]+)\s*:\s*([^;}\n]+)'
    matches = re.findall(pattern, html)
    return {name.strip(): value.strip() for name, value in matches}


def hex_to_flutter(hex_color: str):
    """#RRGGBB 또는 #AARRGGBB → Flutter Color(0xFFRRGGBB)"""
    hex_color = hex_color.strip()
    if hex_color.startswith('#'):
        h = hex_color[1:]
        if len(h) == 6:
            return f"Color(0xFF{h.upper()})"
        if len(h) == 8:
            return f"Color(0x{h.upper()})"
    return None


def rgb_to_hex(rgb: str):
    """rgb(r, g, b) → #RRGGBB"""
    m = re.match(r'rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)', rgb)
    if m:
        r, g, b = int(m.group(1)), int(m.group(2)), int(m.group(3))
        return f"#{r:02X}{g:02X}{b:02X}"
    return None


def normalize_color(value: str):
    """색상 값을 Flutter Color() 문자열로 변환"""
    value = value.strip()
    if value.startswith('#'):
        return hex_to_flutter(value)
    if value.startswith('rgb'):
        hex_val = rgb_to_hex(value)
        return hex_to_flutter(hex_val) if hex_val else None
    return None


def extract_fonts(html: str) -> list[str]:
    """font-family 값 추출"""
    fonts = re.findall(r'font-family\s*:\s*[\'"]?([\w\s]+)[\'"]?', html)
    seen = set()
    result = []
    for f in fonts:
        f = f.strip().strip("'\"")
        if f and f not in seen and f.lower() not in ('inherit', 'sans-serif', 'serif', 'monospace'):
            seen.add(f)
            result.append(f)
    return result


def generate_dart_colors(color_vars: dict) -> str:
    """추출된 색상 변수 → Dart 코드 초안"""
    lines = [
        "import 'package:flutter/material.dart';",
        "",
        "// 자동 생성 초안 — parse_design_html.py",
        "// 검토 후 app_colors.dart로 교체하세요.",
        "class AppColors {",
        "  AppColors._();",
        "",
    ]

    color_entries = []
    for name, value in color_vars.items():
        flutter_color = normalize_color(value)
        if flutter_color:
            # CSS var 이름 → camelCase Dart 이름
            dart_name = re.sub(r'-([a-z])', lambda m: m.group(1).upper(), name)
            dart_name = dart_name.replace('color', '').replace('Color', '')
            dart_name = dart_name[0].lower() + dart_name[1:] if dart_name else name
            color_entries.append(f"  static const {dart_name} = {flutter_color};  // {name}: {value}")

    if color_entries:
        lines.extend(color_entries)
    else:
        lines.append("  // 색상 CSS 변수를 찾지 못했습니다.")
        lines.append("  // HTML 파일 내 --color-xxx 형식의 변수를 확인하세요.")

    lines.extend(["}", ""])
    return "\n".join(lines)


def main():
    if len(sys.argv) < 2:
        print("사용법: python3 scripts/parse_design_html.py <design.html>")
        sys.exit(1)

    html_path = Path(sys.argv[1])
    if not html_path.exists():
        print(f"파일을 찾을 수 없습니다: {html_path}")
        sys.exit(1)

    html = html_path.read_text(encoding='utf-8', errors='ignore')

    print(f"\n=== {html_path.name} 분석 ===\n")

    # 색상 추출
    css_vars = extract_css_vars(html)
    color_vars = {k: v for k, v in css_vars.items() if normalize_color(v)}
    other_vars = {k: v for k, v in css_vars.items() if not normalize_color(v)}

    print(f"[색상 변수] {len(color_vars)}개")
    for name, value in color_vars.items():
        flutter = normalize_color(value)
        print(f"  --{name}: {value}  →  {flutter}")

    print(f"\n[기타 CSS 변수] {len(other_vars)}개")
    for name, value in list(other_vars.items())[:20]:
        print(f"  --{name}: {value}")

    # 폰트 추출
    fonts = extract_fonts(html)
    print(f"\n[폰트] {len(fonts)}개")
    for f in fonts:
        print(f"  {f}")
    if fonts:
        print("\n  google_fonts 사용 예시:")
        for f in fonts[:2]:
            dart_name = f.replace(' ', '')
            print(f"  GoogleFonts.{dart_name[0].lower() + dart_name[1:]}()")

    # Dart 초안 저장
    draft_path = Path("lib/core/constants/app_colors.dart.draft")
    dart_code = generate_dart_colors(color_vars)
    draft_path.write_text(dart_code, encoding='utf-8')
    print(f"\n[완료] 초안 저장: {draft_path}")
    print("       검토 후 app_colors.dart 로 교체하세요.\n")


if __name__ == "__main__":
    main()
