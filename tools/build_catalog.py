#!/usr/bin/env python3
"""Genera el catálogo embebido de IRIS DP a partir de los Excel de material.

Uso (desde la raíz del repo):
  python3 tools/build_catalog.py

Entradas:
  docs/catalog/fuentes/lista_material_tecnico_v1_8.xlsx   volumen de datos
  docs/catalog/fuentes/master_auditoria_v17.xlsx          reglas + datos contrastados
  tools/catalog_base/*.json                               catálogo heredado (base)

Salidas:
  assets/catalog/cameras.json, lenses.json, lights.json, manifest.json
  docs/catalog/INFORME_CATALOGO.md

Capas, de menor a mayor prioridad: base heredada, lista v1.8, master.
Reglas del master que se aplican aquí:
  - El círculo de imagen solo se guarda si la fuente lo publica. El de la base
    estaba inferido por formato y se descarta.
  - El squeeze solo aplica a ópticas anamórficas (VAL-002).
  - Un modo de sensor sin gate no es utilizable (VAL-004).
  - Todo dato lleva estado y fuente; lo no reconocido queda PENDIENTE.

Solo usa la librería estándar.
"""

from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from xlsx_reader import Workbook  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
LISTA = ROOT / "docs/catalog/fuentes/lista_material_tecnico_v1_8.xlsx"
MASTER = ROOT / "docs/catalog/fuentes/master_auditoria_v17.xlsx"
BASE = ROOT / "tools/catalog_base"
OUT = ROOT / "assets/catalog"
REPORT = ROOT / "docs/catalog/INFORME_CATALOGO.md"
CATALOG_VERSION = 7

MODE_COLUMNS = [
    "camera_external_id", "marca", "modelo", "modo_sensor", "res_x", "res_y",
    "aspect_ratio", "gate_ancho_mm", "gate_alto_mm", "crop_x", "crop_y",
    "codec", "fps_max", "fuente",
]


# ── utilidades ──────────────────────────────────────────────────────────────

def blank(value) -> bool:
    return value is None or (isinstance(value, str) and not value.strip())


def text(value):
    return None if blank(value) else str(value).strip()


def number(value):
    if blank(value) or isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    match = re.search(r"-?\d+(?:[.,]\d+)?", str(value))
    return float(match.group(0).replace(",", ".")) if match else None


def integer(value):
    n = number(value)
    return None if n is None else int(round(n))


def truthy(value) -> bool:
    return value in (1, 1.0, True, "1", "true", "True", "sí", "si", "yes")


def norm(value) -> str:
    s = unicodedata.normalize("NFKD", str(value or "")).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "", s.lower())


def clean(record: dict) -> dict:
    """Quita claves vacías para que el JSON no lleve nulos."""
    return {k: v for k, v in record.items() if v is not None and v != [] and v != {}}


def load_base(name: str):
    return json.loads((BASE / name).read_text(encoding="utf-8"))


# ── procedencia ─────────────────────────────────────────────────────────────

AUDITED = {
    "VERIFICADO": "CONFIRMADO",
    "VERIFICADO PARCIAL": "CONFIRMADO",
    "CORREGIDO Y VERIFICADO PARCIAL": "CONFIRMADO",
    "CONTRADICTORIO": "CONFLICTO",
}


def provenance(row: dict, matrix: dict) -> dict:
    """Estado, confianza y fuente de una fila de la lista v1.8.

    Prioridad: auditoría de la lista (`estado_verificacion`), luego la marca
    histórica `estado_dato` cuando declara una fuente trazable (queda como
    SECUNDARIO: trazable pero sin auditar), y si no, PENDIENTE.
    """
    audited = AUDITED.get((text(row.get("estado_verificacion")) or "").upper())
    fields = [f.strip() for f in (text(row.get("campos_verificados")) or "").split(";") if f.strip()]
    conflicts = []
    for entry in matrix.get(row.get("external_id") or row.get("camera_external_id"), []):
        state = (text(entry.get("estado")) or "").upper()
        field = text(entry.get("campo"))
        if not field:
            continue
        if state == "CONTRADICTORIO":
            conflicts.append(field)
        elif state in AUDITED and field not in fields:
            fields.append(field)
    fields = [f for f in fields if f not in conflicts]

    if audited:
        return clean({
            "dataStatus": audited,
            "confidence": text(row.get("nivel_confianza")),
            "verifiedFields": fields,
            "sourceLabel": text(row.get("fuente_verificacion")),
            "sourceUrl": text(row.get("url_verificacion")) or text(row.get("fuente_datos")),
            "verifiedAt": text(row.get("fecha_verificacion")),
        })

    legacy = text(row.get("estado_dato")) or ""
    source = text(row.get("fuente_datos"))
    if "verific" in legacy.lower() and source:
        return clean({
            "dataStatus": "SECUNDARIO",
            "confidence": "MEDIA",
            "sourceLabel": legacy.replace("_", " "),
            "sourceUrl": source if source.startswith("http") else None,
        })
    return clean({
        "dataStatus": "PENDIENTE",
        "sourceUrl": source if source and source.startswith("http") else None,
    })


