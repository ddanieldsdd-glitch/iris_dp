"""
IRIS Stage Link: IRIS mueve las luces, el sol y el cielo de Unreal en vivo.
===========================================================================

IRIS llama por la Remote Control API de Unreal (HTTP, puerto 30010) a las
funciones de la clase `IrisStageLink`. Esta clase la registra este módulo
al abrir el editor (lo importa `init_unreal.py`). Así no hace falta activar
la ejecución remota de Python, que dejaría ejecutar cualquier cosa.

Lo que llega ya está en unidades de Unreal (cm, rotadores en grados,
candelas, lux, kelvin): la conversión se hace en IRIS
(`lib/features/unreal_link/unreal_stage_payload.dart`) y aquí solo se
aplica.

Cada pieza de IRIS es un actor con la etiqueta `iris:<id>` dentro de la
carpeta «IRIS» del World Outliner. Lo que no lleva esa etiqueta no se toca.

Funciones:
  Ping()             → {"ok": true, "version": …}
  ApplyScene(json)   → {"ok": true, "lights": n, "ms": …}
  Snapshot()         → {"ok": true, "actors": {id: {loc, rot, intensity, cct}}}

La ruta del objeto para Remote Control es
`/Game/Python/iris_stage_link_PY.Default__IrisStageLink` (el módulo tiene
que estar en Content/Python del proyecto).
"""

import json
import time

import unreal

VERSION = 1
FOLDER = "IRIS"
TAG_PREFIX = "iris:"
SUN_ID = "_sun"
SKY_ID = "_sky"
ATMOSPHERE_ID = "_atmosphere"

_CLASSES = {
    "spot": unreal.SpotLight,
    "rect": unreal.RectLight,
    "point": unreal.PointLight,
}

# id → actor, para no recorrer el nivel en cada cambio.
_actors = {}


def _actor_subsystem():
    return unreal.get_editor_subsystem(unreal.EditorActorSubsystem)


def _alive(actor):
    try:
        return actor is not None and unreal.SystemLibrary.is_valid(actor)
    except Exception:
        return False


def _tag_id(actor):
    for tag in actor.tags:
        text = str(tag)
        if text.startswith(TAG_PREFIX):
            return text[len(TAG_PREFIX):]
    return None


def _rescan():
    """Vuelve a encontrar los actores de IRIS (al abrir otro nivel)."""
    _actors.clear()
    for actor in _actor_subsystem().get_all_level_actors():
        uid = _tag_id(actor)
        if uid is not None:
            _actors[uid] = actor


def _find(uid):
    actor = _actors.get(uid)
    if _alive(actor):
        return actor
    _rescan()
    actor = _actors.get(uid)
    return actor if _alive(actor) else None


def _vec(v):
    return unreal.Vector(float(v[0]), float(v[1]), float(v[2]))


def _rot(r):
    # unreal.Rotator(roll, pitch, yaw): con nombres para no equivocarse.
    return unreal.Rotator(roll=float(r[2]), pitch=float(r[0]), yaw=float(r[1]))


def _spawn(uid, cls, label, loc, rot):
    actor = _actor_subsystem().spawn_actor_from_class(cls, loc, rot)
    actor.set_actor_label(label)
    actor.set_folder_path(FOLDER)
    actor.tags = [unreal.Name(TAG_PREFIX + uid)]
    _actors[uid] = actor
    return actor


def _ensure(uid, cls, label, loc, rot):
    """El actor de esa pieza; si ha cambiado de clase, se rehace."""
    actor = _find(uid)
    if actor is not None and actor.get_class() != cls.static_class():
        _actor_subsystem().destroy_actor(actor)
        actor = None
    if actor is None:
        return _spawn(uid, cls, label, loc, rot)
    if actor.get_actor_label() != label:
        actor.set_actor_label(label)
    actor.set_actor_location_and_rotation(loc, rot, False, True)
    return actor


def _set(obj, name, value):
    try:
        if obj.get_editor_property(name) != value:
            obj.set_editor_property(name, value)
    except Exception as exc:
        unreal.log_warning("[IRIS Stage] %s.%s: %s" % (obj.get_name(), name, exc))


def _apply_light(light):
    uid = str(light["id"])
    kind = light.get("kind", "spot")
    cls = _CLASSES.get(kind, unreal.SpotLight)
    label = "IRIS_%s" % (light.get("name") or uid)
    actor = _ensure(uid, cls, label, _vec(light["loc"]), _rot(light["rot"]))
    comp = actor.get_component_by_class(unreal.LocalLightComponent)
    if comp is None:
        return
    on = bool(light.get("on", True))
    _set(comp, "intensity_units", unreal.LightUnits.CANDELAS)
    _set(comp, "intensity", float(light.get("cd", 0)) if on else 0.0)
    _set(comp, "use_temperature", True)
    _set(comp, "temperature", float(light.get("cct", 3200)))
    _set(comp, "attenuation_radius", float(light.get("reachCm", 5000)))
    size = float(light.get("sizeCm", 10))
    if kind == "spot":
        _set(comp, "outer_cone_angle", float(light.get("outerDeg", 30)))
        _set(comp, "inner_cone_angle", float(light.get("innerDeg", 10)))
        _set(comp, "source_radius", size / 2)
    elif kind == "rect":
        _set(comp, "source_width", float(light.get("widthCm", size)))
        _set(comp, "source_height", float(light.get("heightCm", size)))
    else:
        _set(comp, "source_radius", size / 2)


