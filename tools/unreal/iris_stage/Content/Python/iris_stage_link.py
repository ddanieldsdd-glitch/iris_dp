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
  FindAssets(texto)  → {"ok": true, "assets": [{path, name, kind, source, sizeCm}]}
  FindFabAssets(txt) → lo mismo, solo lo bajado de Fab y Megascans (F6.20 D2)
  AssetPreview(ruta) → {"ok": true, "top": png64, "threeQuarter": png64, "topSpanCm"}

Los escaneos de la planta (RealityScan, Polycam…, F6.12) llegan con el
nombre de su archivo y las carpetas de IRIS donde buscarlo en este PC; se
importan una vez a `/Game/IRIS/Scans/<nombre>` y se ponen en su sitio.

La ruta del objeto para Remote Control es
`/Game/Python/iris_stage_link_PY.Default__IrisStageLink` (el módulo tiene
que estar en Content/Python del proyecto).
"""

import base64
import json
import math
import os
import re
import struct
import time
import unicodedata
import uuid
import zlib

import unreal

VERSION = 1
FOLDER = "IRIS"
TAG_PREFIX = "iris:"
SUN_ID = "_sun"
SKY_ID = "_sky"
ATMOSPHERE_ID = "_atmosphere"
FLOOR_ID = "_floor"
POST_ID = "_post"
FOG_ID = "_fog"
STRUCTURE_ID = "_structure"
WORLD_ROOT = "/Game/IRIS"
STRUCTURE_ROOT = WORLD_ROOT + "/Estructura"
SCAN_ROOT = WORLD_ROOT + "/Scans"
# Una malla de más de un escaneo (la importación da varias): id#p<n>.
PART = "#p"
CUBE = "/Engine/BasicShapes/Cube.Cube"
PLANE = "/Engine/BasicShapes/Plane.Plane"

# Lo que no se borra al mandar IRIS la escena entera.
_FIXED = {SUN_ID, SKY_ID, ATMOSPHERE_ID, FLOOR_ID, POST_ID, STRUCTURE_ID, FOG_ID}

# Etiqueta con la ruta del asset que hace de una pieza (F6.20 B2): si el
# asset cambia, el actor se rehace.
ASSET_TAG = "iris_asset:"

# El cuerpo (asset) de un foco o una cámara es otro actor, unido a ellos.
BODY = "#cuerpo"

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


def _asset_of(actor):
    for tag in actor.tags:
        text = str(tag)
        if text.startswith(ASSET_TAG):
            return text[len(ASSET_TAG):]
    return None


def _asset_path(asset):
    # {path, kind}; antes (F6.19), solo la ruta.
    return asset.get("path") if isinstance(asset, dict) else asset


def _place_asset(uid, label, asset, loc, rot):
    """El actor de un asset de Unreal (malla, Blueprint o personaje) en su
    sitio. Si la pieza tenía otro asset (o era un bloque), se rehace."""
    path = _asset_path(asset)
    actor = _find(uid)
    if actor is not None and _asset_of(actor) != path:
        _actor_subsystem().destroy_actor(actor)
        _actors.pop(uid, None)
        actor = None
    if actor is None:
        obj = unreal.EditorAssetLibrary.load_asset(path)
        if obj is None:
            unreal.log_warning("[IRIS Stage] No encuentro el asset %s." % path)
            return None
        actor = _actor_subsystem().spawn_actor_from_object(obj, loc, rot)
        if actor is None:
            unreal.log_warning("[IRIS Stage] %s no se puede poner en el nivel." % path)
            return None
        actor.set_actor_label(label)
        actor.set_folder_path(FOLDER)
        actor.tags = [unreal.Name(TAG_PREFIX + uid), unreal.Name(ASSET_TAG + path)]
        _actors[uid] = actor
        return actor
    if actor.get_actor_label() != label:
        actor.set_actor_label(label)
    actor.set_actor_location_and_rotation(loc, rot, False, True)
    return actor


def _apply_body(uid, parent, label, asset):
    """El cuerpo de un foco o una cámara (el aparato, el rig): unido a él,
    se mueve con él. La luz y la cámara siguen siendo las de IRIS."""
    body_uid = uid + BODY
    if not asset:
        _remove([body_uid])
        return
    body = _place_asset(body_uid, label + " (cuerpo)", asset,
                        parent.get_actor_location(), parent.get_actor_rotation())
    if body is not None and body.get_attach_parent_actor() != parent:
        rule = unreal.AttachmentRule.KEEP_WORLD
        body.attach_to_actor(parent, "", rule, rule, rule, False)


def _apply_asset(a):
    """Otra pieza con asset (pared, actor, grip, rigging)."""
    uid = str(a["id"])
    _place_asset(uid, "IRIS_%s" % (a.get("name") or uid), a["asset"],
                 _vec(a["loc"]), _rot(a["rot"]))


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
    _apply_body(uid, actor, label, light.get("asset"))
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
    _apply_body(uid, actor, label, cam.get("asset"))
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
    # Diafragma, foco y exposición de la cámara de rodaje (F6.22.4).
    if cam.get("tStop"):
        _set(comp, "current_aperture", float(cam["tStop"]))
    if cam.get("focusCm"):
        try:
            fs = comp.get_editor_property("focus_settings")
            fs.set_editor_property("focus_method", unreal.CameraFocusMethod.MANUAL)
            fs.set_editor_property("manual_focus_distance", float(cam["focusCm"]))
            comp.set_editor_property("focus_settings", fs)
        except Exception as exc:
            unreal.log_warning("[IRIS Stage] foco: %s" % exc)
    if cam.get("iso") and cam.get("shutterS"):
        pp = comp.get_editor_property("post_process_settings")
        for name, value in [
            ("auto_exposure_method", unreal.AutoExposureMethod.AEM_MANUAL),
            ("auto_exposure_apply_physical_camera_exposure", True),
            ("camera_iso", float(cam["iso"])),
            ("camera_shutter_speed", 1.0 / max(float(cam["shutterS"]), 1e-4)),
            ("depth_of_field_fstop", float(cam.get("tStop") or 2.8)),
            ("auto_exposure_bias", -float(cam.get("nd") or 0)),
        ]:
            try:
                pp.set_editor_property("override_" + name, True)
                pp.set_editor_property(name, value)
            except Exception as exc:
                unreal.log_warning("[IRIS Stage] cámara %s: %s" % (name, exc))
        comp.set_editor_property("post_process_settings", pp)
        _set(comp, "post_process_blend_weight", 1.0)


def _apply_prop(p):
    uid = str(p["id"])
    label = "IRIS_%s" % (p.get("name") or uid)
    size = [float(v) for v in p.get("sizeCm", [50, 50, 80])]
    loc = _vec(p["loc"])
    if p.get("asset"):
        _lift[uid] = 0.0
        if _place_asset(uid, label, p["asset"], loc, _rot(p["rot"])) is not None:
            return
    # Bloque con las medidas de la pieza, apoyado en el suelo.
    mesh = unreal.EditorAssetLibrary.load_asset(CUBE)
    lift = size[2] / 2
    loc = unreal.Vector(loc.x, loc.y, loc.z + lift)
    old = _find(uid)
    if old is not None and _asset_of(old) is not None:
        # Antes tenía asset: el bloque es otro actor.
        _remove([uid])
    actor = _ensure(uid, unreal.StaticMeshActor, label, loc, _rot(p["rot"]))
    _lift[uid] = lift
    comp = actor.static_mesh_component
    if comp.static_mesh != mesh:
        comp.set_static_mesh(mesh)
    scale = unreal.Vector(size[0] / 100, size[1] / 100, size[2] / 100)
    now = actor.get_actor_scale3d()
    if max(abs(now.x - scale.x), abs(now.y - scale.y), abs(now.z - scale.z)) > 0.001:
        actor.set_actor_scale3d(scale)
    # El grip (F6.22.2) lleva el color de su tela: negro, rebote o difusión.
    if p.get("rgb") is not None:
        rgb = int(p["rgb"])
        comp.set_material(0, _ground_material("Grip_%06X" % rgb, rgb))


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


def _source_of(package):
    p = package.lower()
    if p.startswith("/game/fab/"):
        return "fab"
    if p.startswith("/game/megascans/") or p.startswith("/game/quixel/"):
        return "megascans"
    return "project"


def _find_assets(query, limit=40, sources=None):
    """Mallas, Blueprints y personajes del proyecto que contienen todas las
    palabras de [query] en su nombre o su carpeta. Con [sources], solo los
    de esos orígenes («fab», «megascans», «project»)."""
    registry = unreal.AssetRegistryHelpers.get_asset_registry()
    classes = {"StaticMesh": "mesh", "Blueprint": "blueprint", "SkeletalMesh": "skeletal"}
    flt = unreal.ARFilter(
        class_paths=[unreal.TopLevelAssetPath("/Script/Engine", c) for c in classes],
        package_paths=["/Game"], recursive_paths=True)
    words = [w for w in str(query or "").lower().split() if w]
    out = []
    for data in registry.get_assets(flt):
        package = str(data.package_name)
        if package.startswith(WORLD_ROOT + "/"):
            continue
        if sources and _source_of(package) not in sources:
            continue
        name = str(data.asset_name)
        hay = (package + " " + name).lower()
        if any(w not in hay for w in words):
            continue
        kind = classes.get(str(data.asset_class_path.asset_name), "mesh")
        if "/metahumans/" in package.lower() and kind == "blueprint":
            kind = "metahuman"
        size = None
        if kind == "mesh":
            mesh = unreal.EditorAssetLibrary.load_asset(package)
            if isinstance(mesh, unreal.StaticMesh):
                box = mesh.get_bounding_box()
                size = [_round(box.max.x - box.min.x), _round(box.max.y - box.min.y),
                        _round(box.max.z - box.min.z)]
        elif kind == "skeletal":
            mesh = unreal.EditorAssetLibrary.load_asset(package)
            if isinstance(mesh, unreal.SkeletalMesh):
                ext = mesh.get_bounds().box_extent
                size = [_round(ext.x * 2), _round(ext.y * 2), _round(ext.z * 2)]
        out.append({
            "path": "%s.%s" % (package, name),
            "name": name,
            "folder": package.rsplit("/", 1)[0],
            "kind": kind,
            "source": _source_of(package),
            "sizeCm": size,
        })
        if len(out) >= limit:
            break
    return out


# ── Miniaturas (F6.20 B3) ──────────────────────────────────────────────
# Unreal fotografía el asset (cenital con transparencia y 3/4) lejos del
# set, con luces propias y una cámara de captura que solo lo ve a él. IRIS
# guarda las fotos y las sube: son un render, no el modelo.
PREVIEW_AT = unreal.Vector(5000000.0, 5000000.0, 0.0)  # a 50 km del set
PREVIEW_PX = 512
TOP_MARGIN = 1.08


def _png_rgba(width, height, rgba):
    """Un PNG de 8 bits RGBA, sin depender de librerías de imagen."""
    stride = width * 4
    raw = b"".join(b"\x00" + bytes(rgba[y * stride:(y + 1) * stride]) for y in range(height))

    def chunk(kind, data):
        return (struct.pack(">I", len(data)) + kind + data
                + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))

    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 6))
            + chunk(b"IEND", b""))


def _shoot(world, target, loc, rot, ortho_width=None, fov=30.0):
    """Una foto de [target] solo, en HDR, con su opacidad: PNG con alfa."""
    rt = unreal.RenderingLibrary.create_render_target2d(
        world, PREVIEW_PX, PREVIEW_PX, unreal.TextureRenderTargetFormat.RTF_RGBA16F,
        unreal.LinearColor(0, 0, 0, 0), False)
    cap = _actor_subsystem().spawn_actor_from_class(unreal.SceneCapture2D, loc, rot)
    try:
        comp = cap.capture_component2d
        comp.set_editor_property("texture_target", rt)
        comp.set_editor_property("capture_source", unreal.SceneCaptureSource.SCS_SCENE_COLOR_HDR)
        comp.set_editor_property("primitive_render_mode",
                                 unreal.SceneCapturePrimitiveRenderMode.PRM_USE_SHOW_ONLY_LIST)
        comp.show_only_actor_components(target)
        comp.set_editor_property("capture_every_frame", False)
        comp.set_editor_property("capture_on_movement", False)
        if ortho_width is not None:
            comp.set_editor_property("projection_type", unreal.CameraProjectionMode.ORTHOGRAPHIC)
            comp.set_editor_property("ortho_width", float(ortho_width))
        else:
            comp.set_editor_property("fov_angle", float(fov))
        comp.capture_scene()
        pixels = unreal.RenderingLibrary.read_render_target_raw(world, rt)
    finally:
        _actor_subsystem().destroy_actor(cap)
    # En HDR, A es la opacidad al revés. El color se normaliza con lo más
    # claro de la pieza: la foto no depende de la exposición del set.
    lum = sorted(0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b for c in pixels if c.a < 0.5)
    peak = lum[int(len(lum) * 0.98)] if lum else 1.0
    gain = 0.85 / peak if peak > 1e-6 else 1.0
    out = bytearray(len(pixels) * 4)
    for i, c in enumerate(pixels):
        alpha = 1.0 - min(max(c.a, 0.0), 1.0)
        for k, v in enumerate((c.r, c.g, c.b)):
            v = min(max(v * gain, 0.0), 1.0) ** (1 / 2.2)
            out[i * 4 + k] = int(v * 255 + 0.5)
        out[i * 4 + 3] = int(alpha * 255 + 0.5)
    return _png_rgba(PREVIEW_PX, PREVIEW_PX, out)


def _asset_preview(path):
    obj = unreal.EditorAssetLibrary.load_asset(path)
    if obj is None:
        raise ValueError("No encuentro el asset %s." % path)
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    temp = []
    try:
        target = _actor_subsystem().spawn_actor_from_object(obj, PREVIEW_AT, unreal.Rotator())
        if target is None:
            raise ValueError("%s no se puede poner en el nivel." % path)
        temp.append(target)
        origin, extent = target.get_actor_bounds(False)
        off_x, off_y = origin.x - PREVIEW_AT.x, origin.y - PREVIEW_AT.y
        # La cenital, centrada en el punto de apoyo de la pieza: IRIS la
        # dibuja centrada en el elemento, girada con él.
        half = max(abs(off_x) + extent.x, abs(off_y) + extent.y, 1.0) * TOP_MARGIN
        radius = max(math.sqrt(extent.x ** 2 + extent.y ** 2 + extent.z ** 2), 1.0)
        # Luces propias (llave, relleno y contra), solo allí.
        for dx, dy, dz, power in ((1.2, -0.8, 1.4, 1.0), (-1.0, -1.2, 0.6, 0.45), (-0.6, 1.3, 1.1, 0.6)):
            light = _actor_subsystem().spawn_actor_from_class(
                unreal.PointLight,
                unreal.Vector(origin.x + dx * radius * 2, origin.y + dy * radius * 2,
                              origin.z + dz * radius * 2),
                unreal.Rotator())
            comp = light.get_component_by_class(unreal.PointLightComponent)
            comp.set_editor_property("intensity_units", unreal.LightUnits.CANDELAS)
            comp.set_editor_property("intensity", 2000.0 * power * (radius / 100.0) ** 2)
            comp.set_editor_property("attenuation_radius", radius * 8)
            temp.append(light)
        top = _shoot(world, target,
                     unreal.Vector(PREVIEW_AT.x, PREVIEW_AT.y, origin.z + extent.z + radius * 2),
                     unreal.Rotator(roll=0.0, pitch=-90.0, yaw=0.0), ortho_width=half * 2)
        eye = unreal.Vector(0.75, 0.6, 0.5)
        dist = radius / math.tan(math.radians(15)) * 1.15
        norm = math.sqrt(eye.x ** 2 + eye.y ** 2 + eye.z ** 2)
        at = unreal.Vector(origin.x + eye.x / norm * dist, origin.y + eye.y / norm * dist,
                           origin.z + eye.z / norm * dist)
        look = unreal.MathLibrary.find_look_at_rotation(at, origin)
        three = _shoot(world, target, at, look, fov=30.0)
        return {"top": base64.b64encode(top).decode("ascii"),
                "threeQuarter": base64.b64encode(three).decode("ascii"),
                "topSpanCm": _round(half * 2)}
    finally:
        for actor in temp:
            _actor_subsystem().destroy_actor(actor)


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


def _scan_meshes(file, folders, root=None):
    """Las mallas de un escaneo importado; si aún no está, se importa del
    archivo que tiene IRIS en este PC. Vacío si no se encuentra."""
    base = re.sub(r"[^0-9a-zA-Z_]", "_", os.path.splitext(os.path.basename(file))[0])
    dest = "%s/S_%s" % (root or SCAN_ROOT, base)
    lib = unreal.EditorAssetLibrary

    def meshes():
        if not lib.does_directory_exist(dest):
            return []
        out = []
        for path in lib.list_assets(dest, recursive=True, include_folder=False):
            data = lib.find_asset_data(path)
            if str(data.asset_class_path.asset_name) == "StaticMesh":
                out.append(str(data.package_name) + "." + str(data.asset_name))
        return sorted(out)

    found = meshes()
    if found:
        return found
    source = None
    for folder in folders or []:
        candidate = os.path.join(folder, os.path.basename(file))
        if os.path.isfile(candidate):
            source = candidate
            break
    if source is None:
        unreal.log_warning("[IRIS Stage] El escaneo %s no está en este PC." % file)
        return []
    task = unreal.AssetImportTask()
    task.filename = source
    task.destination_path = dest
    task.automated = True
    task.save = True
    task.replace_existing = True
    unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
    found = meshes()
    if not found:
        unreal.log_warning("[IRIS Stage] No se ha podido importar %s." % source)
    return found


def _apply_scan(s, folders):
    """Un escaneo de la planta: sus mallas en su sitio, giro y escala."""
    uid = str(s["id"])
    label = "IRIS_%s" % (s.get("name") or uid)
    loc, rot = _vec(s["loc"]), _rot(s["rot"])
    scale = float(s.get("scale") or 1.0)
    parts = _scan_meshes(s["file"], folders)
    for i, path in enumerate(parts):
        part_uid = uid if i == 0 else "%s%s%d" % (uid, PART, i)
        actor = _place_asset(part_uid, label if i == 0 else "%s (%d)" % (label, i),
                             path, loc, rot)
        if actor is not None:
            actor.set_actor_scale3d(unreal.Vector(scale, scale, scale))
    # Mallas que ya no tiene (otra importación del mismo escaneo).
    _remove([p for p in list(_actors)
             if p.startswith(uid + PART) and int(p[len(uid + PART):] or 0) >= max(len(parts), 1)])


def _apply_structure(s):
    """La estructura del set (F6.21.3): paredes con sus huecos, techos,
    cristales, telas, pilares y rigging, en un GLB que IRIS guarda en este
    PC. Cada pieza ya trae su sitio en la malla, así que todas van en el
    origen, sin giro ni escala. La de antes se quita."""
    parts = _scan_meshes(s["file"], [s.get("folder")], root=STRUCTURE_ROOT)
    if not parts:
        return
    _rescan()
    _remove([uid for uid in list(_actors)
             if uid == STRUCTURE_ID or uid.startswith(STRUCTURE_ID + PART)])
    origin, flat = unreal.Vector(0, 0, 0), unreal.Rotator(0, 0, 0)
    for i, path in enumerate(parts):
        uid = STRUCTURE_ID if i == 0 else "%s%s%d" % (STRUCTURE_ID, PART, i)
        _place_asset(uid, "IRIS_Estructura" if i == 0 else "IRIS_Estructura (%d)" % i,
                     path, origin, flat)


GROUND_ROOT = WORLD_ROOT + "/Materiales"
_BASIC_MAT = "/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial"


def _ground_material(name, rgb):
    """Un material liso del color [rgb] (0xRRGGBB) para el suelo, creado
    una vez como instancia del material básico de Unreal."""
    path = "%s/Suelo_%s" % (GROUND_ROOT, name)
    lib = unreal.EditorAssetLibrary
    if lib.does_asset_exist(path):
        return lib.load_asset(path)
    tools = unreal.AssetToolsHelpers.get_asset_tools()
    mic = tools.create_asset("Suelo_%s" % name, GROUND_ROOT,
                             unreal.MaterialInstanceConstant,
                             unreal.MaterialInstanceConstantFactoryNew())
    mic.set_editor_property("parent", lib.load_asset(_BASIC_MAT))
    color = unreal.LinearColor(((rgb >> 16) & 255) / 255.0, ((rgb >> 8) & 255) / 255.0,
                               (rgb & 255) / 255.0, 1.0)
    unreal.MaterialEditingLibrary.set_material_instance_vector_parameter_value(
        mic, "Color", color)
    lib.save_loaded_asset(mic)
    return mic


def _apply_environment(e):
    """Plató, interior o exterior (F6.21.1). En un plató solo alumbran los
    focos: sin sol, cielo ni atmósfera, y el suelo gris neutro. Fuera, el
    suelo del terreno, grande, con el cielo y el sol que mande IRIS."""
    kind = e.get("kind", "interior")
    floor = _find(FLOOR_ID)
    if kind == "studio":
        sun = _find(SUN_ID)
        if sun is not None:
            comp = sun.get_component_by_class(unreal.DirectionalLightComponent)
            if comp is not None:
                _set(comp, "intensity", 0.0)
        sky = _find(SKY_ID)
        if sky is not None:
            comp = sky.get_component_by_class(unreal.SkyLightComponent)
            if comp is not None:
                _set(comp, "intensity", 0.0)
        atmosphere = _find(ATMOSPHERE_ID)
        if atmosphere is not None:
            _actor_subsystem().destroy_actor(atmosphere)
            _actors.pop(ATMOSPHERE_ID, None)
    if floor is None:
        return
    comp = floor.static_mesh_component
    if kind == "studio":
        comp.set_material(0, _ground_material("Plato", 0x767676))
        floor.set_actor_scale3d(unreal.Vector(100, 100, 1))
    elif kind == "exterior":
        comp.set_material(0, _ground_material(
            str(e.get("ground", "grass")).capitalize(), int(e.get("groundRgb", 0x4f6b35))))
        # Hasta el horizonte: 2 km.
        floor.set_actor_scale3d(unreal.Vector(2000, 2000, 1))
    else:
        comp.set_material(0, _ground_material("Interior", 0x8a8378))
        floor.set_actor_scale3d(unreal.Vector(100, 100, 1))


# Por tipo de niebla: densidad a 100 %, caída con la altura (alta = pegada
# al suelo) y cuánto apaga la niebla volumétrica.
_FOG_KINDS = {
    "haze": (0.08, 0.2, 2.0),
    "smoke": (0.35, 1.5, 4.0),
    "exterior": (0.04, 0.05, 1.0),
}


def _apply_fog(fog):
    """Niebla o humo del esquema (F6.21.2): ExponentialHeightFog con niebla
    volumétrica, que hace visibles los haces de los focos. Sin niebla, se
    quita."""
    actor = _find(FOG_ID)
    pct = float((fog or {}).get("pct", 0)) / 100.0
    if pct <= 0:
        if actor is not None:
            _actor_subsystem().destroy_actor(actor)
            _actors.pop(FOG_ID, None)
        return
    density, falloff, extinction = _FOG_KINDS.get(fog.get("kind"), _FOG_KINDS["haze"])
    if actor is None:
        actor = _spawn(FOG_ID, unreal.ExponentialHeightFog, "IRIS_Niebla",
                       unreal.Vector(0, 0, 0), unreal.Rotator())
    comp = actor.get_component_by_class(unreal.ExponentialHeightFogComponent)
    if comp is None:
        return
    _set(comp, "fog_density", density * pct)
    _set(comp, "fog_height_falloff", falloff)
    _set(comp, "volumetric_fog", True)
    _set(comp, "volumetric_fog_extinction_scale", 1.0 + extinction * pct)
    # Hacia delante: los haces brillan al mirar hacia el foco, como en set.
    _set(comp, "volumetric_fog_scattering_distribution", 0.6)


def _apply_exposure(e):
    """Exposición fija con la cámara de IRIS (F6.21.4): manual y con la
    cámara física (ISO, obturador, diafragma), en un PostProcessVolume que
    vale para todo el nivel. Así la luz se ve como la mide IRIS, y bajar un
    foco al 50 % se ve la mitad."""
    vol = _ensure(POST_ID, unreal.PostProcessVolume, "IRIS_Exposicion",
                  unreal.Vector(0, 0, 0), unreal.Rotator(0, 0, 0))
    _set(vol, "unbound", True)
    s = vol.get_editor_property("settings")
    values = [
        ("auto_exposure_method", unreal.AutoExposureMethod.AEM_MANUAL),
        ("auto_exposure_apply_physical_camera_exposure", True),
        ("camera_iso", float(e.get("iso", 800))),
        ("camera_shutter_speed", 1.0 / max(float(e.get("shutterS", 1 / 48.0)), 1e-4)),
        ("depth_of_field_fstop", float(e.get("tStop", 2.8))),
        # El ND quita luz: compensación negativa.
        ("auto_exposure_bias", -float(e.get("nd", 0))),
        # Nada que cambie el nivel de la imagen por su cuenta.
        ("vignette_intensity", 0.0),
        ("bloom_intensity", 0.2),
        ("local_exposure_highlight_contrast_scale", 1.0),
        ("local_exposure_shadow_contrast_scale", 1.0),
    ]
    for name, value in values:
        try:
            s.set_editor_property("override_" + name, True)
            s.set_editor_property(name, value)
        except Exception as exc:
            unreal.log_warning("[IRIS Stage] exposición %s: %s" % (name, exc))
    vol.set_editor_property("settings", s)


def _remove(ids):
    ids = list(ids) + [str(uid) + BODY for uid in ids if not str(uid).endswith(BODY)]
    # Las otras mallas de un escaneo se van con él.
    ids += [p for p in list(_actors) for uid in list(ids)
            if PART not in str(uid) and p.startswith(str(uid) + PART)]
    for uid in ids:
        actor = _find(str(uid))
        if actor is not None:
            _actor_subsystem().destroy_actor(actor)
            _actors.pop(str(uid), None)


def _apply(data):
    lights = data.get("lights", [])
    cameras = data.get("cameras", [])
    props = data.get("props", [])
    assets = data.get("assets", [])
    scans = data.get("scans", [])
    if data.get("world"):
        _ensure_world(data["world"])
    if data.get("full"):
        # Escena entera: lo de IRIS que ya no está, fuera.
        _rescan()
        keep = ({str(x["id"]) for x in lights + cameras + props + assets + scans}
                | {str(x["id"]) + BODY for x in lights + cameras if x.get("asset")}
                | _FIXED)
        _remove([uid for uid in list(_actors)
                 if uid not in keep and uid.split(PART)[0] not in keep])
    _remove(data.get("remove", []))
    for light in lights:
        _apply_light(light)
    for cam in cameras:
        _apply_camera(cam)
    for p in props:
        _apply_prop(p)
    for a in assets:
        _apply_asset(a)
    for s in scans:
        _apply_scan(s, data.get("scanFolders", []))
    studio = (data.get("environment") or {}).get("kind") == "studio"
    if "sun" in data:
        _apply_sun(None if studio else data["sun"])
    if "sky" in data and not studio:
        _apply_sky(data["sky"])
    if data.get("environment"):
        _apply_environment(data["environment"])
    if "fog" in data:
        _apply_fog(data["fog"])
    if data.get("exposure"):
        _apply_exposure(data["exposure"])
    if data.get("structure"):
        _apply_structure(data["structure"])
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

    @unreal.ufunction(static=True, params=[str], ret=str,
                      meta=dict(Category="IRIS Stage"))
    def FindFabAssets(query):
        try:
            return json.dumps({"ok": True, "assets": _find_assets(
                query, limit=300, sources=("fab", "megascans"))})
        except Exception as exc:
            return json.dumps({"ok": False, "error": str(exc)})

    @unreal.ufunction(static=True, params=[str], ret=str,
                      meta=dict(Category="IRIS Stage"))
    def AssetPreview(path):
        try:
            result = _asset_preview(path)
            result["ok"] = True
            return json.dumps(result)
        except Exception as exc:
            unreal.log_error("[IRIS Stage] AssetPreview: %s" % exc)
            return json.dumps({"ok": False, "error": str(exc)})

    @unreal.ufunction(static=True, ret=str, meta=dict(Category="IRIS Stage"))
    def Snapshot():
        try:
            return json.dumps({"ok": True, "actors": _snapshot()})
        except Exception as exc:
            return json.dumps({"ok": False, "error": str(exc)})


unreal.log("[IRIS Stage] Link v%d listo en %s: IRIS puede conectar por Remote Control."
           % (VERSION, unreal.get_default_object(IrisStageLink).get_path_name()))
