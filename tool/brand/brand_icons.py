#!/usr/bin/env python3
"""Erzeugt Favicon und Web-App-Icons aus dem Lovel-Logo (Herz als Controller).

Quelle: Design „LovelApp Logo“ (App-Icon). Formen identisch zu
lib/core/widgets/lovel_logo.dart – bei Änderungen beide anpassen.

Aufruf: python3 tool/brand/brand_icons.py   (braucht rsvg-convert)
"""
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WEB = ROOT / "web"

TERRACOTTA = "#BB5B3E"
CREAM = "#FFFEF6"

# Herz-Controller im Koordinatensystem 240 × 220.
HEART = ("M120 200 C 120 200 20 138 20 76 C 20 42 46 18 78 18 "
         "C 98 18 112 28 120 44 C 128 28 142 18 162 18 "
         "C 194 18 220 42 220 76 C 220 138 120 200 120 200 Z")


def mark(heart: str, detail: str) -> str:
    return (
        f'<path d="{HEART}" fill="{heart}" stroke="{heart}" stroke-width="14" '
        f'stroke-linejoin="round"/>'
        f'<rect x="51" y="73" width="56" height="18" rx="5" fill="{detail}"/>'
        f'<rect x="70" y="54" width="18" height="56" rx="5" fill="{detail}"/>'
        f'<circle cx="150" cy="95" r="11" fill="{detail}"/>'
        f'<circle cx="176" cy="69" r="11" fill="{detail}"/>'
    )


def icon_svg(size: int, radius_ratio: float, mark_ratio: float) -> str:
    """Terrakotta-Fläche mit hellem Herz; mark_ratio = Breite Herz / Icon."""
    w = size * mark_ratio
    scale = w / 240
    h = 220 * scale
    x = (size - w) / 2
    y = (size - h) / 2 + size * 0.02  # optisch etwas tiefer
    r = size * radius_ratio
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
        f'viewBox="0 0 {size} {size}">'
        f'<rect width="{size}" height="{size}" rx="{r}" fill="{TERRACOTTA}"/>'
        f'<g transform="translate({x:.2f} {y:.2f}) scale({scale:.5f})">'
        f'{mark(CREAM, TERRACOTTA)}</g></svg>'
    )


def render(svg: str, out: Path, size: int) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["rsvg-convert", "-w", str(size), "-h", str(size), "-o", str(out)],
        input=svg.encode(), check=True,
    )


def main() -> None:
    # Wie im Design: abgerundetes Quadrat (Radius ≈ 22 %), Herz ≈ 68 %.
    rounded = lambda s: icon_svg(s, 0.22, 0.68)
    # Maskable/iOS: volle Fläche, Herz in der sicheren Zone (≈ 56 %).
    full = lambda s: icon_svg(s, 0, 0.56)

    (WEB / "favicon.svg").write_text(rounded(64))
    render(rounded(48), WEB / "favicon.png", 48)
    render(rounded(192), WEB / "icons" / "Icon-192.png", 192)
    render(rounded(512), WEB / "icons" / "Icon-512.png", 512)
    render(full(192), WEB / "icons" / "Icon-maskable-192.png", 192)
    render(full(512), WEB / "icons" / "Icon-maskable-512.png", 512)
    render(full(180), WEB / "icons" / "apple-touch-icon.png", 180)
    print("Icons erzeugt.")


if __name__ == "__main__":
    main()