def master_sources(master: Workbook) -> dict:
    out = {}
    for row in master.records("88_Fuentes_Registro"):
        sid = text(row.get("ID fuente"))
        title = text(row.get("Título/documento"))
        if sid and title:
            out[sid] = {
                "label": f"{text(row.get('Organización/autor')) or ''} — {title}".strip(" —"),
                "url": text(row.get("URL/ubicación")),
            }
    return out


def master_provenance(status: str, source_ids: str, sources: dict, fields, date=None) -> dict:
    ids = [s.strip() for s in (source_ids or "").split(";") if s.strip()]
    known = [sources[i] for i in ids if i in sources]
    return clean({
        "dataStatus": status,
        "confidence": "ALTA",
        "verifiedFields": list(fields),
        "sourceLabel": "; ".join(s["label"] for s in known) or None,
        "sourceUrl": known[0]["url"] if known else None,
        "verifiedAt": date,
    })


def merge_provenance(target: dict, incoming: dict) -> None:
    """El master añade campos verificados y sustituye estado y fuente."""
    fields = list(target.get("verifiedFields", []))
    for field in incoming.get("verifiedFields", []):
        if field not in fields:
            fields.append(field)
    labels = [l for l in (target.get("sourceLabel"), incoming.get("sourceLabel")) if l]
    was_usable = target.get("dataStatus") in ("CONFIRMADO", "CONTRASTADO")
    target.update({k: v for k, v in incoming.items() if k not in ("verifiedFields", "sourceLabel")})
    if not was_usable:
        # La ficha no estaba auditada: el estado nuevo solo cubre estos campos.
        fields = list(incoming.get("verifiedFields", []))
        labels = labels[-1:]
    target["verifiedFields"] = fields
    if labels:
        target["sourceLabel"] = "; ".join(dict.fromkeys(labels))


# ── modos de sensor ─────────────────────────────────────────────────────────

def read_mode_rows(lista: Workbook, report: list) -> list:
    """Lee `Modos_Cámara` y recompone las filas escritas en escalera.

    A partir de cierta fila la hoja tiene cada valor de un modo en una fila
    distinta (columna A en una fila, B en la siguiente…). Se recomponen.
    """
    rows = lista.rows("Modos_Cámara")[1:]
    width = len(MODE_COLUMNS)
    out, pending, recovered = [], None, 0
    for row in rows:
        cells = [(i, v) for i, v in enumerate(row[:width]) if not blank(v)]
        if len(cells) > 1:
            out.append({MODE_COLUMNS[i]: v for i, v in cells})
            pending = None
            continue
        if not cells:
            continue
        index, value = cells[0]
        if index == 0:
            pending = {MODE_COLUMNS[0]: value}
            out.append(pending)
            recovered += 1
        elif pending is not None:
            pending[MODE_COLUMNS[index]] = value
    if recovered:
        report.append(
            f"- `Modos_Cámara`: {recovered} modos estaban escritos en escalera "
            "(un valor por fila) y se han recompuesto. Conviene corregir la hoja."
        )
    return out


def mode_from_row(row: dict) -> dict:
    return clean({
        "name": text(row.get("modo_sensor")),
        "widthMm": number(row.get("gate_ancho_mm")),
        "heightMm": number(row.get("gate_alto_mm")),
        "cropFactor": number(row.get("crop_x")),
        "cropY": number(row.get("crop_y")),
        "maxWidthPx": integer(row.get("res_x")),
        "maxHeightPx": integer(row.get("res_y")),
        "aspectRatio": text(row.get("aspect_ratio")),
        "codec": text(row.get("codec")),
        "fpsMax": number(row.get("fps_max")),
    })


