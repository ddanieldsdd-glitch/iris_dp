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

Cada set de rodaje de IRIS es un mundo (nivel) propio en
`/Game/IRIS/<localización>/<set>`: al llegar otro, se guarda el anterior y
se abre (o se crea) el suyo.

Funciones:
  Ping()             → {"ok": true, "version": …}
  ApplyScene(json)   → {"ok": true, "lights": n, "ms": …, "world": ruta}
  Snapshot()         → {"ok": true, "actors": {id: {loc, rot, intensity, cct}}}
  ViewThrough(id)    → el visor del editor (y Pixel Streaming) por esa cámara
  Capture(json)      → {"ok": true, "token": …}: foto en alta por una cámara
  CaptureResult(tok) → {"ok": true, "ready": bool, "png": base64}
  FindAssets(texto)  → {"ok": true, "assets": [{path, name, sizeCm}]}

La ruta del objeto para Remote Control es
`/Game/Python/iris_stage_link_PY.Default__IrisStageLink` (el módulo tiene
que estar en Content/Python del proyecto).
"""

import base64
import json
import os
import re
import time
import unicodedata
import uuid

import unreal

VERSION = 1
FOLDER = "IRIS"
TAG_PREFIX = "iris:"
SUN_ID = "_sun"
SKY_ID = "_sky"
ATMOSPHERE_ID = "_atmosphere"
FLOOR_ID = "_floor"
WORLD_ROOT = "/Game/IRIS"
CUBE = "/Engine/BasicShapes/Cube.Cube"
PLANE = "/Engine/BasicShapes/Plane.Plane"

# Lo que no se borra al mandar IRIS la escena entera.
_FIXED = {SUN_ID, SKY_ID, ATMOSPHERE_ID, FLOOR_ID}

# Bloques de atrezzo sin asset: su malla tiene el centro en medio y la
# pieza de IRIS en la base; id → cm que se sube.
_lift = {}

# Capturas en marcha: token → (ruta, último tamaño visto).
_captures = {}

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


def _apply_camera(cam):
    uid = str(cam["id"])
    label = "IRIS_Cam_%s" % (cam.get("name") or uid)
    actor = _ensure(uid, unreal.CineCameraActor, label, _vec(cam["loc"]), _rot(cam["rot"]))
    comp = actor.get_cine_camera_component()
    if comp is None:
        return
    sensor = float(cam.get("sensorMm", 24.89))
    filmback = comp.get_editor_property("filmback")
    if abs(filmback.sensor_width - sensor) > 0.01:
        filmback.sensor_width = sensor
        filmback.sensor_height = sensor * 9 / 16
        comp.set_editor_property("filmback", filmback)
    _set(comp, "current_focal_length", float(cam.get("focalMm", 35)))


def _apply_prop(p):
    uid = str(p["id"])
    label = "IRIS_%s" % (p.get("name") or uid)
    size = [float(v) for v in p.get("sizeCm", [50, 50, 80])]
    loc = _vec(p["loc"])
    mesh = None
    asset = p.get("asset")
    # F6.20 B1: el asset llega como {path, kind}; antes, como ruta.
    path = asset.get("path") if isinstance(asset, dict) else asset
    if path:
        mesh = unreal.EditorAssetLibrary.load_asset(path)
        if not isinstance(mesh, unreal.StaticMesh):
            unreal.log_warning("[IRIS Stage] %s no es una malla: va un bloque." % path)
            mesh = None
    lift = 0.0
    if mesh is None:
        # Bloque con las medidas de la pieza, apoyado en el suelo.
        mesh = unreal.EditorAssetLibrary.load_asset(CUBE)
        lift = size[2] / 2
        loc = unreal.Vector(loc.x, loc.y, loc.z + lift)
    actor = _ensure(uid, unreal.StaticMeshActor, label, loc, _rot(p["rot"]))
    _lift[uid] = lift
    comp = actor.static_mesh_component
    if comp.static_mesh != mesh:
        comp.set_static_mesh(mesh)
    scale = (unreal.Vector(size[0] / 100, size[1] / 100, size[2] / 100)
             if lift else unreal.Vector(1, 1, 1))
    now = actor.get_actor_scale3d()
    if max(abs(now.x - scale.x), abs(now.y - scale.y), abs(now.z - scale.z)) > 0.001:
        actor.set_actor_scale3d(scale)


def _slug(text):
    # «Salón» → «Salon»: los nombres de Unreal solo admiten ASCII.
    plain = unicodedata.normalize("NFKD", str(text or "")).encode("ascii", "ignore").decode()
    return re.sub(r"[^A-Za-z0-9_]+", "_", plain).strip("_") or "IRIS"


def _world_path(world):
    folder = _slug(world.get("site") or "Sets")
    return "%s/%s/%s_%s" % (WORLD_ROOT, folder, _slug(world.get("name")), _slug(world.get("key")))


def _current_world():
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    return world.get_outermost().get_name() if world else ""


def _ensure_world(world):
    """Abre el mundo de ese set (o lo crea). Devuelve su ruta."""
    target = _world_path(world)
    current = _current_world()
    if current == target:
        return target
    levels = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
    if current.startswith(WORLD_ROOT + "/"):
        levels.save_current_level()
    else:
        dirty = [p.get_name() for p in unreal.EditorLoadingAndSavingUtils.get_dirty_map_packages()]
        if dirty and not current.startswith("/Temp/"):
            raise RuntimeError(
                "El nivel abierto en Unreal (%s) tiene cambios sin guardar. "
                "Guárdalo y vuelve a conectar: IRIS abrirá el mundo del set." % current)
    if unreal.EditorAssetLibrary.does_asset_exist(target):
        if not levels.load_level(target):
            raise RuntimeError("No se ha podido abrir %s." % target)
        _rescan()
    else:
        if not levels.new_level(target):
            raise RuntimeError("No se ha podido crear %s." % target)
        _rescan()
        floor = _spawn(FLOOR_ID, unreal.StaticMeshActor, "IRIS_Suelo",
                       unreal.Vector(0, 0, 0), unreal.Rotator())
        floor.static_mesh_component.set_static_mesh(unreal.EditorAssetLibrary.load_asset(PLANE))
        floor.set_actor_scale3d(unreal.Vector(100, 100, 1))
        levels.save_current_level()
        unreal.log("[IRIS Stage] Mundo nuevo: %s" % target)
    return target


def _capture(data):
    actor = _find(str(data["camera"]))
    if actor is None:
        raise ValueError("No hay en Unreal una cámara de IRIS con id %s." % data["camera"])
    folder = os.path.join(unreal.Paths.convert_relative_path_to_full(unreal.Paths.project_saved_dir()),
                          "IRIS", "Capturas")
    os.makedirs(folder, exist_ok=True)
    token = uuid.uuid4().hex[:12]
    path = os.path.join(folder, "%s.png" % token)
    unreal.AutomationLibrary.take_high_res_screenshot(
        int(data.get("width", 1920)), int(data.get("height", 1080)), path, camera=actor)
    _captures[token] = [path, -1]
    return token


def _capture_result(token):
    entry = _captures.get(token)
    if entry is None:
        raise ValueError("Captura desconocida.")
    path, last = entry
    size = os.path.getsize(path) if os.path.exists(path) else -1
    entry[1] = size
    # Lista cuando el archivo existe y no ha crecido desde la última vez.
    if size <= 0 or size != last:
        return None
    with open(path, "rb") as f:
        data = base64.b64encode(f.read()).decode("ascii")
    _captures.pop(token, None)
    return data


def _find_assets(query, limit=40):
    registry = unreal.AssetRegistryHelpers.get_asset_registry()
    flt = unreal.ARFilter(
        class_paths=[unreal.TopLevelAssetPath("/Script/Engine", "StaticMesh")],
        package_paths=["/Game"], recursive_paths=True)
    words = [w for w in str(query or "").lower().split() if w]
    out = []
    for data in registry.get_assets(flt):
        package = str(data.package_name)
        if package.startswith(WORLD_ROOT + "/"):
            continue
        name = str(data.asset_name)
        hay = (package + " " + name).lower()
        if any(w not in hay for w in words):
            continue
        mesh = unreal.EditorAssetLibrary.load_asset(package)
        if not isinstance(mesh, unreal.StaticMesh):
            continue
        box = mesh.get_bounding_box()
        out.append({
            "path": "%s.%s" % (package, name),
            "name": name,
            "folder": package.rsplit("/", 1)[0],
            "sizeCm": [_round(box.max.x - box.min.x), _round(box.max.y - box.min.y),
                       _round(box.max.z - box.min.z)],
        })
        if len(out) >= limit:
            break
    return out


def _view_through(uid):
    actor = _find(str(uid))
    if actor is None:
        raise ValueError("No hay en Unreal una cámara de IRIS con id %s." % uid)
    unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).pilot_level_actor(actor)


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
    cameras = data.get("cameras", [])
    props = data.get("props", [])
    if data.get("world"):
        _ensure_world(data["world"])
    if data.get("full"):
        # Escena entera: lo de IRIS que ya no está, fuera.
        _rescan()
        keep = ({str(x["id"]) for x in lights + cameras + props} | _FIXED)
        _remove([uid for uid in list(_actors) if uid not in keep])
    _remove(data.get("remove", []))
    for light in lights:
        _apply_light(light)
    for cam in cameras:
        _apply_camera(cam)
    for p in props:
        _apply_prop(p)
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
            "loc": [_round(loc.x), _round(loc.y), _round(loc.z - _lift.get(uid, 0.0))],
            "rot": [_round(rot.pitch, 2), _round(rot.yaw, 2), _round(rot.roll, 2)],
            "path": actor.get_path_name(),
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
                           "engine": unreal.SystemLibrary.get_engine_version(),
                           "project": unreal.Paths.get_project_file_path()})

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
            return json.dumps({"ok": True, "lights": n, "ms": round(ms, 1),
                               "world": _current_world()})
        except Exception as exc:
            unreal.log_error("[IRIS Stage] %s" % exc)
            return json.dumps({"ok": False, "error": str(exc)})

    @unreal.ufunction(static=True, params=[str], ret=str,
                      meta=dict(Category="IRIS Stage"))
    def ViewThrough(id):
        try:
            _view_through(id)
            return json.dumps({"ok": True})
        except Exception as exc:
            return json.dumps({"ok": False, "error": str(exc)})

    @unreal.ufunction(static=True, params=[str], ret=str,
                      meta=dict(Category="IRIS Stage"))
    def Capture(request):
        try:
            return json.dumps({"ok": True, "token": _capture(json.loads(request))})
        except Exception as exc:
            return json.dumps({"ok": False, "error": str(exc)})

    @unreal.ufunction(static=True, params=[str], ret=str,
                      meta=dict(Category="IRIS Stage"))
    def CaptureResult(token):
        try:
            png = _capture_result(token)
            return json.dumps({"ok": True, "ready": png is not None, "png": png})
        except Exception as exc:
            return json.dumps({"ok": False, "error": str(exc)})

    @unreal.ufunction(static=True, params=[str], ret=str,
                      meta=dict(Category="IRIS Stage"))
    def FindAssets(query):
        try:
            return json.dumps({"ok": True, "assets": _find_assets(query)})
        except Exception as exc:
            return json.dumps({"ok": False, "error": str(exc)})

    @unreal.ufunction(static=True, ret=str, meta=dict(Category="IRIS Stage"))
    def Snapshot():
        try:
            return json.dumps({"ok": True, "actors": _snapshot()})
        except Exception as exc:
            return json.dumps({"ok": False, "error": str(exc)})


unreal.log("[IRIS Stage] Link v%d listo en %s: IRIS puede conectar por Remote Control."
           % (VERSION, unreal.get_default_object(IrisStageLink).get_path_name()))
