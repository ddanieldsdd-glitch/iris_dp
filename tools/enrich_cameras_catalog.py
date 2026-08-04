#!/usr/bin/env python3
"""Genera assets/catalog/cameras_expansion.json con modos sensor validados por cámara."""

from __future__ import annotations

import json
import math
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CAMERAS = ROOT / "assets/catalog/cameras.json"
OUT = ROOT / "assets/catalog/cameras_expansion.json"

TOL_MM = 0.06
TOL_AR = 0.015


def mode(
    name: str,
    w_mm: float,
    h_mm: float,
    w_px: int,
    h_px: int,
    crop: float = 1.0,
    off_x: float = 0.0,
    off_y: float = 0.0,
) -> dict:
    m = {
        "name": name,
        "widthMm": round(w_mm, 4),
        "heightMm": round(h_mm, 6),
        "maxWidthPx": int(w_px),
        "maxHeightPx": int(h_px),
        "cropFactor": crop,
    }
    if off_x:
        m["offsetXMm"] = round(off_x, 4)
    if off_y:
        m["offsetYMm"] = round(off_y, 4)
    return m


def fit_recording(
    name: str,
    w_px: int,
    h_px: int,
    chip_w: float,
    chip_h: float,
    crop: float = 1.0,
) -> dict:
    """Deriva mm activos desde resolución real, ajustados al chip (sin exceder área física)."""
    ar = w_px / h_px
    # Probar ancho completo
    h_mm = chip_w / ar
    if h_mm <= chip_h + TOL_MM:
        w_mm, h_mm = chip_w, min(h_mm, chip_h)
    else:
        h_mm = chip_h
        w_mm = min(chip_h * ar, chip_w)
    return mode(name, w_mm, h_mm, w_px, h_px, crop=crop)


def crop169(name: str, chip_w: float, chip_h: float, w_px: int, h_px: int) -> dict:
    return fit_recording(name, w_px, h_px, chip_w, chip_h)


def crop239(name: str, chip_w: float, chip_h: float, w_px: int, h_px: int) -> dict:
    return fit_recording(name, w_px, h_px, chip_w, chip_h)


def open_gate(name: str, chip_w: float, chip_h: float, w_px: int, h_px: int) -> dict:
    """Open gate: usa resolución nativa; mm se ajustan al aspect de grabación dentro del chip."""
    return fit_recording(name, w_px, h_px, chip_w, chip_h)


def explicit(name: str, w_mm: float, h_mm: float, w_px: int, h_px: int, **kw) -> dict:
    return mode(name, w_mm, h_mm, w_px, h_px, **kw)


def validate_mode(m: dict, chip_w: float, chip_h: float) -> list[str]:
    errs = []
    w_mm, h_mm = m["widthMm"], m["heightMm"]
    w_px, h_px = m["maxWidthPx"], m["maxHeightPx"]
    if w_mm > chip_w + TOL_MM:
        errs.append(f"ancho {w_mm} > chip {chip_w}")
    if h_mm > chip_h + TOL_MM:
        errs.append(f"alto {h_mm} > chip {chip_h}")
    if w_px <= 0 or h_px <= 0:
        errs.append("px inválidos")
    ar_mm = w_mm / h_mm
    ar_px = w_px / h_px
    if abs(ar_mm - ar_px) / ar_mm > TOL_AR:
        errs.append(f"AR mm={ar_mm:.4f} px={ar_px:.4f}")
    return errs


def validate_modes(modes: list[dict], chip_w: float, chip_h: float, camera: str) -> list[str]:
    issues = []
    names = []
    for m in modes:
        names.append(m["name"])
        for e in validate_mode(m, chip_w, chip_h):
            issues.append(f"{camera} / {m['name']}: {e}")
    if len(names) != len(set(names)):
        issues.append(f"{camera}: nombres duplicados {names}")
    return issues