def merge_mode(modes: list, incoming: dict, camera_id: str, report: list) -> None:
    """Fusiona un modo en la lista de la cámara, por nombre o por resolución."""
    name = incoming.get("name")
    if not name:
        return
    match = next((m for m in modes if norm(m.get("name")) == norm(name)), None)
    if match is None and incoming.get("maxWidthPx") and incoming.get("maxHeightPx"):
        same = [
            m for m in modes
            if m.get("maxWidthPx") == incoming["maxWidthPx"]
            and m.get("maxHeightPx") == incoming["maxHeightPx"]
        ]
        if len(same) == 1:
            match = same[0]
    if match is not None:
        kept_name = match.get("name")
        match.update(incoming)
        match["name"] = kept_name
        return
    if incoming.get("widthMm") and incoming.get("heightMm"):
        incoming.setdefault("cropFactor", 1.0)
        modes.append(incoming)
    else:
        report.append(f"- Modo sin gate, no utilizable: `{camera_id}` · {name}")


# ── cámaras ─────────────────────────────────────────────────────────────────

def build_cameras(lista, master, sources, matrix, report):
    cameras = {c["externalId"]: dict(c) for c in load_base("cameras.json")}
    for patch in load_base("cameras_expansion.json"):
        if patch["externalId"] in cameras and patch.get("sensorModes"):
            cameras[patch["externalId"]]["sensorModes"] = patch["sensorModes"]
    for camera in cameras.values():
        camera["sensorModes"] = [dict(m) for m in camera.get("sensorModes", [])]
        camera["dataStatus"] = "PENDIENTE"

    added = 0
    for row in lista.records("Cámaras"):
        cid = text(row.get("external_id"))
        if not cid or truthy(row.get("es_custom")):
            continue
        width, height = number(row.get("sensor_ancho_mm")), number(row.get("sensor_alto_mm"))
        camera = cameras.get(cid)
        if camera is None:
            if not (width and height):
                report.append(f"- Cámara sin sensor, omitida: `{cid}`")
                continue
            camera = cameras[cid] = {"externalId": cid, "sensorModes": [], "vintage": False, "lukaCompatible": False}
            added += 1
        camera.update(clean({
            "brand": text(row.get("marca")),
            "model": text(row.get("modelo")),
            "sensorWidthMm": width,
            "sensorHeightMm": height,
            "mountType": text(row.get("mount")),
            "nativeIso": integer(row.get("iso_base") if not blank(row.get("iso_base")) else row.get("iso_base_1")),
            "dynamicRangeStops": number(row.get("rango_dinamico_stops")),
            "colorScience": text(row.get("tipo_sensor")),
            "recordingFormats": text(row.get("formatos_grabacion")),
        }))
        for key in ("dataStatus", "confidence", "verifiedFields", "sourceLabel", "sourceUrl", "verifiedAt"):
            camera.pop(key, None)
        camera.update(provenance(row, matrix))

    by_label = {norm(f"{c.get('brand')}{c.get('model')}"): cid for cid, c in cameras.items()}
    by_model = {norm(c.get("model")): cid for cid, c in cameras.items()}

    listed = 0
    for row in read_mode_rows(lista, report):
        cid = text(row.get("camera_external_id"))
        if cid not in cameras:
            cid = by_label.get(norm(f"{row.get('marca')}{row.get('modelo')}")) or by_model.get(norm(row.get("modelo")))
        if cid not in cameras:
            report.append(f"- Modo de una cámara que no está en el catálogo: {row.get('camera_external_id')} · {row.get('modo_sensor')}")
            continue
        merge_mode(cameras[cid]["sensorModes"], mode_from_row(row), cid, report)
        listed += 1

    confirmed = 0
    for row in master.records("69_Camara_Modo"):
        if (text(row.get("Estado")) or "").upper() not in ("CONFIRMADO", "CONTRASTADO"):
            continue
        cid = by_label.get(norm(f"{row.get('Fabricante')}{row.get('Modelo')}")) or by_model.get(norm(row.get("Modelo")))
        if cid not in cameras:
            report.append(f"- Master: cámara sin ficha en el catálogo: {row.get('Modelo')}")
            continue
        src = sources.get(text(row.get("Fuente")) or "", {})
        mode = clean({
            "name": text(row.get("Modo")),
            "widthMm": number(row.get("Gate W mm")),
            "heightMm": number(row.get("Gate H mm")),
            "codec": text(row.get("Formato")),
            "fpsMax": number(row.get("FPS")),
            "dataStatus": text(row.get("Estado")).upper(),
            "sourceLabel": src.get("label"),
            "sourceUrl": src.get("url"),
        })
        merge_mode(cameras[cid]["sensorModes"], mode, cid, report)
        confirmed += 1

    out = []
    for camera in cameras.values():
        if not camera.get("sensorModes"):
            camera.pop("sensorModes", None)
        out.append(clean(camera))
    report.insert(0, f"- Cámaras: {len(out)} ({added} nuevas de la lista). Modos leídos de la lista: {listed}. Modos confirmados por el master: {confirmed}.")
    return out


