"""
iris_dp_import.py — IRIS DP Bridge para Unreal Engine 5
========================================================
Importa la planta de cámara de IRIS DP en un entorno UE5 con:
  - Gaussian Splat de la localización real (via Luma AI plugin)
  - Cámaras CineCamera con focal real
  - MetaHumans o marcadores para actores (por nombre del guion)
  - ARRI Virtual Fixtures (via LUKA plugin) o PointLights de fallback
  - Secuencia de render automática por plano

REQUISITOS:
  - Unreal Engine 5.3+
  - Plugin Luma AI activado (Fab/Marketplace, gratuito)
  - Plugin ARRI LUKA activado (Windows 64-bit, 3 meses gratuito)
  - Python Editor Script Plugin activado (Edit → Plugins → Python)
  - El Gaussian Splat de la localización ya importado en el Level

USO:
  1. Ajusta JSON_PATH a la ruta del JSON exportado por IRIS DP.
  2. Ajusta GAUSSIAN_SPLAT_ACTOR_LABEL al nombre del actor de GS en el Level.
  3. Ve a Tools → Execute Python Script → selecciona este archivo.

  Soporta export_type "scene" (una escena) o "project" (todas las escenas).
  Para proyectos completos, usa SCENE_INDEX para elegir qué escena importar.
"""

import json
import os

import unreal

# ── CONFIGURACIÓN ──────────────────────────────────────────────────────────────
JSON_PATH = "C:/Users/TuUsuario/Documents/iris_dp_escena.json"
GAUSSIAN_SPLAT_ACTOR_LABEL = "LumaGaussianSplat"
LUKA_FIXTURES_PATH = "/Game/ARRI_LUKA/Fixtures/"
METAHUMAN_PATH = "/Game/MetaHumans/Common/Male/Medium/NormalWeight/Body/"
OUTPUT_DIR = "C:/Users/TuUsuario/Documents/IrisDP_Renders/"
# Índice de escena cuando export_type == "project" (0 = primera escena)
SCENE_INDEX = 0
# ──────────────────────────────────────────────────────────────────────────────


