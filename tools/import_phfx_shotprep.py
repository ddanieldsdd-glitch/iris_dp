#!/usr/bin/env python3
"""
Importa modos de sensor desde PHFX shotPrep (https://phfx.com/tools/shotPrep/).
Genera assets/catalog/phfx_camera_formats.json y actualiza cameras_expansion.json.
"""

from __future__ import annotations

import json
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CAMERAS = ROOT / "assets/catalog/cameras.json"
MAP_FILE = ROOT / "assets/catalog/phfx_iris_camera_map.json"
OUT_FORMATS = ROOT / "assets/catalog/phfx_camera_formats.json"
OUT_EXPANSION = ROOT / "assets/catalog/cameras_expansion.json"
PHFX_URL = "https://phfx.com/tools/shotPrep/"
SCRAPE_URL = "https://phfx.com/tools/shotPrep/sp.cgi"

TOL_MM = 0.06
TOL_AR = 0.015
SCRAPE_DELAY_S = 0.15


def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "IRIS-DP-Catalog/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read().decode("latin-1", errors="replace")


def parse_phfx_tree(html: str) -> dict[str, dict[str, list[str]]]:
    tree: dict[str, dict[str, list[str]]] = {}
    for line in html.split("\n"):
        line = line.strip()
        m2 = re.search(
            r'camLevel\.forValue\("([^"]+)"\)\.forValue\("([^"]+)"\)\.addOptions\((.+)\);',
            line,
        )
        if m2:
            make, model, opts = m2.group(1), m2.group(2), m2.group(3)
            formats = re.findall(r'"([^"]+)"', opts)
            tree.setdefault(make, {})[model] = formats
            continue
        m = re.search(r'camLevel\.forValue\("([^"]+)"\)\.addOptions\((.+)\);', line)
        if m:
            make, opts = m.group(1), m.group(2)
            models = re.findall(r'"([^"]+)"', opts)
            tree[make] = {mod: [] for mod in models}
    return tree


def scrape_format(make: str, model: str, fmt: str) -> dict | None:
    params = urllib.parse.urlencode(
        {"make": make, "model": model, "format": fmt, "rf": "no", "sf": "1"}
    )
    try:
        html = fetch(f"{SCRAPE_URL}?{params}")
    except Exception as e:
        print(f"  ⚠ scrape fail {make}/{model}/{fmt}: {e}")
        return None

    size = re.search(r"Format Size = ([0-9.]+)x([0-9.]+)mm", html)
    res = re.search(r"Format Resolution = ([0-9]+)x([0-9]+)", html)
    ar = re.search(r"Format Aspect Ratio = ([0-9.]+):1", html)
    mp = re.search(r"\(([0-9.]+) megapixels\)", html)
    circle = re.search(r"Format Size = [^(]+\(([0-9.]+)mm image circle\)", html)

    if not res:
        return None

    w_px, h_px = int(res.group(1)), int(res.group(2))
    phfx_w = float(size.group(1)) if size else None
    phfx_h = float(size.group(2)) if size else None

    dci: list[str] = []
    uhd: list[str] = []
    rows = re.findall(
        r"<tr><td>([0-9]+x[0-9]+)</td><td>([0-9]+x[0-9]+)</td></tr>", html
    )
    for d, u in rows:
        dci.append(d)
        uhd.append(u)

    return {
        "name": fmt,
        "maxWidthPx": w_px,
        "maxHeightPx": h_px,
        "phfxWidthMm": phfx_w,
        "phfxHeightMm": phfx_h,
        "aspectRatio": float(ar.group(1)) if ar else round(w_px / h_px, 3),
        "megapixels": float(mp.group(1)) if mp else round(w_px * h_px / 1e6, 2),
        "imageCircleMm": float(circle.group(1)) if circle else None,
        "deliveryDci": dci,
        "deliveryUhd": uhd,
    }


def fit_mm(w_px: int, h_px: int, chip_w: float, chip_h: float) -> tuple[float, float]:
    ar = w_px / h_px
    h_mm = chip_w / ar
    if h_mm <= chip_h + TOL_MM:
        return chip_w, min(h_mm, chip_h)
    h_mm = chip_h
    return min(chip_h * ar, chip_w), h_mm