# ── ópticas ─────────────────────────────────────────────────────────────────

def coverage_label(value, fallback):
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return fallback or ("FF" if value >= 40 else "S35")
    label = text(value)
    if label is None:
        return fallback
    upper = label.upper()
    if upper.startswith("LF"):
        return "LF"
    if upper.startswith("FULL"):
        return "FF"
    if upper.startswith("S35"):
        return "S35"
    return label


def build_lenses(lista, master, sources, matrix, report):
    lenses = {l["externalId"]: dict(l) for l in load_base("lenses.json")}
    for lens in load_base("lenses_expansion.json"):
        lenses[lens["externalId"]] = dict(lens)

    inferred = 0
    for lens in lenses.values():
        # El círculo de imagen de la base estaba inferido por formato.
        if lens.pop("imageCircleMm", None) is not None:
            inferred += 1
        lens["dataStatus"] = "PENDIENTE"

    added = published = dropped_squeeze = pending_squeeze = custom = 0
    for row in lista.records("Ópticas"):
        lid = text(row.get("external_id"))
        if not lid:
            continue
        if truthy(row.get("es_custom")):
            custom += 1
            continue
        lens = lenses.get(lid)
        focal = number(row.get("distancia_focal")) or number(row.get("focal_min_mm"))
        t_stop = number(row.get("t_stop_min"))
        coverage = coverage_label(row.get("cobertura"), (lens or {}).get("formatCoverage"))
        if lens is None:
            if not (focal and t_stop and coverage):
                report.append(f"- Óptica sin focal, T-stop o cobertura, omitida: `{lid}`")
                continue
            lens = lenses[lid] = {"externalId": lid, "vintage": False, "lukaCompatible": False}
            added += 1
        if isinstance(row.get("cobertura"), (int, float)):
            report.append(f"- `{lid}`: la columna `cobertura` trae un número ({row.get('cobertura')}); se mantiene el formato «{coverage}» y no se toma como círculo de imagen.")

        anamorphic = truthy(row.get("anamorfica"))
        squeeze = number(row.get("squeeze"))
        if squeeze is not None and not anamorphic:
            dropped_squeeze += 1
            squeeze = None
        if anamorphic and squeeze is None:
            pending_squeeze += 1
        circle = number(row.get("image_circle_mm"))
        if circle is not None:
            published += 1

        weight = number(row.get("peso_g"))
        lens.update(clean({
            "brand": text(row.get("marca")),
            "model": text(row.get("modelo")),
            "focalLength": focal,
            "focalMin": number(row.get("focal_min_mm")),
            "focalMax": number(row.get("focal_max_mm")),
            "minTStop": t_stop,
            "formatCoverage": coverage,
            "mountType": text(row.get("mount")),
            "imageCircleMm": circle,
            "closeFocusM": number(row.get("min_focus_m")),
            "squeezeRatio": squeeze,
            "lensType": text(row.get("tipo_optica")),
            "frontDiameterMm": number(row.get("front_diameter_mm")),
            "lengthMm": number(row.get("longitud_mm")),
            "weightKg": None if weight is None else round(weight / 1000, 3),
        }))
        lens["isAnamorphic"] = anamorphic
        lens["projectionType"] = "ANAMÓRFICA" if anamorphic else "ESFÉRICA"
        if not anamorphic:
            lens.pop("squeezeRatio", None)
        for key in ("dataStatus", "confidence", "verifiedFields", "sourceLabel", "sourceUrl", "verifiedAt"):
            lens.pop(key, None)
        lens.update(provenance(row, matrix))

    # Master: ficha por focal de ARRI Signature Prime.
    signature = {}
    for lid, lens in lenses.items():
        if norm(lens.get("brand")) == "arri" and "signature" in norm(lens.get("model")):
            signature[int(round(lens["focalLength"]))] = lens
    focal_specs = 0
    for row in master.records("93_Focales_Signature"):
        focal = integer(row.get("Focal"))
        lens = signature.get(focal)
        if lens is None:
            report.append(f"- Master: Signature Prime {focal} mm sin ficha en el catálogo")
            continue
        lens.update(clean({
            "minTStop": number(row.get("T-stop")),
            "mountType": text(row.get("Montura")),
            "closeFocusM": number(row.get("MOD sensor")),
            "frontDiameterMm": number(row.get("Diámetro frontal")),
            "lengthMm": number(row.get("Longitud")),
            "weightKg": number(row.get("Peso")),
            "projectionType": "ESFÉRICA",
        }))
        lens["specs"] = clean({
            "aovContext": "LF Open Gate",
            "aovH": text(row.get("AOV H")),
            "aovV": text(row.get("AOV V")),
            "aovD": text(row.get("AOV D")),
            "modFront": text(row.get("MOD front")),
            "magnification": text(row.get("Magnificación")),
            "entrancePupil": text(row.get("Entrada pupila")),
            "housingDiameter": text(row.get("Diámetro housing")),
        })
        merge_provenance(lens, master_provenance(
            (text(row.get("Estado")) or "CONFIRMADO").upper(), text(row.get("Fuente")), sources,
            ["distancia_focal", "t_stop_min", "mount", "min_focus_m", "front_diameter_mm", "longitud_mm", "peso_g"],
        ))
        focal_specs += 1

    # Master: registros de familia.
    family_notes = 0
    for row in master.records("33_Catalogo_Lentes"):
        status = (text(row.get("Estado global")) or "").upper()
        model = norm(row.get("Modelo"))
        if status not in ("CONFIRMADO", "CONTRASTADO") or not model:
            if model:
                report.append(f"- Master: `{row.get('Modelo')}` está en estado {status or 'vacío'} y no se aplica.")
            continue
        members = [l for l in lenses.values() if model in norm(l.get("model")) or model in norm(l.get("series"))]
        if not members:
            report.append(f"- Master: la familia `{row.get('Modelo')}` no tiene ópticas en el catálogo.")
            continue
        circle = number(row.get("Image Circle mm"))
        squeeze = number(row.get("Squeeze"))
        anamorphic = "ANAM" in (text(row.get("Tipo proyección")) or "").upper()
        fields = []
        for lens in members:
            lens["projectionType"] = "ANAMÓRFICA" if anamorphic else "ESFÉRICA"
            lens["isAnamorphic"] = anamorphic
            if circle is not None:
                lens["imageCircleMm"] = circle
            if anamorphic and squeeze is not None:
                lens["squeezeRatio"] = squeeze
            fields = [f for f, on in (("image_circle_mm", circle is not None), ("squeeze", anamorphic and squeeze is not None)) if on]
            merge_provenance(lens, master_provenance(status, text(row.get("Fuente principal")), sources, fields, text(row.get("Fecha contraste"))))
        family_notes += 1
        report.append(f"- Master: `{row.get('Modelo')}` aplicado a {len(members)} ópticas ({', '.join(fields) or 'tipo de proyección'}).")

    out = [clean(l) for l in lenses.values()]
    with_circle = sum(1 for l in out if l.get("imageCircleMm"))
    report.insert(1, (
        f"- Ópticas: {len(out)} ({added} nuevas de la lista). Con círculo de imagen publicado: {with_circle} "
        f"({published} de la lista, el resto del master). Círculos inferidos descartados de la base: {inferred}."
    ))
    report.insert(2, (
        f"- Squeeze descartado en {dropped_squeeze} ópticas esféricas (VAL-002). "
        f"{pending_squeeze} anamórficas no traen squeeze en la lista; conservan el de la base, sin verificar. "
        f"Fichas por focal del master: {focal_specs}. Familias del master aplicadas: {family_notes}. "
        f"{custom} ópticas marcadas `es_custom` en la lista no entran en el catálogo oficial."
    ))
    return out