def _apply_sun(sun):
    actor = _find(SUN_ID)
    if sun is None:
        if actor is not None:
            comp = actor.get_component_by_class(unreal.DirectionalLightComponent)
            if comp is not None:
                _set(comp, "intensity", 0.0)
        return
    actor = _ensure(SUN_ID, unreal.DirectionalLight, "IRIS_Sol",
                    unreal.Vector(0, 0, 1000), _rot(sun["rot"]))
    comp = actor.get_component_by_class(unreal.DirectionalLightComponent)
    if comp is None:
        return
    _set(comp, "intensity", float(sun.get("lux", 0)))
    _set(comp, "use_temperature", True)
    _set(comp, "temperature", float(sun.get("cct", 5400)))
    _set(comp, "atmosphere_sun_light", True)


def _apply_sky(sky):
    if sky is None:
        return
    if _find(ATMOSPHERE_ID) is None:
        _spawn(ATMOSPHERE_ID, unreal.SkyAtmosphere, "IRIS_Atmosfera",
               unreal.Vector(0, 0, 0), unreal.Rotator())
    actor = _find(SKY_ID)
    if actor is None:
        actor = _spawn(SKY_ID, unreal.SkyLight, "IRIS_Cielo",
                       unreal.Vector(0, 0, 500), unreal.Rotator())
    comp = actor.get_component_by_class(unreal.SkyLightComponent)
    if comp is not None:
        _set(comp, "real_time_capture", True)
        _set(comp, "intensity", float(sky.get("scale", 1.0)))


def _remove(ids):
    for uid in ids:
        actor = _find(str(uid))
        if actor is not None:
            _actor_subsystem().destroy_actor(actor)
            _actors.pop(str(uid), None)


def _apply(data):
    lights = data.get("lights", [])
    if data.get("full"):
        # Escena entera: lo de IRIS que ya no está, fuera.
        _rescan()
        keep = {str(l["id"]) for l in lights} | {SUN_ID, SKY_ID, ATMOSPHERE_ID}
        _remove([uid for uid in list(_actors) if uid not in keep])
    _remove(data.get("remove", []))
    for light in lights:
        _apply_light(light)
    if "sun" in data:
        _apply_sun(data["sun"])
    if "sky" in data:
        _apply_sky(data["sky"])
    return len(lights)


def _round(v, n=1):
    return round(float(v), n)


def _snapshot():
    """Cómo están ahora en Unreal las piezas de IRIS (las haya movido IRIS o
    alguien en el editor)."""
    _rescan()
    out = {}
    for uid, actor in _actors.items():
        loc = actor.get_actor_location()
        rot = actor.get_actor_rotation()
        item = {
            "loc": [_round(loc.x), _round(loc.y), _round(loc.z)],
            "rot": [_round(rot.pitch, 2), _round(rot.yaw, 2), _round(rot.roll, 2)],
        }
        comp = actor.get_component_by_class(unreal.LightComponent)
        if comp is not None:
            item["intensity"] = _round(comp.get_editor_property("intensity"))
            item["cct"] = _round(comp.get_editor_property("temperature"))
        out[uid] = item
    return out


@unreal.uclass()
class IrisStageLink(unreal.BlueprintFunctionLibrary):
    """Lo que IRIS llama por Remote Control."""

    @unreal.ufunction(static=True, ret=str, meta=dict(Category="IRIS Stage"))
    def Ping():
        return json.dumps({"ok": True, "version": VERSION,
                           "engine": unreal.SystemLibrary.get_engine_version()})

    @unreal.ufunction(static=True, params=[str], ret=str,
                      meta=dict(Category="IRIS Stage"))
    def ApplyScene(payload):
        t0 = time.perf_counter()
        try:
            data = json.loads(payload)
            if int(data.get("v", 0)) > VERSION:
                return json.dumps({"ok": False,
                                   "error": "IRIS es más nuevo que el plugin: actualízalo."})
            n = _apply(data)
            ms = (time.perf_counter() - t0) * 1000
            return json.dumps({"ok": True, "lights": n, "ms": round(ms, 1)})
        except Exception as exc:
            unreal.log_error("[IRIS Stage] %s" % exc)
            return json.dumps({"ok": False, "error": str(exc)})

    @unreal.ufunction(static=True, ret=str, meta=dict(Category="IRIS Stage"))
    def Snapshot():
        try:
            return json.dumps({"ok": True, "actors": _snapshot()})
        except Exception as exc:
            return json.dumps({"ok": False, "error": str(exc)})


unreal.log("[IRIS Stage] Link v%d listo en %s: IRIS puede conectar por Remote Control."
           % (VERSION, unreal.get_default_object(IrisStageLink).get_path_name()))
