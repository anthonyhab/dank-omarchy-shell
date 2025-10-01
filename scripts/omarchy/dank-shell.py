#!/usr/bin/env python3
"""Render Omarchy theme assets for Dank Shell consumers."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Dict, Tuple

from jinja2 import Environment, FileSystemLoader

PALETTE_DEFAULTS: Dict[Tuple[str, str], str] = {
    ("Colors:Window", "ForegroundNormal"): "#ffffff",
    ("Colors:Window", "ForegroundInactive"): "#c4c7c5",
    ("Colors:Window", "BackgroundNormal"): "#1a1c1e",
    ("Colors:View", "BackgroundAlternate"): "#1e2023",
    ("Colors:View", "BackgroundNormal"): "#1a1c1e",
    ("Colors:View", "ForegroundInactive"): "#8e918f",
    ("Colors:View", "ForegroundNormal"): "#e3e8ef",
    ("Colors:View", "ForegroundLink"): "#2196f3",
    ("Colors:View", "ForegroundNegative"): "#f28b82",
    ("Colors:View", "ForegroundPositive"): "#4caf50",
    ("Colors:Button", "DecorationFocus"): "#4285f4",
    ("Colors:Button", "DecorationHover"): "#8ab4f8",
    ("Colors:Button", "ForegroundNormal"): "#e3e8ef",
    ("Colors:Button", "ForegroundActive"): "#ffffff",
    ("Colors:Selection", "BackgroundNormal"): "#1976d2",
    ("Colors:Selection", "ForegroundNormal"): "#1a1c1e",
    ("Colors:Selection", "ForegroundActive"): "#1a1c1e",
    ("Colors:Header", "BackgroundNormal"): "#292b2f",
}

SHADOW_FALLBACK = "#000000"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render Dank Shell toolkit assets from Omarchy theme data")
    parser.add_argument("theme", help="Omarchy theme name")
    parser.add_argument(
        "--targets",
        choices=["qt", "firefox"],
        nargs="+",
        default=["qt"],
        help="Toolkit targets to write",
    )
    parser.add_argument(
        "--templates",
        default=str(Path.home() / ".config/omarchy/theme-generator/templates"),
        help="Template directory (defaults to Omarchy theme generator templates)",
    )
    return parser.parse_args()


def parse_dank_colors(path: Path) -> Dict[str, Dict[str, Dict[str, float]]]:
    if not path.exists():
        raise FileNotFoundError(f"dank.colors not found: {path}")

    sections: Dict[str, Dict[str, Dict[str, float]]] = {}
    current = None

    for raw_line in path.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
            sections.setdefault(current, {})
            continue

        if current is None or "=" not in line:
            continue

        key, value = [segment.strip() for segment in line.split("=", 1)]
        parts = [segment.strip() for segment in value.split(",") if segment.strip()]
        if len(parts) != 3:
            continue

        try:
            r_i, g_i, b_i = (int(part) for part in parts)
        except ValueError:
            continue

        r_i = max(0, min(r_i, 255))
        g_i = max(0, min(g_i, 255))
        b_i = max(0, min(b_i, 255))

        sections[current][key] = {
            "hex": f"#{r_i:02x}{g_i:02x}{b_i:02x}",
            "red": r_i,
            "green": g_i,
            "blue": b_i,
        }

    return sections


def as_entry(hex_color: str) -> Dict[str, float]:
    hex_color = hex_color.lstrip("#")
    if len(hex_color) != 6:
        hex_color = "000000"
    r_i = int(hex_color[0:2], 16)
    g_i = int(hex_color[2:4], 16)
    b_i = int(hex_color[4:6], 16)
    return {
        "hex": f"#{r_i:02x}{g_i:02x}{b_i:02x}",
        "red": r_i,
        "green": g_i,
        "blue": b_i,
    }


def palette_lookup(palette: Dict[str, Dict[str, Dict[str, float]]], section: str, key: str) -> Dict[str, float]:
    entry = palette.get(section, {}).get(key)
    if entry:
        return entry
    fallback = PALETTE_DEFAULTS.get((section, key), SHADOW_FALLBACK if key == "Shadow" else "#ffffff")
    return as_entry(fallback)


MATERIAL_KEY_MAP: Dict[str, Tuple[str, str] | str] = {
    "primary": ("Colors:Button", "DecorationFocus"),
    "primary_container": ("Colors:Selection", "BackgroundNormal"),
    "on_primary": ("Colors:Selection", "ForegroundNormal"),
    "on_primary_container": ("Colors:Selection", "ForegroundActive"),
    "primary_fixed": ("Colors:Button", "DecorationFocus"),
    "primary_fixed_dim": ("Colors:Button", "DecorationFocus"),
    "on_primary_fixed": ("Colors:Selection", "ForegroundNormal"),
    "on_primary_fixed_variant": ("Colors:Selection", "ForegroundActive"),
    "secondary": ("Colors:Button", "DecorationHover"),
    "secondary_container": ("Colors:Button", "BackgroundNormal"),
    "on_secondary": ("Colors:Button", "ForegroundNormal"),
    "on_secondary_container": ("Colors:Button", "ForegroundActive"),
    "secondary_fixed": ("Colors:Button", "DecorationHover"),
    "secondary_fixed_dim": ("Colors:Button", "DecorationHover"),
    "on_secondary_fixed": ("Colors:Button", "ForegroundNormal"),
    "on_secondary_fixed_variant": ("Colors:Button", "ForegroundActive"),
    "tertiary": ("Colors:View", "ForegroundLink"),
    "tertiary_container": ("Colors:View", "BackgroundAlternate"),
    "on_tertiary": ("Colors:View", "ForegroundNormal"),
    "on_tertiary_container": ("Colors:View", "ForegroundNormal"),
    "tertiary_fixed": ("Colors:View", "ForegroundLink"),
    "tertiary_fixed_dim": ("Colors:View", "ForegroundLink"),
    "on_tertiary_fixed": ("Colors:View", "ForegroundNormal"),
    "on_tertiary_fixed_variant": ("Colors:View", "ForegroundNormal"),
    "background": ("Colors:View", "BackgroundNormal"),
    "on_background": ("Colors:View", "ForegroundNormal"),
    "surface": ("Colors:View", "BackgroundNormal"),
    "surface_variant": ("Colors:View", "BackgroundAlternate"),
    "on_surface": ("Colors:View", "ForegroundNormal"),
    "on_surface_variant": ("Colors:View", "ForegroundInactive"),
    "surface_container": ("Colors:View", "BackgroundAlternate"),
    "surface_container_low": ("Colors:View", "BackgroundNormal"),
    "surface_container_lowest": ("Colors:View", "BackgroundNormal"),
    "surface_container_high": ("Colors:Header", "BackgroundNormal"),
    "surface_container_highest": ("Colors:Header", "BackgroundNormal"),
    "surface_dim": ("Colors:Window", "BackgroundNormal"),
    "surface_bright": ("Colors:View", "BackgroundAlternate"),
    "outline": ("Colors:View", "ForegroundInactive"),
    "outline_variant": ("Colors:View", "ForegroundInactive"),
    "error": ("Colors:View", "ForegroundNegative"),
    "on_error": ("Colors:View", "BackgroundNormal"),
    "error_container": ("Colors:View", "ForegroundNegative"),
    "on_error_container": ("Colors:View", "BackgroundNormal"),
    "inverse_surface": ("Colors:Window", "ForegroundNormal"),
    "inverse_on_surface": ("Colors:Window", "BackgroundNormal"),
    "inverse_primary": ("Colors:Button", "DecorationFocus"),
    "shadow": SHADOW_FALLBACK,
    "scrim": SHADOW_FALLBACK,
}


def build_material_palette(palette: Dict[str, Dict[str, Dict[str, float]]]) -> Dict[str, Dict[str, Dict[str, float]]]:
    result: Dict[str, Dict[str, Dict[str, float]]] = {}

    for key, mapping in MATERIAL_KEY_MAP.items():
        if isinstance(mapping, tuple):
            section, prop = mapping
            base_entry = palette_lookup(palette, section, prop)
        else:
            base_entry = as_entry(mapping)

        entry = {
            "hex": base_entry["hex"],
            "red": base_entry["red"],
            "green": base_entry["green"],
            "blue": base_entry["blue"],
        }

        result[key] = {
            "default": entry,
            "light": entry,
            "dark": entry,
        }

    return result


def render_qt(env: Environment, palette: Dict[str, Dict[str, Dict[str, float]]]) -> None:
    try:
        template = env.get_template("qtct-colors.conf.j2")
    except Exception:
        return

    material_palette = build_material_palette(palette)
    content = template.render(colors=material_palette)

    qt5_target = Path.home() / ".config" / "qt5ct" / "colors" / "omarchy.conf"
    qt6_target = Path.home() / ".config" / "qt6ct" / "colors" / "omarchy.conf"

    for target in (qt5_target, qt6_target):
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)


def render_firefox(env: Environment, palette: Dict[str, Dict[str, Dict[str, float]]]) -> None:
    try:
        template = env.get_template("firefox-userchrome.css.j2")
    except Exception:
        return

    material_palette = build_material_palette(palette)
    content = template.render(colors=material_palette)

    profile_root = Path.home() / ".mozilla" / "firefox"
    if not profile_root.exists():
        return

    profiles = [
        profile
        for profile in profile_root.iterdir()
        if profile.is_dir()
        and any(profile.name.endswith(suffix) for suffix in (".default", ".default-release", ".default-nightly"))
    ]

    if not profiles:
        return

    for profile in profiles:
        chrome_dir = profile / "chrome"
        chrome_dir.mkdir(parents=True, exist_ok=True)
        (chrome_dir / "theme-material-blue.css").write_text(content)


def main() -> int:
    args = parse_args()

    theme_path = Path.home() / ".config" / "omarchy" / "themes" / args.theme
    dank_colors = theme_path / "dank.colors"
    try:
        palette = parse_dank_colors(dank_colors)
    except FileNotFoundError as err:
        print(err, file=sys.stderr)
        return 1

    if not palette:
        print(f"No colors parsed from {dank_colors}", file=sys.stderr)
        return 1

    template_dir = Path(args.templates)
    env = Environment(loader=FileSystemLoader(str(template_dir)))

    if "qt" in args.targets:
        render_qt(env, palette)

    if "firefox" in args.targets:
        render_firefox(env, palette)

    return 0


if __name__ == "__main__":
    sys.exit(main())