# ── luces ───────────────────────────────────────────────────────────────────

def build_lights(lista, matrix, report):
    lights = {l["externalId"]: dict(l) for l in load_base("lights.json")}
    for light in lights.values():
        light["dataStatus"] = "PENDIENTE"
    added = 0
    for row in lista.records("Luces"):
        lid = text(row.get("external_id"))
        if not lid or truthy(row.get("es_custom")):
            continue
        light = lights.get(lid)
        power = integer(row.get("potencia_w"))
        if light is None:
            if power is None:
                report.append(f"- Luz sin potencia, omitida: `{lid}`")
                continue
            light = lights[lid] = {"externalId": lid, "vintage": False, "lukaCompatible": False}
            added += 1
        t_min, t_max = integer(row.get("temp_min")), integer(row.get("temp_max"))
        light.update(clean({
            "brand": text(row.get("marca")),
            "model": text(row.get("modelo")),
            "lightType": text(row.get("tipo_luz")) or text(row.get("tecnologia")),
            "powerW": power,
            "colorTempMin": t_min,
            "colorTempMax": t_max,
            "cri": integer(row.get("cri")),
            "tlci": integer(row.get("tlci")),
            "dimmingType": text(row.get("dimming")),
        }))
        light.setdefault("lightType", "led_panel")
        light.setdefault("colorTempMin", 3200)
        light.setdefault("colorTempMax", 5600)
        for key in ("dataStatus", "confidence", "verifiedFields", "sourceLabel", "sourceUrl", "verifiedAt"):
            light.pop(key, None)
        light.update(provenance(row, matrix))
    out = [clean(l) for l in lights.values()]
    report.insert(3, f"- Luces: {len(out)} ({added} nuevas de la lista).")
    return out


