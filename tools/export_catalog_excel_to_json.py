#!/usr/bin/env python3
"""Exporta Cámaras + Modos_Cámara del Excel técnico a JSON CatalogCameraEntry.

Uso:
  python3 tools/export_catalog_excel_to_json.py \\
    docs/catalog/lista_de_material_tecnico_v1_7.xlsx \\
    docs/catalog/cameras_modos_v1_7.json

Requiere openpyxl. El paquete Dart `excel` no abre bien libros ricos
(Numbers/Excel); este JSON es el camino de import estable en app.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

try:
    from openpyxl import load_workbook
except ImportError as e:  # pragma: no cover
    raise SystemExit("Instala openpyxl: pip install openpyxl") from e


def _to_float(v):
    if v is None:
        return None
    if isinstance(v, (int, float)):
        return float(v)
    m = re.search(r"-?\d+(\.\d+)?", str(v).replace(",", "."))
    return float(m.group(0)) if m else None


def _to_int(v):
    f = _to_float(v)
    return int(round(f)) if f is not None else None


def export(src: Path, dst: Path) -> None:
    wb = load_workbook(src, data_only=True, read_only=True)
    cam_rows = list(wb["Cámaras"].iter_rows(values_only=True))
    mode_rows = list(wb["Modos_Cámara"].iter_rows(values_only=True))
    cam_h = [str(h) if h is not None else "" for h in cam_rows[0]]
    mode_h = [str(h) if h is not None else "" for h in mode_rows[0]]

    modes_by: dict[str, list] = {}
    skipped_modes = 0
    for row in mode_rows[1:]:
        d = {mode_h[i]: (row[i] if i < len(row) else None) for i in range(len(mode_h))}
        cid = d.get("camera_external_id")
        if not cid:
            continue
        name = d.get("modo_sensor")
        gw = _to_float(d.get("gate_ancho_mm"))
        gh = _to_float(d.get("gate_alto_mm"))
        if not name or gw is None or gh is None:
            skipped_modes += 1
            continue
        mode = {
            "name": str(name),
            "widthMm": gw,
            "heightMm": gh,
            "cropFactor": _to_float(d.get("crop_x")) or 1.0,
        }
        cy = _to_float(d.get("crop_y"))
        if cy is not None:
            mode["cropY"] = cy
        rx, ry = _to_int(d.get("res_x")), _to_int(d.get("res_y"))
        if rx is not None:
            mode["maxWidthPx"] = rx
        if ry is not None:
            mode["maxHeightPx"] = ry
        if d.get("aspect_ratio"):
            mode["aspectRatio"] = str(d["aspect_ratio"])
        if d.get("codec"):
            mode["codec"] = str(d["codec"])
        fm = _to_float(d.get("fps_max"))
        if fm is not None:
            mode["fpsMax"] = fm
        modes_by.setdefault(str(cid), []).append(mode)

    cameras = []
    for row in cam_rows[1:]:
        d = {cam_h[i]: (row[i] if i < len(row) else None) for i in range(len(cam_h))}
        eid = d.get("external_id")
        if not eid:
            continue
        if d.get("es_custom") in (1, True, "1", "true"):
            continue
        brand, model = d.get("marca"), d.get("modelo")
        w, h = _to_float(d.get("sensor_ancho_mm")), _to_float(d.get("sensor_alto_mm"))
        if not brand or not model or w is None or h is None:
            continue
        entry = {
            "externalId": str(eid),
            "brand": str(brand),
            "model": str(model),
            "sensorWidthMm": w,
            "sensorHeightMm": h,
            "vintage": d.get("vintage") in (1, True, "1"),
            "lukaCompatible": d.get("luka_compatible") in (1, True, "1"),
            "sensorModes": modes_by.get(str(eid), []),
        }
        if d.get("mount"):
            entry["mountType"] = str(d["mount"])
        ni = _to_int(d.get("iso_base")) or _to_int(d.get("iso_base_1"))
        if ni is not None:
            entry["nativeIso"] = ni
        dr = _to_float(d.get("rango_dinamico_stops"))
        if dr is not None:
            entry["dynamicRangeStops"] = dr
        if d.get("tipo_sensor"):
            entry["colorScience"] = str(d["tipo_sensor"])
        if d.get("fuente_datos"):
            entry["manufacturerUrl"] = str(d["fuente_datos"])
        cameras.append(entry)

    dst.write_text(json.dumps(cameras, ensure_ascii=False, indent=2), encoding="utf-8")
    with_modes = sum(1 for c in cameras if c["sensorModes"])
    print(
        f"OK {len(cameras)} cámaras, {with_modes} con modos, "
        f"{sum(len(c['sensorModes']) for c in cameras)} modos "
        f"({skipped_modes} modos sin gate_mm omitidos) → {dst}"
    )
    wb.close()


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__)
        return 2
    export(Path(argv[1]), Path(argv[2]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
