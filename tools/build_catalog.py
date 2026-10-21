#!/usr/bin/env python3
"""Genera el catálogo embebido de IRIS DP a partir de los Excel de material.

Uso (desde la raíz del repo):
  python3 tools/build_catalog.py

Entradas:
  docs/catalog/fuentes/lista_material_tecnico_v1_8.xlsx   volumen de datos
  docs/catalog/fuentes/master_auditoria_v17.xlsx          reglas + datos contrastados
  docs/catalog/fuentes/flujo_sxt_superspeed_v2_0.xlsx     v2.0: cámaras, gates, SXT, Super Speed
  tools/catalog_base/*.json                               catálogo heredado (base)

Salidas:
  assets/catalog/cameras.json, lenses.json, lights.json, manifest.json
  assets/catalog/recording.json    medios y formatos de grabación por cámara
  assets/catalog/retired.json      fichas heredadas que la app debe retirar
  docs/catalog/INFORME_CATALOGO.md

Capas, de menor a mayor prioridad: base heredada, lista v1.8, master v17,
flujo v2.0.
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
FLUJO = ROOT / "docs/catalog/fuentes/flujo_sxt_superspeed_v2_0.xlsx"
BASE = ROOT / "tools/catalog_base"
OUT = ROOT / "assets/catalog"
REPORT = ROOT / "docs/catalog/INFORME_CATALOGO.md"
CATALOG_VERSION = 10

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


# ── flujo v2.0 ──────────────────────────────────────────────────────────────

# Ids que ya usaba la lista v1.8 en `Modos_Cámara` para estas cámaras.
FLUJO_CAMERA_IDS = {
    "alexa35xtreme": "arri_alexa35_xtreme",
    "pyxis6kpl": "blackmagic_pyxis_6k_pl",
    "ursacine17k65": "blackmagic_ursa_cine_17k_65",
    "ursacine12klf": "blackmagic_ursa_cine_12k_lf",
}
SXT_ID = "arri_alexa_sxt"

# Fichas heredadas que se retiran del catálogo, con el motivo.
RETIRED_LENSES = [
    (
        re.compile(r"^zeiss_super_speed_mk[123]_\d+$"),
        "Familia heredada con datos erróneos (T2.8 y focales 16/20/24 mm que no "
        "existen en Super Speed). La sustituyen «Super Speed MKI» y «Super Speed MKII/III».",
    ),
]


def flujo_sources(flujo: Workbook) -> dict:
    return {
        text(row.get("ID")): {"label": text(row.get("Descripción")), "url": text(row.get("URL"))}
        for row in flujo.records("12_Fuentes")
        if text(row.get("ID")) and text(row.get("URL"))
    }


def flujo_status(raw) -> str:
    """Estado del flujo v2.0 traducido a los estados del master."""
    value = (text(raw) or "").upper()
    if value.startswith("CONFIRMADO") or value.startswith("DISCREPANCIA MENOR"):
        return "CONFIRMADO"
    if value.startswith("CALCULADO"):
        return "CALCULADO"
    if value.startswith("CONTRASTE"):
        # «Medido por terceros»: es una observación, no una especificación.
        return "OBSERVADO"
    return "PENDIENTE"


def flujo_provenance(status_raw, source_ids, sources, fields, date=None) -> dict:
    ids = [s.strip() for s in (text(source_ids) or "").split(";") if s.strip()]
    known = [sources[i] for i in ids if i in sources]
    status = flujo_status(status_raw)
    return clean({
        "dataStatus": status,
        "confidence": "ALTA" if status == "CONFIRMADO" else "MEDIA",
        "verifiedFields": list(fields),
        "sourceLabel": "; ".join(s["label"] for s in known) or None,
        "sourceUrl": known[0]["url"] if known else None,
        "verifiedAt": text(date),
    })


def mm_pair(value):
    """«28,25 x 18,17 mm» → (28.25, 18.17)."""
    found = re.findall(r"\d+(?:[.,]\d+)?", str(value or ""))
    return (float(found[0].replace(",", ".")), float(found[1].replace(",", "."))) if len(found) >= 2 else (None, None)


def add_flujo_cameras(cameras: dict, flujo: Workbook, sources: dict, report: list) -> int:
    added = 0
    by_model = {norm(c.get("model")): cid for cid, c in cameras.items()}
    for row in flujo.records("08_Camaras_Faltantes"):
        model = text(row.get("Modelo (nombre exacto en Modos_Cámara)"))
        width, height = number(row.get("Sensor W (mm)")), number(row.get("Sensor H (mm)"))
        if not (model and width and height):
            continue
        cid = FLUJO_CAMERA_IDS.get(norm(model)) or by_model.get(norm(model))
        if cid is None:
            cid = f"{norm(row.get('Fabricante'))}_{norm(model)}"
        camera = cameras.get(cid)
        if camera is None:
            camera = cameras[cid] = {"externalId": cid, "sensorModes": [], "vintage": False, "lukaCompatible": False}
            added += 1
        brand = text(row.get("Fabricante")) or ""
        camera.update(clean({
            "brand": "Blackmagic" if brand.startswith("Blackmagic") else brand,
            "model": model,
            "sensorWidthMm": width,
            "sensorHeightMm": height,
            "mountType": (text(row.get("Montura")) or "").split(" ")[0].strip(";") or None,
            "pixelPitchUm": number(row.get("Pitch (µm)")),
        }))
        merge_provenance(camera, flujo_provenance(
            row.get("Estado"), row.get("Fuente"), sources,
            ["sensor_ancho_mm", "sensor_alto_mm", "mount"], row.get("Fecha consulta"),
        ))
    # ALEXA SXT: ficha de cámara.
    sxt = cameras.get(SXT_ID)
    if sxt is not None:
        params = {text(r.get("Parámetro")): r for r in flujo.records("13_SXT_Camara")}
        size = params.get("Tamaño total (Open Gate)")
        if size:
            w, h = mm_pair(size.get("Valor"))
            if w and h:
                sxt["sensorWidthMm"], sxt["sensorHeightMm"] = w, h
        pitch = params.get("Pitch (tamaño de photosite)")
        if pitch:
            sxt["pixelPitchUm"] = number(str(pitch.get("Valor")).replace(",", "."))
        if params.get("Montura de serie"):
            sxt["mountType"] = "PL"
        if params.get("Códecs"):
            sxt["recordingFormats"] = text(params["Códecs"].get("Valor"))
        merge_provenance(sxt, flujo_provenance(
            "CONFIRMADO", "F07; F09", sources, ["sensor_ancho_mm", "sensor_alto_mm", "mount"],
        ))
    return added


def apply_flujo_modes(cameras: dict, flujo: Workbook, sources: dict, report: list) -> int:
    by_model = {norm(c.get("model")): cid for cid, c in cameras.items()}
    count = 0
    for row in flujo.records("09_Gates_Modos"):
        name = text(row.get("Modo"))
        width, height = number(row.get("Gate W final (mm)")), number(row.get("Gate H final (mm)"))
        if not (text(row.get("ID modo")) and name and width and height):
            continue
        cid = FLUJO_CAMERA_IDS.get(norm(row.get("Cámara"))) or by_model.get(norm(row.get("Cámara")))
        if cid not in cameras:
            report.append(f"- Flujo v2.0: modo de una cámara sin ficha: {row.get('Cámara')} · {name}")
            continue
        src = sources.get((text(row.get("Fuente")) or "").split(";")[0].strip(), {})
        status = flujo_status(row.get("Estado"))
        if status == "PENDIENTE":
            report.append(f"- Gate pendiente de confirmar: `{cid}` · {name} ({text(row.get('Estado'))})")
        merge_mode(cameras[cid]["sensorModes"], clean({
            "name": name,
            "widthMm": width,
            "heightMm": height,
            "maxWidthPx": integer(row.get("Ancho (px)")),
            "maxHeightPx": integer(row.get("Alto (px)")),
            "cropFactor": 1.0,
            "readout": text(row.get("Tipo de lectura")),
            "gateMethod": text(row.get("Método")),
            "dataStatus": status,
            "sourceLabel": src.get("label"),
            "sourceUrl": src.get("url"),
            "note": text(row.get("Observación")),
        }), cid, report)
        count += 1

    # ALEXA SXT: sus 14 formatos sustituyen a los modos heredados.
    sxt = cameras.get(SXT_ID)
    sxt_modes = []
    for row in flujo.records("14_SXT_Modos"):
        if not (text(row.get("ID modo")) or "").startswith("SXT-"):
            continue
        width = number(row.get("Gate W publicado (mm)")) or number(row.get("Gate W calc (mm)"))
        height = number(row.get("Gate H publicado (mm)")) or number(row.get("Gate H calc (mm)"))
        src = sources.get((text(row.get("Fuente")) or "").split(";")[0].strip(), {})
        sxt_modes.append(clean({
            "name": f"{text(row.get('Modo de sensor'))} · {text(row.get('Formato de grabación'))}",
            "sensorMode": text(row.get("Modo de sensor")),
            "widthMm": width,
            "heightMm": height,
            "cropFactor": 1.0,
            "maxWidthPx": integer(row.get("Grabación W (px)")),
            "maxHeightPx": integer(row.get("Grabación H (px)")),
            "sensorAreaWidthPx": integer(row.get("Área sensor W (px)")),
            "sensorAreaHeightPx": integer(row.get("Área sensor H (px)")),
            "codec": text(row.get("Familia")),
            "fpsMax": number(row.get("FPS máx.")),
            "sphericalOk": text(row.get("Apto óptica esférica")),
            "recommendedUse": text(row.get("Uso recomendado (ARRI)")),
            "dataStatus": flujo_status(row.get("Estado")),
            "sourceLabel": src.get("label"),
            "sourceUrl": src.get("url"),
            "note": text(row.get("Observación")),
        }))
    if sxt is not None and sxt_modes:
        sxt["sensorModes"] = sxt_modes
        count += len(sxt_modes)
    return count


def apply_flujo_lenses(lenses: dict, flujo: Workbook, sources: dict, report: list) -> int:
    count = 0
    for row in flujo.records("17_Opticas_SuperSpeed"):
        focal = integer(row.get("Focal (mm)"))
        if not (text(row.get("ID óptica")) or "").startswith("ZSS-") or focal is None:
            continue
        # El set de NAPALM es un juego físico concreto: tiene sus propias
        # fichas, aparte de las familias genéricas MKI y MKII/III.
        lid = f"zeiss_super_speed_napalm_{focal}"
        lens = lenses.get(lid)
        if lens is None:
            lens = lenses[lid] = {
                "externalId": lid, "brand": "ZEISS", "model": "Super Speed MKII (NAPALM)",
                "formatCoverage": "S35", "vintage": True, "lukaCompatible": False, "isAnamorphic": False,
            }
        lens.pop("squeezeRatio", None)
        lens.update(clean({
            "focalLength": float(focal),
            "focalMin": float(focal),
            "focalMax": float(focal),
            "minTStop": number(row.get("T máx.")),
            "mountType": text(row.get("Montura")),
            "imageCircleMm": number(row.get("Círculo típico (mm)")),
            "closeFocusM": number(row.get("Enfoque mínimo NAPALM (m)")),
            "frontDiameterMm": number(row.get("Diámetro frontal (mm)")),
            "weightKg": number(row.get("Peso NAPALM (kg)")),
            "projectionType": "ESFÉRICA",
            "series": "Super Speed MKII (NAPALM)",
        }))
        lens["isAnamorphic"] = False
        lens["specs"] = clean({
            "imageCircleWorstMm": number(row.get("Círculo peor caso (mm)")),
            "circleT13InfinityMm": number(row.get("Círculo T1.3 infinito (mm)")),
            "circleT13CloseMm": number(row.get("Círculo T1.3 enfoque mín. (mm)")),
            "circleT16InfinityMm": number(row.get("Círculo T16 infinito (mm)")),
            "circleT16CloseMm": number(row.get("Círculo T16 enfoque mín. (mm)")),
            "irisBlades": integer(row.get("Palas de iris (MKII)")),
            "version": text(row.get("Versión según NAPALM")),
            "closeFocusAltM": number(row.get("Enfoque mínimo Camaleon (m)")),
            "note": text(row.get("Observación")),
        })
        for key in ("dataStatus", "confidence", "verifiedFields", "sourceLabel", "sourceUrl", "verifiedAt"):
            lens.pop(key, None)
        lens.update(flujo_provenance(
            row.get("Estado"), row.get("Fuente"), sources,
            ["image_circle_mm", "distancia_focal", "t_stop_min", "mount", "min_focus_m", "front_diameter_mm", "peso_g"],
        ))
        count += 1
    return count


def build_recording(flujo: Workbook, sources: dict) -> dict:
    """Medios y formatos de grabación con sus tasas y tiempos (ALEXA SXT)."""
    rows = flujo.rows("15_SXT_Almacenamiento")
    media, formats, header = [], [], None
    media_columns = {}
    for row in rows[1:]:
        cells = list(row) + [None] * 12
        first = text(cells[0])
        if first is None:
            continue
        if first == "ID formato":
            header = [text(c) for c in cells]
            continue
        if header is None:
            capacity = number(cells[1])
            if capacity is None:
                continue
            src = sources.get((text(cells[8]) or "").split(";")[0].strip(), {})
            media.append(clean({
                "id": norm(first),
                "name": first,
                "capacityGb": capacity,
                "adapter": text(cells[2]),
                "arriraw": (text(cells[3]) or "").lower().startswith("s"),
                "prores": (text(cells[4]) or "").lower().startswith("s"),
                "proresRaid": (text(cells[5]) or "").lower().startswith("s"),
                "interface": text(cells[6]),
                "dock": text(cells[7]),
                "dataStatus": flujo_status(cells[9]),
                "sourceLabel": src.get("label"),
                "sourceUrl": src.get("url"),
                "note": text(cells[10]),
            }))
            continue
        if not first.startswith("REC-"):
            continue
        if not media_columns:
            # Las columnas de tiempos se emparejan con los medios por capacidad.
            for index, title in enumerate(header):
                size = number(title) if title and "GB" in title or title and "TB" in title else None
                if size is None:
                    continue
                gb = size * 1000 if "TB" in title else size
                match = next((m for m in media if m["capacityGb"] == gb), None)
                if match:
                    media_columns[index] = match["id"]
        minutes = {}
        for index, media_id in media_columns.items():
            value = cells[index]
            if isinstance(value, (int, float)) and not isinstance(value, bool):
                minutes[media_id] = int(round(value * 1440))
        formats.append(clean({
            "id": first,
            "mode": text(cells[1]),
            "codec": text(cells[2]),
            "rateMbPerSec": number(cells[9]),
            "gbPerHour": number(cells[11]),
            "minutesByMedia": minutes,
        }))
    return {"cameras": [{"cameraId": SXT_ID, "fps": 24, "media": media, "formats": formats}]} if formats else {"cameras": []}


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

def build_cameras(lista, master, sources, matrix, report, flujo, flujo_src):
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

    added += add_flujo_cameras(cameras, flujo, flujo_src, report)

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

    flujo_modes = apply_flujo_modes(cameras, flujo, flujo_src, report)

    out = []
    for camera in cameras.values():
        if not camera.get("sensorModes"):
            camera.pop("sensorModes", None)
        out.append(clean(camera))
    report.insert(0, f"- Cámaras: {len(out)} ({added} nuevas respecto a la base). Modos leídos de la lista: {listed}. Modos confirmados por el master: {confirmed}. Modos del flujo v2.0: {flujo_modes}.")
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


def build_lenses(lista, master, sources, matrix, report, flujo, flujo_src):
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

    retired = []
    for lid in list(lenses):
        for pattern, reason in RETIRED_LENSES:
            if pattern.match(lid):
                retired.append(lid)
                del lenses[lid]
                break
    if retired:
        report.append(f"- Retiradas {len(retired)} ópticas heredadas: {RETIRED_LENSES[0][1]}")
    build_lenses.retired = sorted(retired)

    flujo_lenses = apply_flujo_lenses(lenses, flujo, flujo_src, report)
    report.append(f"- Flujo v2.0: {flujo_lenses} ópticas ZEISS Super Speed con círculo de imagen medido (típico y peor caso).")

    out = [clean(l) for l in lenses.values()]
    with_circle = sum(1 for l in out if l.get("imageCircleMm"))
    report.insert(1, (
        f"- Ópticas: {len(out)} ({added} nuevas de la lista). Con círculo de imagen publicado: {with_circle} "
        f"({published} de la lista; el resto, del master y del flujo v2.0). Círculos inferidos descartados de la base: {inferred}."
    ))
    report.insert(2, (
        f"- Squeeze descartado en {dropped_squeeze} ópticas esféricas (VAL-002). "
        f"{pending_squeeze} anamórficas no traen squeeze en la lista; conservan el de la base, sin verificar. "
        f"Fichas por focal del master: {focal_specs}. Familias del master aplicadas: {family_notes}. "
        f"{custom} ópticas marcadas `es_custom` en la lista no entran en el catálogo oficial."
    ))
    return out


# ── luces ───────────────────────────────────────────────────────────────────

# Vocabulario cerrado del tipo de luz: «<tecnología>_<formato>». Lo lee
# `lib/shared/equipment/light_kind.dart`.
LIGHT_FORMATS = ("fresnel", "panel", "flex", "tube", "cob", "balloon", "practical", "open", "profile")
LIGHT_TECHS = ("led", "hmi", "tungsten", "fluorescent")

# Columnas de la hoja Luces que mandan sobre la revisión cuando vienen
# rellenas. Las cuatro últimas aún no existen en la lista v1.8.
LIGHT_EXCEL_COLUMNS = ("formato", "tecnologia", "haz_grados", "fotometria_lux",
                       "fotometria_distancia_m", "fotometria_condicion")

FORMAT_WORDS = {
    "fresnel": "fresnel", "panel": "panel", "panel flexible": "flex", "flexible": "flex", "flex": "flex",
    "tubo": "tube", "tube": "tube", "cob": "cob", "puntual": "cob", "globo": "balloon", "balloon": "balloon",
    "practica": "practical", "practical": "practical", "par": "open", "abierta": "open", "open": "open",
    "recorte": "profile", "profile": "profile",
}
TECH_WORDS = {"led": "led", "hmi": "hmi", "tungsteno": "tungsten", "tungsten": "tungsten",
              "fluorescente": "fluorescent", "fluorescent": "fluorescent"}


def light_kind(raw, model=""):
    """(tecnología, formato) de un tipo escrito como venga: «led_panel»,
    «LED Panel», «LED point-source», «fresnel», «hmi»…"""
    t = re.sub(r"[_\-]+", " ", (raw or "").lower()).strip()
    words = set(t.split())
    for tech in LIGHT_TECHS:
        for fmt in LIGHT_FORMATS:
            if t == f"{tech} {fmt}":
                return tech, fmt
    tech = "hmi" if "hmi" in words else "led" if "led" in words else \
        "fluorescent" if words & {"fluorescent", "kino", "flo"} else None
    if "balloon" in words or "globo" in words:
        fmt = "balloon"
    elif "practical" in words or "practica" in words:
        fmt = "practical"
    elif "flexible" in words or "flex" in words:
        fmt = "flex"
    elif "tube" in words or "pixel" in words or "bar" in words:
        fmt = "tube"
    elif "panel" in words:
        fmt = "panel"
    elif "fresnel" in words:
        fmt = "fresnel"
    elif words & {"par", "open"}:
        fmt = "open"
    elif words & {"profile", "ellipsoidal"}:
        fmt = "profile"
    elif tech == "hmi":
        fmt = "fresnel"
    elif tech == "led":
        fmt = "cob"
    else:
        fmt = "fresnel"
    if tech is None:
        tech = "fluorescent" if fmt == "tube" else "led" if fmt in ("panel", "flex", "balloon") else "tungsten"
    return tech, fmt


def excel_word(value, words):
    key = norm(value)
    for word, code in words.items():
        if norm(word) == key:
            return code
    return None


def build_lights(lista, matrix, report):
    lights = {l["externalId"]: dict(l) for l in load_base("lights.json")}
    revision = load_base("lights_revision.json")
    fichas, duplicates = revision["fichas"], revision["duplicados"]
    for light in lights.values():
        light["dataStatus"] = "PENDIENTE"
    added = 0
    excel = {}
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
        excel[lid] = row

    # Revisión: tipo cerrado, correcciones, haz y fotometría con fuente.
    to_fix = []
    for lid, light in lights.items():
        row = excel.get(lid, {})
        fix = fichas.get(lid, {})
        tech, fmt = light_kind(light.get("lightType"), light.get("model", ""))
        listed = (tech, fmt)
        fmt = excel_word(row.get("formato"), FORMAT_WORDS) or fix.get("format") or fmt
        tech = excel_word(row.get("tecnologia"), TECH_WORDS) or fix.get("technology") or tech
        if row and (tech, fmt) != listed and not text(row.get("formato")):
            to_fix.append(f"`{lid}`: tipo_luz «{light.get('lightType')}» → formato «{fmt}», tecnologia «{tech}»")
        light["lightType"] = f"{tech}_{fmt}"
        for key in ("brand", "powerW", "beamAngleDeg", "lukaCompatible", "lukaFixtureId"):
            if key in fix:
                if key == "powerW" and row and integer(row.get("potencia_w")) not in (None, fix[key]):
                    to_fix.append(f"`{lid}`: potencia_w {integer(row.get('potencia_w'))} → {fix[key]}")
                if fix[key] is None:
                    light.pop(key, None)
                else:
                    light[key] = fix[key]
        if "dataStatus" in fix:
            light["dataStatus"] = fix["dataStatus"]
            light["sourceLabel"] = fix.get("note")
        beam = number(row.get("haz_grados"))
        if beam is not None:
            light["beamAngleDeg"] = beam
        photo = fix.get("photometry")
        lux, dist = number(row.get("fotometria_lux")), number(row.get("fotometria_distancia_m"))
        if lux is not None and dist is not None:
            light["photometryLux"], light["photometryDistanceM"] = lux, dist
        elif photo:
            light["photometryLux"], light["photometryDistanceM"] = photo["lux"], photo["distanceM"]
            if light.get("dataStatus") in (None, "PENDIENTE"):
                light.update(clean({
                    "dataStatus": photo["status"],
                    "verifiedFields": ["haz_grados", "fotometria_lux", "fotometria_distancia_m"],
                    "sourceLabel": f"{photo['sourceLabel']} — {photo['condition']}",
                    "sourceUrl": photo.get("sourceUrl"),
                    "verifiedAt": photo.get("verifiedAt"),
                }))
        if not light.get("lukaFixtureId"):
            light["lukaCompatible"] = False

    # Duplicados: la ficha que queda se completa con lo que traía la otra.
    for old, new in duplicates.items():
        gone = lights.pop(old, None)
        if gone is None:
            report.append(f"- Duplicado ya no está en la lista: `{old}`")
            continue
        for key, value in gone.items():
            lights[new].setdefault(key, value)
        if old in excel:
            to_fix.append(f"`{old}`: duplicado de `{new}`; quitar la fila")
    build_lights.retired = dict(duplicates)

    out = [clean(l) for l in lights.values()]
    with_photo = sum(1 for l in out if "photometryLux" in l)
    with_beam = sum(1 for l in out if "beamAngleDeg" in l)
    report.insert(3, (
        f"- Luces: {len(out)} ({added} nuevas de la lista, {len(duplicates)} duplicados retirados). "
        f"Con haz: {with_beam}; con fotometría: {with_photo}."
    ))
    if to_fix:
        report.append("- Luces que la revisión corrige y conviene corregir también en el Excel:")
        report.extend(f"  - {line}" for line in to_fix)
    return out


# ── principal ───────────────────────────────────────────────────────────────

def status_table(name, items) -> list:
    counts = {}
    for item in items:
        counts[item.get("dataStatus", "PENDIENTE")] = counts.get(item.get("dataStatus", "PENDIENTE"), 0) + 1
    usable = sum(v for k, v in counts.items() if k in ("CONFIRMADO", "CONTRASTADO", "SECUNDARIO", "CALCULADO", "OBSERVADO"))
    cells = ", ".join(f"{k} {v}" for k, v in sorted(counts.items(), key=lambda kv: -kv[1]))
    return [f"| {name} | {len(items)} | {usable} | {cells} |"]


def write_json(path: Path, data) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def main() -> int:
    lista, master, flujo = Workbook(LISTA), Workbook(MASTER), Workbook(FLUJO)
    sources = master_sources(master)
    flujo_src = flujo_sources(flujo)
    matrix = {}
    for entry in lista.records("01_Matriz_Verificacion"):
        matrix.setdefault(text(entry.get("material_id")), []).append(entry)

    notes: list = []
    cameras = build_cameras(lista, master, sources, matrix, notes, flujo, flujo_src)
    lenses = build_lenses(lista, master, sources, matrix, notes, flujo, flujo_src)
    recording = build_recording(flujo, flujo_src)
    lights = build_lights(lista, matrix, notes)

    OUT.mkdir(parents=True, exist_ok=True)
    write_json(OUT / "cameras.json", cameras)
    write_json(OUT / "lenses.json", lenses)
    write_json(OUT / "lights.json", lights)
    write_json(OUT / "recording.json", recording)
    write_json(OUT / "retired.json", {"lenses": build_lenses.retired, "lights": build_lights.retired})
    write_json(OUT / "manifest.json", {
        "version": CATALOG_VERSION,
        "camerasUrl": "cameras.json",
        "lensesUrl": "lenses.json",
        "lightsUrl": "lights.json",
        "recordingUrl": "recording.json",
        "retiredUrl": "retired.json",
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
        "Grabación: " + "; ".join(
            f"`{c['cameraId']}` con {len(c['media'])} medios y {len(c['formats'])} formatos"
            for c in recording["cameras"]
        ) + ".",
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