def modes_for(eid: str, chip_w: float, chip_h: float) -> list[dict]:
    """Modos autoritativos por cámara — solo resoluciones reales de cada modelo."""
    cw, ch = chip_w, chip_h

    specs: dict[str, list[dict]] = {
        # ARRI
        "arri_alexa35": [
            explicit("4.6K Open Gate", 27.99, 19.22, 4608, 3164),
            explicit("4.6K 16:9", 27.99, 15.74, 4608, 2592),
            explicit("4K 2.39:1", 27.99, 11.71, 4096, 1716),
            explicit("S16", 12.35, 7.49, 2048, 1242, crop=2.27),
        ],
        "arri_alexa_mini_lf": [
            explicit("Open Gate LF", 36.7, 25.54, 4448, 3096),
            explicit("4K 16:9", 36.7, 20.65, 4096, 2304),
            explicit("2.39:1", 36.7, 15.35, 4096, 1716),
        ],
        "arri_alexa_mini": [
            explicit("Open Gate", 28.25, 18.17, 3424, 2202),
            explicit("16:9", 28.25, 15.890625, 3424, 1920),
            explicit("2.39:1", 28.25, 11.820084, 3424, 1432),
        ],
        "arri_amira": [
            explicit("Open Gate", 28.25, 18.17, 3424, 2202),
            explicit("16:9", 28.25, 15.890625, 3424, 1920),
            explicit("2.39:1", 28.25, 11.820084, 3424, 1432),
        ],
        "arri_416": [
            explicit("Open Gate", 12.35, 7.49, 2048, 1242),
            explicit("16:9", 12.35, 6.946875, 2048, 1152),
            explicit("2.39:1", 12.35, 5.167364, 2048, 856),
        ],
        "arri_416_plus": [
            explicit("Open Gate", 12.35, 7.49, 2048, 1242),
            explicit("16:9", 12.35, 6.946875, 2048, 1152),
            explicit("2.39:1", 12.35, 5.167364, 2048, 856),
        ],
        "arri_alexa_65": [
            explicit("6.5K Open Gate", 54.12, 25.59, 6560, 3104),
            fit_recording("6.5K 16:9", 6560, 3690, cw, ch),  # crop ancho, no excede alto
            explicit("4K 2.39:1", 54.12, 22.65, 4096, 1716),
        ],
        "arri_alexa_xt": [
            explicit("Open Gate", 28.25, 18.17, 3424, 2202),
            explicit("16:9", 28.25, 15.890625, 3424, 1920),
            explicit("2.39:1", 28.25, 11.820084, 3424, 1432),
        ],
        "arri_alexa_sxt": [
            explicit("Open Gate", 28.25, 18.17, 3424, 2202),
            explicit("16:9", 28.25, 15.890625, 3424, 1920),
            explicit("2.39:1", 28.25, 11.820084, 3424, 1432),
        ],
        "arri_alexa_lf": [
            explicit("Open Gate LF", 36.7, 25.54, 4448, 3096),
            explicit("4K 16:9", 36.7, 20.65, 4096, 2304),
            explicit("2.39:1", 36.7, 15.35, 4096, 1716),
        ],
        "arri_alexa_xt_plus": [
            explicit("Open Gate", 28.25, 18.17, 3424, 2202),
            explicit("16:9", 28.25, 15.890625, 3424, 1920),
            explicit("2.39:1", 28.25, 11.820084, 3424, 1432),
        ],
        "arri_265": [
            fit_recording("4K Open Gate", 3840, 2160, cw, ch),
            crop169("16:9", cw, ch, 3840, 2160),
            crop239("2.39:1", cw, ch, 3840, 1607),
        ],
        "arri_sr3": [
            explicit("Super 16 Open Gate", 24.89, 18.66, 2048, 1552),
            explicit("Super 16 · 16:9", 24.89, 14.0, 1920, 1080),
        ],
        "arri_435": [
            explicit("4-perf Open", 24.89, 18.66, 4096, 3072),
            explicit("3-perf", 24.89, 14.0, 4096, 2304),
            explicit("2-perf Anamorphic", 24.89, 10.0, 4096, 1648),
        ],
        # Sony cinema
        "sony_venice2": [
            explicit("8K Open Gate", 35.9, 24.0, 8640, 5760),
            explicit("8K 16:9", 35.9, 20.19, 8640, 4860),
            explicit("6K 2.39:1", 35.9, 15.02, 6054, 2538),
            explicit("4K 16:9", 35.9, 20.19, 4096, 2304),
        ],
        "sony_venice": [
            explicit("6K Open Gate", 35.9, 24.0, 6054, 4032),
            explicit("4K 16:9", 35.9, 20.19, 4096, 2304),
            explicit("6K 2.39:1", 35.9, 15.02, 6054, 2538),
        ],
        "sony_venice_1_r": [
            explicit("6K Open Gate", 35.9, 24.0, 6054, 4032),
            explicit("4K 16:9", 35.9, 20.19, 4096, 2304),
            explicit("6K 2.39:1", 35.9, 15.02, 6054, 2538),
        ],
        "sony_burano": [
            open_gate("4K Open Gate", cw, ch, 4096, 2160),
            crop169("4K 16:9", cw, ch, 4096, 2304),
        ],
        "sony_fx9": [
            crop169("4K UHD", cw, ch, 3840, 2160),
            crop169("4K DCI", cw, ch, 4096, 2160),
            crop239("2.39:1", cw, ch, 3840, 1607),
        ],
        "sony_fx6": [
            crop169("4K UHD", cw, ch, 3840, 2160),
            crop169("4K DCI", cw, ch, 4096, 2160),
            crop239("2.39:1", cw, ch, 3840, 1607),
        ],
        "sony_fx3": [
            crop169("4K UHD", cw, ch, 3840, 2160),
            crop239("2.39:1", cw, ch, 3840, 1607),
        ],
        "sony_fr7": [
            crop169("4K UHD", cw, ch, 3840, 2160),
            crop239("2.39:1", cw, ch, 3840, 1607),
        ],
        "sony_fr7_studio": [
            crop169("4K UHD", cw, ch, 3840, 2160),
            crop239("2.39:1", cw, ch, 3840, 1607),
        ],
        "sony_f55": [
            crop169("4K QFHD", cw, ch, 4096, 2160),
            crop239("2.39:1", cw, ch, 4096, 1714),
        ],
        "sony_f5": [
            crop169("4K QFHD", cw, ch, 4096, 2160),
            crop239("2.39:1", cw, ch, 4096, 1714),
        ],
        "sony_f65": [
            fit_recording("16:9 4K", 4096, 2160, cw, ch),
            fit_recording("17:9 8K", 8192, 4320, cw, ch),
        ],
        "sony_f35": [
            crop169("4K UHD", cw, ch, 3840, 2160),
            crop239("2.39:1", cw, ch, 3840, 1607),
        ],
        "sony_fs7ii": [
            crop169("4K UHD", cw, ch, 3840, 2160),
            crop239("2.39:1", cw, ch, 3840, 1607),
        ],
        "sony_fs5": [
            crop169("4K UHD", cw, ch, 3840, 2160),
            crop239("2.39:1", cw, ch, 3840, 1607),
        ],
        "sony_a7siii": [
            open_gate("Full Frame Stills", cw, ch, 4240, 2832),
            crop169("4K UHD", cw, ch, 3840, 2160),
            explicit("S35 4K", 23.6, 13.3, 3840, 2160, crop=1.5),
        ],
        # RED
        "red_vraptor_vv": [
            open_gate("8K Open Gate", cw, ch, 8192, 4320),
            crop169("8K 16:9", cw, ch, 8192, 4608),
            crop239("8K 2.39:1", cw, ch, 8192, 3424),
        ],
        "red_vraptor_xl": [
            open_gate("8K Open Gate", cw, ch, 8192, 4320),
            crop169("8K 16:9", cw, ch, 8192, 4608),
            crop239("8K 2.39:1", cw, ch, 8192, 3424),
        ],
        "red_komodo": [
            open_gate("6K Open Gate", cw, ch, 6144, 3240),
            crop169("6K 16:9", cw, ch, 6144, 3456),
            crop239("6K 2.39:1", cw, ch, 6144, 2568),
        ],
        "red_komodo_x": [
            open_gate("6K Open Gate", cw, ch, 6144, 3240),
            crop169("6K 16:9", cw, ch, 6144, 3456),
            crop239("6K 2.39:1", cw, ch, 6144, 2568),
        ],
        "red_gemini": [
            open_gate("5K Open Gate", cw, ch, 5120, 2700),
            crop169("5K 16:9", cw, ch, 5120, 2880),
            crop239("5K 2.39:1", cw, ch, 5120, 2142),
        ],
        "red_ranger": [
            open_gate("5K Open Gate", cw, ch, 5120, 2700),
            crop169("5K 16:9", cw, ch, 5120, 2880),
            crop239("5K 2.39:1", cw, ch, 5120, 2142),
        ],
        "red_weapon_vv": [
            open_gate("8K Open Gate", cw, ch, 8192, 4320),
            crop169("8K 16:9", cw, ch, 8192, 4608),
            crop239("8K 2.39:1", cw, ch, 8192, 3424),
        ],
        "red_monstro": [
            open_gate("8K Open Gate", cw, ch, 8192, 4320),
            crop169("8K 16:9", cw, ch, 8192, 4608),
            crop239("8K 2.39:1", cw, ch, 8192, 3424),
        ],
        "red_ranger_monstro": [
            open_gate("8K Open Gate", cw, ch, 8192, 4320),
            crop169("8K 16:9", cw, ch, 8192, 4608),
            crop239("8K 2.39:1", cw, ch, 8192, 3424),
        ],
        "red_scarlet_w": [
            open_gate("5K Open Gate", cw, ch, 5120, 2700),
            crop169("5K 16:9", cw, ch, 5120, 2880),
            crop239("5K 2.39:1", cw, ch, 5120, 2142),
        ],
        # Blackmagic
        "bm_pyxis": [
            fit_recording("6K Open Gate", 6048, 4032, cw, ch),
            explicit("6K 16:9", 23.1, 12.994, 6048, 3402),
            explicit("6K 2.39:1", 23.1, 9.665, 6048, 2530),
            explicit("4K DCI", 20.12, 10.62, 4096, 2160),
            explicit("4K UHD", 18.84, 10.57, 3840, 2160),
            explicit("2.8K", 14.02, 7.38, 2868, 1512),
        ],
        "bm_pocket_6k_pro": [
            fit_recording("6K Open Gate", 6144, 3456, cw, ch),
            explicit("6K 16:9", 23.1, 12.994, 6144, 3456),
            explicit("6K 2.39:1", 23.1, 9.665, 6144, 2568),
            explicit("4K DCI", 20.12, 10.62, 4096, 2160),
            explicit("4K UHD", 18.84, 10.57, 3840, 2160),
        ],
        "blackmagic_pocket_6k_g2": [
            fit_recording("6K Open Gate", 6144, 3456, cw, ch),
            explicit("6K 16:9", 23.1, 12.994, 6144, 3456),
            explicit("4K DCI", 20.12, 10.62, 4096, 2160),
            explicit("4K UHD", 18.84, 10.57, 3840, 2160),
        ],
        "bm_pocket_4k": [
            open_gate("4K DCI", cw, ch, 4096, 2160),
            fit_recording("4K UHD", 3840, 2160, cw, ch),
            explicit("2.8K", 13.2, 7.0, 2868, 1512),
        ],
        "bm_ursa_12k": [
            open_gate("12K 16:9", cw, ch, 12288, 6480),
            open_gate("8K Open Gate", cw, ch, 8192, 4320),
            explicit("4K DCI", 20.0, 10.55, 4096, 2160),
            explicit("4K UHD", 18.72, 10.52, 3840, 2160),
        ],
        "bm_ursa_g2": [
            open_gate("4.6K", cw, ch, 4608, 2592),
            crop169("4.6K 16:9", cw, ch, 4608, 2592),
            crop239("4.6K 2.39:1", cw, ch, 4608, 1928),
        ],
        "bm_ursa_4.6k": [
            open_gate("4.6K", cw, ch, 4608, 2592),
            crop169("4.6K 16:9", cw, ch, 4608, 2592),
            crop239("4.6K 2.39:1", cw, ch, 4608, 1928),
        ],
        "blackmagic_ursa_17k": [
            open_gate("17K Open Gate", cw, ch, 17568, 9200),
            fit_recording("12K 16:9", 12288, 6912, cw, ch),
            fit_recording("8K 16:9", 8192, 4608, cw, ch),
            explicit("4K DCI", 40.0, 21.1, 4096, 2160),
        ],
        # Canon
        "canon_c500mk2": [
            open_gate("5.9K Open Gate", cw, ch, 5952, 3140),
            crop169("5.9K 16:9", cw, ch, 5952, 3348),
            crop239("4K 2.39:1", cw, ch, 4096, 1716),
        ],
        "canon_c700": [
            open_gate("5.9K Open Gate", cw, ch, 5952, 3140),
            crop169("5.9K 16:9", cw, ch, 5952, 3348),
            crop239("4K 2.39:1", cw, ch, 4096, 1716),
        ],
        "canon_c300mk3": [
            open_gate("4K DCI", cw, ch, 4096, 2160),
            crop169("4K 16:9", cw, ch, 4096, 2304),
            crop239("2.39:1", cw, ch, 4096, 1714),
        ],
        "canon_c300mk2": [
            open_gate("4K DCI", cw, ch, 4096, 2160),
            crop169("4K 16:9", cw, ch, 4096, 2304),
            crop239("2.39:1", cw, ch, 4096, 1714),
        ],
        "canon_c200": [
            open_gate("4K DCI", cw, ch, 4096, 2160),
            crop169("4K 16:9", cw, ch, 4096, 2304),
            crop239("2.39:1", cw, ch, 4096, 1714),
        ],
        "canon_c70": [
            open_gate("4K DCI", cw, ch, 4096, 2160),
            crop169("4K 16:9", cw, ch, 4096, 2304),
            crop239("2.39:1", cw, ch, 4096, 1714),
        ],
        "canon_c50": [
            open_gate("4K DCI", cw, ch, 4096, 2160),
            crop169("4K 16:9", cw, ch, 4096, 2304),
            crop239("2.39:1", cw, ch, 4096, 1714),
        ],
        "canon_1dc": [
            crop169("4K DCI", cw, ch, 4096, 2160),
            crop239("2.39:1", cw, ch, 4096, 1714),
        ],
        "canon_r5c": [
            open_gate("8K Open Gate", cw, ch, 8192, 4320),
            crop169("4K DCI", cw, ch, 4096, 2160),
            fit_recording("4K UHD", 3840, 2160, cw, ch),
        ],
        # Panasonic (sensor 4:3)
        "panasonic_varicam_lt": [
            crop169("4K 16:9", cw, ch, 4096, 2160),
            crop239("2.39:1", cw, ch, 4096, 1714),
            open_gate("4K 4:3", cw, ch, 4096, 3072),
        ],
        "panasonic_varicam_35": [
            crop169("4K 16:9", cw, ch, 4096, 2160),
            crop239("2.39:1", cw, ch, 4096, 1714),
            open_gate("4K 4:3", cw, ch, 4096, 3072),
        ],
        "panasonic_varicam_pure": [
            crop169("4K 16:9", cw, ch, 4096, 2160),
            crop239("2.39:1", cw, ch, 4096, 1714),
            open_gate("4K 4:3", cw, ch, 4096, 3072),
        ],
        "panasonic_varicam_hs": [
            crop169("4K High Speed 16:9", cw, ch, 4096, 2160),
            crop239("2.39:1", cw, ch, 4096, 1714),
        ],
        "panasonic_eva1": [
            open_gate("5.7K Open Gate", cw, ch, 5728, 3016),
            crop169("5.7K 16:9", cw, ch, 5728, 3222),
            crop239("5.7K 2.39:1", cw, ch, 5728, 2396),
        ],
        "panasonic_s1h": [
            open_gate("6K Open Gate", cw, ch, 5952, 3968),
            crop169("6K 16:9", cw, ch, 5952, 3348),
            crop239("5.9K 2.39:1", cw, ch, 5952, 2490),
        ],
        # Panavision
        "panavision_dxl2": [
            open_gate("8K Open Gate", cw, ch, 8192, 4320),
            crop169("8K 16:9", cw, ch, 8192, 4608),
            crop239("8K 2.39:1", cw, ch, 8192, 3424),
        ],
        "panavision_millennium": [
            open_gate("8K Open Gate", cw, ch, 8192, 4320),
            crop169("8K 16:9", cw, ch, 8192, 4608),
            crop239("8K 2.39:1", cw, ch, 8192, 3424),
        ],
        "panavision_millennium_xl2": [
            explicit("4-perf Open", 24.89, 18.66, 4096, 3072),
            explicit("3-perf", 24.89, 14.0, 4096, 2304),
            explicit("2-perf Anamorphic", 24.89, 10.0, 4096, 1648),
        ],
        # Otros
        "phantom_flex4k": [
            open_gate("4K", cw, ch, 4096, 2304),
            crop169("4K 16:9", cw, ch, 4096, 2304),
        ],
        "phantom_t1340": [
            open_gate("4K", cw, ch, 4096, 2304),
            fit_recording("2K High Speed", 2048, 1152, cw, ch),
        ],
        "imax_15perf": [
            explicit("15/70 Open Gate", 70.41, 52.63, 8192, 6114),
            explicit("1.43:1 IMAX", 70.41, 49.24, 8192, 5718),
        ],
        "phase_one_xf": [
            explicit("150MP Full", 53.7, 40.4, 14204, 10652),
            explicit("100MP Crop", 43.8, 32.9, 11608, 8708),
        ],
    }

    if eid in specs:
        return specs[eid]

    # Fallback conservador: derivar mm desde resolución, sin inventar modos de otras cámaras
    existing = []
    return existing