def load_json():
    with open(JSON_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def resolve_scene_payload(data):
    """Devuelve el bloque de escena a importar (scene o project export)."""
    export_type = data.get("export_type", "scene")
    if export_type == "project":
        scenes = data.get("scenes", [])
        if not scenes:
            raise ValueError("JSON de proyecto sin escenas")
        if SCENE_INDEX < 0 or SCENE_INDEX >= len(scenes):
            raise IndexError(
                f"SCENE_INDEX {SCENE_INDEX} fuera de rango "
                f"(0..{len(scenes) - 1})"
            )
        return scenes[SCENE_INDEX]
    return data


def apply_gaussian_splat_orientation(data):
    """Aplica corrección de orientación al actor GS si está configurado."""
    fix = data.get("meta", {}).get("gaussian_splat_orientation_fix")
    if not fix:
        return

    actors = unreal.EditorLevelLibrary.get_all_level_actors()
    gs_actor = None
    for actor in actors:
        if actor.get_actor_label() == GAUSSIAN_SPLAT_ACTOR_LABEL:
            gs_actor = actor
            break

    if not gs_actor:
        unreal.log_warning(
            f"[IRIS DP] Actor GS '{GAUSSIAN_SPLAT_ACTOR_LABEL}' no encontrado."
        )
        return

    rot = fix.get("rotation", [-90, 0, 0])
    gs_actor.set_actor_rotation(unreal.Rotator(rot[0], rot[1], rot[2]), False)

    scale_z = fix.get("scale_z")
    if scale_z is not None:
        scale = gs_actor.get_actor_scale3d()
        gs_actor.set_actor_scale3d(unreal.Vector(scale.x, scale.y, scale_z))

    unreal.log("[IRIS DP] ✓ Orientación Gaussian Splat aplicada")


def v(x, y, z):
    return unreal.Vector(x, y, z)


def r(p, y, ro):
    return unreal.Rotator(p, y, ro)


def shot_prefix(data):
    shot = data.get("shot_number")
    return f"P{shot:02d}_" if shot is not None else ""


def create_camera_path_spline(cam_data):
    """Crea un spline con la trayectoria de cámara (posición + path_points)."""
    path_points = cam_data.get("path_points", [])
    if not path_points:
        return None

    start = cam_data["position"]
    points = [start] + [p["position"] for p in path_points]
    if len(points) < 2:
        return None

    label = cam_data.get("label", "Cam")
    prefix = shot_prefix(cam_data)

    origin = v(start["x"], start["y"], start["z"])
    actor = unreal.EditorLevelLibrary.spawn_actor_from_class(
        unreal.Actor, origin, r(0, 0, 0)
    )
    actor.set_actor_label(f"CamPath_{prefix}{label}")

    try:
        spline = actor.add_component_by_class(
            unreal.SplineComponent,
            manual_attachment=False,
            relative_location=unreal.Vector(0, 0, 0),
            relative_rotation=unreal.Rotator(0, 0, 0),
        )
        spline.clear_spline_points()
        for pt in points:
            spline.add_spline_point(
                v(pt["x"], pt["y"], pt["z"]),
                unreal.SplineCoordinateSpace.WORLD,
                update_spline=False,
            )
        spline.update_spline()
        spline.set_editor_property("draw_debug", True)
        unreal.log(
            f"[IRIS DP] ✓ Spline CamPath_{prefix}{label} — {len(points)} puntos"
        )
        return actor
    except Exception as exc:
        unreal.log_warning(
            f"[IRIS DP] Spline falló para {label}: {exc}. Usando marcadores."
        )
        unreal.EditorLevelLibrary.destroy_actor(actor)
        return None


def place_cine_camera(cam_data):
    """Coloca una CineCameraActor con focal, T-stop y trayectoria del plano."""
    pos = v(
        cam_data["position"]["x"],
        cam_data["position"]["y"],
        cam_data["position"]["z"],
    )
    rot = r(0, cam_data.get("rotation_y", 0), 0)

    actor = unreal.EditorLevelLibrary.spawn_actor_from_class(
        unreal.CineCameraActor, pos, rot
    )
    label = cam_data.get("label", "Cam")
    prefix = shot_prefix(cam_data)
    actor.set_actor_label(f"Cam_{prefix}{label}")

    cam_comp = actor.get_cine_camera_component()
    cam_comp.set_editor_property(
        "current_focal_length", float(cam_data.get("lens_mm", 50))
    )
    cam_comp.set_editor_property(
        "current_aperture", float(cam_data.get("t_stop", 2.8))
    )

    filmback = unreal.CameraFilmbackSettings()
    sensor_w = cam_data.get("sensor_width_mm")
    sensor_h = cam_data.get("sensor_height_mm")
    filmback.sensor_width = float(sensor_w) if sensor_w else 27.99
    filmback.sensor_height = float(sensor_h) if sensor_h else 11.70
    cam_comp.filmback = filmback

    path_points = cam_data.get("path_points", [])
    movement = cam_data.get("movement", "STEADY")
    movement_kind = cam_data.get("movement_kind", "static")
    path_len = cam_data.get("path_length_m", 0)
    path_count = cam_data.get("path_point_count", len(path_points))

    spline = create_camera_path_spline(cam_data)

    if spline is None:
        for pt in path_points:
            marker = unreal.EditorLevelLibrary.spawn_actor_from_class(
                unreal.PointLight,
                v(
                    pt["position"]["x"],
                    pt["position"]["y"],
                    pt["position"]["z"],
                ),
                r(0, 0, 0),
            )
            marker.set_actor_label(
                f"Path_{prefix}{label}_{pt.get('index', 0)}"
            )
            marker.set_actor_scale3d(v(0.05, 0.05, 0.05))

    unreal.log(
        f"[IRIS DP] ✓ Cámara {prefix}{label} — "
        f"{cam_data.get('lens_mm')}mm T{cam_data.get('t_stop')} — "
        f"mov: {movement} ({movement_kind}) — "
        f"trayectoria: {path_count} pts / {path_len:.1f}m"
    )
    return actor


def place_luka_light(light_data):
    """Coloca un ARRI Virtual Fixture o luz Unreal de fallback."""
    pos = v(
        light_data["position"]["x"],
        light_data["position"]["y"],
        light_data["position"]["z"],
    )
    rot = r(0, light_data.get("rotation_y", 0), 0)
    label = light_data.get("label", "Luz")
    prefix = shot_prefix(light_data)
    luka_id = light_data.get("luka_fixture_id")

    loc = light_data.get("location", {})
    set_name = loc.get("set_name", "")

    if luka_id and light_data.get("luka_compatible", False):
        asset_path = f"{LUKA_FIXTURES_PATH}{luka_id}.{luka_id}"
        asset = unreal.EditorAssetLibrary.load_asset(asset_path)
        if asset:
            actor = unreal.EditorLevelLibrary.spawn_actor_from_object(
                asset, pos, rot
            )
            actor.set_actor_label(f"LUKA_{prefix}{label}")
            unreal.log(
                f"[IRIS DP] ✓ ARRI LUKA '{luka_id}' — {prefix}{label} "
                f"@ {set_name or loc.get('slugline', '')}"
            )
            return actor
        unreal.log_warning(
            f"[IRIS DP] Fixture LUKA '{luka_id}' no encontrado. Usando fallback."
        )

    light_type = light_data.get(
        "unreal_light_type",
        light_data.get(
            "light_type",
            light_data.get("iris_light_type", "led_panel"),
        ),
    )
    actor_class = {
        "fresnel": unreal.SpotLight,
        "hmi": unreal.SpotLight,
        "led_panel": unreal.RectLight,
        "softbox": unreal.RectLight,
        "chimera": unreal.RectLight,
        "practical": unreal.PointLight,
        "bounce": unreal.RectLight,
    }.get(light_type, unreal.PointLight)

    actor = unreal.EditorLevelLibrary.spawn_actor_from_class(
        actor_class, pos, rot
    )
    actor.set_actor_label(f"Light_{prefix}{label}")

    intensity = float(light_data.get("intensity", 1.0)) * 8000
    color_temp = float(light_data.get("color_temp_k", 5600.0))
    light_comp = actor.get_component_by_class(unreal.LightComponent)
    if light_comp:
        light_comp.set_editor_property("intensity", intensity)
        light_comp.set_editor_property("use_temperature", True)
        light_comp.set_editor_property("temperature", color_temp)

    iris_type = light_data.get("light_type_label", light_type)
    unreal.log(
        f"[IRIS DP] ✓ Luz {prefix}{label} ({iris_type}) — fallback Unreal"
    )
    return actor


def place_actor(actor_data):
    """Coloca un MetaHuman o placeholder con el nombre del actor."""
    pos = v(
        actor_data["position"]["x"],
        actor_data["position"]["y"],
        actor_data["position"]["z"],
    )
    rot = r(0, actor_data.get("rotation_y", 0), 0)
    name = actor_data.get("name", "Actor")
    source = actor_data.get("source", "camera_plan")

    mh_asset_path = f"{METAHUMAN_PATH}BP_Male_Medium_NormalWeight_Body"
    mh_asset = unreal.EditorAssetLibrary.load_asset(mh_asset_path)

    if mh_asset:
        actor = unreal.EditorLevelLibrary.spawn_actor_from_object(
            mh_asset, pos, rot
        )
    else:
        actor = unreal.EditorLevelLibrary.spawn_actor_from_class(
            unreal.StaticMeshActor, pos, rot
        )

    actor.set_actor_label(f"Actor_{name}")
    unreal.log(f"[IRIS DP] ✓ Actor '{name}' — fuente: {source}")
    return actor


def create_level_sequence(scene_data, cameras):
    """Crea un LevelSequence con un binding por cámara."""
    sequence_name = f"IrisDP_{scene_data['scene']['name'].replace(' ', '_')}"

    seq = unreal.AssetToolsHelpers.get_asset_tools().create_asset(
        sequence_name,
        "/Game/IrisDP",
        unreal.LevelSequence,
        unreal.LevelSequenceFactoryNew(),
    )
    if not seq:
        unreal.log_warning("[IRIS DP] No se pudo crear el LevelSequence.")
        return None

    seq.set_editor_property("display_rate", unreal.FrameRate(24, 1))

    for cam_actor in cameras:
        seq.add_possessable(cam_actor)
        unreal.log(
            f"[IRIS DP] Añadido {cam_actor.get_actor_label()} a la secuencia"
        )

    unreal.log(f"[IRIS DP] ✓ Secuencia creada: /Game/IrisDP/{sequence_name}")
    return seq


def place_prop(prop_data):
    """Coloca un prop o elemento de arquitectura como StaticMeshActor."""
    pos = v(
        prop_data["position"]["x"],
        prop_data["position"]["y"],
        prop_data["position"]["z"],
    )
    rot = r(0, prop_data.get("rotation_y", 0), 0)
    label = prop_data.get("label", "Prop")
    prefix = shot_prefix(prop_data)
    mesh_path = prop_data.get(
        "unreal_mesh_path",
        "/Engine/BasicShapes/Cube",
    )

    actor = unreal.EditorLevelLibrary.spawn_actor_from_class(
        unreal.StaticMeshActor, pos, rot
    )
    actor.set_actor_label(f"Prop_{prefix}{label}")

    mesh = unreal.EditorAssetLibrary.load_asset(mesh_path)
    if mesh:
        actor.static_mesh_component.set_static_mesh(mesh)

    ct_type = prop_data.get("cinetracer_type", prop_data.get("type", "prop"))
    unreal.log(
        f"[IRIS DP] ✓ Prop '{label}' ({ct_type}) — mesh: {mesh_path}"
    )
    return actor


def import_floor_plan_elements(elements, label_prefix=""):
    """Importa cámaras/luces/props de un bloque elements."""
    cameras = []
    lights = []
    props = []
    if not elements:
        return cameras, lights, props

    unreal.log(f"[IRIS DP] Plano base {label_prefix}:")
    for cam in elements.get("cameras", []):
        actor = place_cine_camera(cam)
        if actor:
            cameras.append(actor)
    for light in elements.get("lights", []):
        actor = place_luka_light(light)
        if actor:
            lights.append(actor)
    for actor_data in elements.get("actors", []):
        place_actor(actor_data)
    for prop in elements.get("props", []):
        actor = place_prop(prop)
        if actor:
            props.append(actor)
    return cameras, lights, props


def import_floor_plan_rigging(scene_data):
    """Importa luces/cámaras/props del plano base del set y site."""
    plan = scene_data.get("camera_plan", {})
    placed_cameras = []
    placed_lights = []
    placed_props = []

    set_plan = plan.get("set_floor_plan", {})
    set_elements = set_plan.get("elements", {})
    cams, lights, props = import_floor_plan_elements(set_elements, "set")
    placed_cameras.extend(cams)
    placed_lights.extend(lights)
    placed_props.extend(props)

    site_plan = plan.get("site_floor_plan", {})
    site_elements = site_plan.get("elements", {})
    cams, lights, props = import_floor_plan_elements(site_elements, "site")
    placed_cameras.extend(cams)
    placed_lights.extend(lights)
    placed_props.extend(props)

    return placed_cameras, placed_lights, placed_props


def import_scene_block(scene_data):
    """Importa planta de cámara completa: focos, cámaras, movimiento y actores."""
    scene_name = scene_data["scene"]["name"]
    placed_cameras = []
    placed_lights = []
    placed_actors = []
    placed_props = []

    unreal.log(f"\n[IRIS DP] ── Escena: {scene_name} ──")

    camera_plan = scene_data.get("camera_plan")
    if camera_plan:
        loc = camera_plan.get("location", {})
        unreal.log(
            f"[IRIS DP] Planta v{camera_plan.get('version', 1)} — "
            f"{loc.get('slugline', '')} / set: {loc.get('set_name', '—')}"
        )

        rig_cams, rig_lights, rig_props = import_floor_plan_rigging(scene_data)
        placed_cameras.extend(rig_cams)
        placed_lights.extend(rig_lights)

        for shot_block in camera_plan.get("shots", []):
            shot_num = shot_block.get("shot_number")
            source = shot_block.get("plan_source", "shot")
            counts = shot_block.get("counts", {})
            unreal.log(
                f"[IRIS DP] Plano {shot_num} ({source}): "
                f"{counts.get('cameras', 0)} cam · "
                f"{counts.get('lights', 0)} luces · "
                f"{counts.get('actors', 0)} actores · "
                f"{counts.get('props', 0)} props"
            )
            elements = shot_block.get("elements", {})
            for cam in elements.get("cameras", []):
                actor = place_cine_camera(cam)
                if actor:
                    placed_cameras.append(actor)
            for light in elements.get("lights", []):
                actor = place_luka_light(light)
                if actor:
                    placed_lights.append(actor)
            for actor_data in elements.get("actors", []):
                actor = place_actor(actor_data)
                if actor:
                    placed_actors.append(actor)
            for prop in elements.get("props", []):
                actor = place_prop(prop)
                if actor:
                    placed_props.append(actor)
    else:
        for cam in scene_data.get("cameras", []):
            actor = place_cine_camera(cam)
            if actor:
                placed_cameras.append(actor)

        for light in scene_data.get("lights", []):
            actor = place_luka_light(light)
            if actor:
                placed_lights.append(actor)

        for actor_data in scene_data.get("actors", []):
            actor = place_actor(actor_data)
            if actor:
                placed_actors.append(actor)

    if placed_cameras:
        create_level_sequence(scene_data, placed_cameras)

    render_seq = scene_data.get("render_sequence", [])
    if render_seq:
        unreal.log(f"[IRIS DP] Render sequence: {len(render_seq)} planos")
        for item in render_seq:
            cam_label = item.get("camera_label", "—")
            movement = item.get("movement_kind", item.get("movement", ""))
            unreal.log(
                f"  → P{item.get('shot_number')} {cam_label} "
                f"{item.get('output_filename')} "
                f"({item.get('lens_mm')}mm T{item.get('t_stop')}) "
                f"mov:{movement} path:{item.get('path_point_count', 0)}"
            )

    return placed_cameras, placed_lights, placed_actors, placed_props


def main():
    if not os.path.exists(JSON_PATH):
        unreal.log_error(f"[IRIS DP] Archivo no encontrado: {JSON_PATH}")
        return

    root = load_json()
    project_name = root["project"]["name"]
    export_type = root.get("export_type", "scene")

    unreal.log("\n[IRIS DP] ═══════════════════════════════════════")
    unreal.log(f"[IRIS DP] Proyecto: {project_name} ({export_type})")

    if export_type == "project":
        scenes = root.get("scenes", [])
        unreal.log(f"[IRIS DP] {len(scenes)} escenas en el JSON")
        unreal.log(f"[IRIS DP] Importando escena índice {SCENE_INDEX}")
        scene_data = resolve_scene_payload(root)
    else:
        scene_data = root

    scene_name = scene_data["scene"]["name"]
    plan = scene_data.get("camera_plan", {})
    plan_shots = len(plan.get("shots", [])) if plan else 0
    unreal.log(f"[IRIS DP] Escena activa: {scene_name}")
    unreal.log(
        f"[IRIS DP] {len(scene_data.get('cameras', []))} cámaras | "
        f"{len(scene_data.get('lights', []))} luces | "
        f"{len(scene_data.get('actors', []))} actores | "
        f"{len(scene_data.get('shots', []))} planos | "
        f"camera_plan: {plan_shots} bloques"
    )

    locations = root.get("locations", [])
    if locations:
        unreal.log(f"[IRIS DP] Catálogo: {len(locations)} localizaciones/sets")

    gs = scene_data.get("location", {}).get("gaussian_splat", {})
    if gs.get("model_glb_fallback"):
        unreal.log(
            f"[IRIS DP] GLB fallback: {gs['model_glb_fallback']}"
        )

    unreal.log("[IRIS DP] ═══════════════════════════════════════\n")

    apply_gaussian_splat_orientation(root)

    cameras, lights, actors, props = import_scene_block(scene_data)

    unreal.log("\n[IRIS DP] ✓ Importación completa:")
    unreal.log(f"  → {len(cameras)} cámaras CineCamera")
    unreal.log(f"  → {len(lights)} luces (LUKA + fallback)")
    unreal.log(f"  → {len(actors)} actores")
    unreal.log(f"  → {len(props)} props / arquitectura")
    unreal.log("\n[IRIS DP] Próximos pasos:")
    unreal.log("  1. Verifica el Gaussian Splat en el Level.")
    unreal.log("  2. Ajusta fixtures ARRI LUKA (Windows).")
    unreal.log("  3. Play Mode: opera la cámara en primera persona.")
    unreal.log("  4. Movie Render Queue → frames PNG.")
    unreal.log(
        "  5. Importa renders en IRIS DP (iris_dp_s{sceneId}_p{shot}.png)."
    )


if __name__ == "__main__":
    main()