# ── principal ───────────────────────────────────────────────────────────────

def status_table(name, items) -> list:
    counts = {}
    for item in items:
        counts[item.get("dataStatus", "PENDIENTE")] = counts.get(item.get("dataStatus", "PENDIENTE"), 0) + 1
    usable = sum(v for k, v in counts.items() if k in ("CONFIRMADO", "CONTRASTADO", "SECUNDARIO", "CALCULADO"))
    cells = ", ".join(f"{k} {v}" for k, v in sorted(counts.items(), key=lambda kv: -kv[1]))
    return [f"| {name} | {len(items)} | {usable} | {cells} |"]


def write_json(path: Path, data) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def main() -> int:
    lista, master = Workbook(LISTA), Workbook(MASTER)
    sources = master_sources(master)
    matrix = {}
    for entry in lista.records("01_Matriz_Verificacion"):
        matrix.setdefault(text(entry.get("material_id")), []).append(entry)

    notes: list = []
    cameras = build_cameras(lista, master, sources, matrix, notes)
    lenses = build_lenses(lista, master, sources, matrix, notes)
    lights = build_lights(lista, matrix, notes)

    OUT.mkdir(parents=True, exist_ok=True)
    write_json(OUT / "cameras.json", cameras)
    write_json(OUT / "lenses.json", lenses)
    write_json(OUT / "lights.json", lights)
    write_json(OUT / "manifest.json", {
        "version": CATALOG_VERSION,
        "camerasUrl": "cameras.json",
        "lensesUrl": "lenses.json",
        "lightsUrl": "lights.json",
    })

    modes = sum(len(c.get("sensorModes", [])) for c in cameras)
    summary, details = notes[:4], notes[4:]
    lines = [
        "# Informe del catálogo generado",
        "",
        "Generado por `tools/build_catalog.py`. No editar a mano.",
        "",
        f"Versión del catálogo: {CATALOG_VERSION}. Modos de sensor en total: {modes}.",
        "",
        "## Resumen",
        "",
        *summary,
        "",
        "## Estado de los datos",
        "",
        "| Tipo | Fichas | Aptas para cálculos | Por estado |",
        "|---|---|---|---|",
        *status_table("Cámaras", cameras),
        *status_table("Ópticas", lenses),
        *status_table("Luces", lights),
        "",
        "## Incidencias",
        "",
        *(details or ["Ninguna."]),
        "",
    ]
    REPORT.write_text("\n".join(lines), encoding="utf-8")
    print("\n".join(lines[4:20]))
    print(f"… {len(details)} incidencias en {REPORT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