def build_modes(camera: dict) -> list[dict]:
    eid = camera["externalId"]
    cw = camera["sensorWidthMm"]
    ch = camera["sensorHeightMm"]
    modes = modes_for(eid, cw, ch)
    if modes:
        return modes

    # Usar modos base del JSON si existen — validar y corregir px/mm
    existing = camera.get("sensorModes") or []
    if existing:
        fixed = []
        for m in existing:
            w_px = m.get("maxWidthPx")
            h_px = m.get("maxHeightPx")
            if w_px and h_px:
                fixed.append(fit_recording(m["name"], w_px, h_px, cw, ch))
            else:
                w_mm, h_mm = m["widthMm"], m["heightMm"]
                ar = w_mm / h_mm
                est_w = max(640, round(w_mm * 121))
                est_h = max(480, round(est_w / ar))
                fixed.append(mode(m["name"], w_mm, h_mm, est_w, est_h, crop=m.get("cropFactor", 1.0)))
        return fixed

    return []


def main() -> None:
    cameras = json.loads(CAMERAS.read_text())
    expansion = []
    all_issues: list[str] = []

    for cam in cameras:
        eid = cam["externalId"]
        cw, ch = cam["sensorWidthMm"], cam["sensorHeightMm"]
        name = f"{cam['brand']} {cam['model']}"
        new_modes = build_modes(cam)
        if not new_modes:
            all_issues.append(f"{name}: sin modos definidos")
            continue

        issues = validate_modes(new_modes, cw, ch, name)
        all_issues.extend(issues)

        before = cam.get("sensorModes") or []
        changed = json.dumps(before, sort_keys=True) != json.dumps(new_modes, sort_keys=True)
        if changed or eid in {x["externalId"] for x in expansion}:
            expansion.append({"externalId": eid, "sensorModes": new_modes})

    OUT.write_text(json.dumps(expansion, indent=2) + "\n")
    print(f"Wrote {OUT} ({len(expansion)} cameras)")

    if all_issues:
        print(f"\n⚠️  {len(all_issues)} problemas de validación:")
        for i in all_issues[:30]:
            print(f"  - {i}")
        if len(all_issues) > 30:
            print(f"  ... y {len(all_issues) - 30} más")
        raise SystemExit(1)
    print("✓ Validación OK — todos los modos caben en el chip y AR mm/px coherente")


if __name__ == "__main__":
    main()