def build_sensor_mode(raw: dict, chip_w: float, chip_h: float) -> dict:
    w_px, h_px = raw["maxWidthPx"], raw["maxHeightPx"]
    w_mm, h_mm = fit_mm(w_px, h_px, chip_w, chip_h)
    mode = {
        "name": raw["name"],
        "widthMm": round(w_mm, 4),
        "heightMm": round(h_mm, 6),
        "maxWidthPx": w_px,
        "maxHeightPx": h_px,
        "cropFactor": 1.0,
        "phfxAspectRatio": raw.get("aspectRatio"),
        "phfxMegapixels": raw.get("megapixels"),
    }
    if raw.get("phfxWidthMm"):
        mode["phfxFormatWidthMm"] = raw["phfxWidthMm"]
        mode["phfxFormatHeightMm"] = raw["phfxHeightMm"]
    if raw.get("imageCircleMm"):
        mode["phfxImageCircleMm"] = raw["imageCircleMm"]
    if raw.get("deliveryDci"):
        mode["deliveryDci"] = raw["deliveryDci"]
    if raw.get("deliveryUhd"):
        mode["deliveryUhd"] = raw["deliveryUhd"]
    return mode


def validate_mode(m: dict, chip_w: float, chip_h: float) -> list[str]:
    errs = []
    w_mm, h_mm = m["widthMm"], m["heightMm"]
    w_px, h_px = m["maxWidthPx"], m["maxHeightPx"]
    if w_mm > chip_w + TOL_MM:
        errs.append("ancho excede chip")
    if h_mm > chip_h + TOL_MM:
        errs.append("alto excede chip")
    ar_mm = w_mm / h_mm
    ar_px = w_px / h_px
    if abs(ar_mm - ar_px) / ar_mm > TOL_AR:
        errs.append(f"AR incoherente mm={ar_mm:.3f} px={ar_px:.3f}")
    return errs


def filter_formats(formats: list[str], filt: list[str] | None) -> list[str]:
    if not filt:
        return formats
    out = []
    for f in formats:
        fl = f.lower()
        if any(k.lower() in fl for k in filt):
            out.append(f)
    return out or formats


def main() -> None:
    print("Fetching PHFX shotPrep tree…")
    html = fetch(PHFX_URL)
    tree = parse_phfx_tree(html)

    cameras = json.loads(CAMERAS.read_text())
    cam_by_id = {c["externalId"]: c for c in cameras}
    mapping = json.loads(MAP_FILE.read_text())

    phfx_data: dict = {}
    expansion: list = []
    errors: list[str] = []
    scrape_count = 0

    for eid, map_entry in mapping.items():
        cam = cam_by_id.get(eid)
        if cam is None:
            continue

        make = map_entry["phfxMake"]
        model = map_entry["phfxModel"]
        chip_w = cam["sensorWidthMm"]
        chip_h = cam["sensorHeightMm"]
        name = f"{cam['brand']} {cam['model']}"

        formats = tree.get(make, {}).get(model, [])
        formats = filter_formats(formats, map_entry.get("phfxFormatFilter"))
        if not formats:
            errors.append(f"{name}: sin formatos PHFX para {make}/{model}")
            continue

        print(f"\n{name} ({make} / {model}) — {len(formats)} formatos")
        modes_raw = []
        for fmt in formats:
            time.sleep(SCRAPE_DELAY_S)
            raw = scrape_format(make, model, fmt)
            scrape_count += 1
            if raw:
                modes_raw.append(raw)
                print(f"  ✓ {fmt}: {raw['maxWidthPx']}x{raw['maxHeightPx']}")
            else:
                print(f"  ✗ {fmt}")

        modes = [build_sensor_mode(r, chip_w, chip_h) for r in modes_raw]
        for m in modes:
            for e in validate_mode(m, chip_w, chip_h):
                errors.append(f"{name} / {m['name']}: {e}")

        phfx_data[eid] = {
            "phfxMake": make,
            "phfxModel": model,
            "physicalChipMm": [chip_w, chip_h],
            "source": "phfx.com/tools/shotPrep",
            "modes": modes,
        }
        expansion.append({"externalId": eid, "sensorModes": modes})

    OUT_FORMATS.write_text(json.dumps(phfx_data, indent=2) + "\n")
    OUT_EXPANSION.write_text(json.dumps(expansion, indent=2) + "\n")

    print(f"\nScraped {scrape_count} formats for {len(phfx_data)} cameras")
    print(f"Wrote {OUT_FORMATS}")
    print(f"Wrote {OUT_EXPANSION} ({len(expansion)} entries)")

    if errors:
        print(f"\n⚠ {len(errors)} avisos:")
        for e in errors[:20]:
            print(f"  - {e}")
        if len(errors) > 20:
            print(f"  … y {len(errors) - 20} más")
    else:
        print("\n✓ Validación OK")


if __name__ == "__main__":
    main()
