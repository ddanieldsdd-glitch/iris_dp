"""Carga iris_stage_link.py fuera de Unreal, con un módulo `unreal` de
mentira, para pillar fallos al importarlo (un nombre usado antes de
definirlo, una errata): en Unreal, un fallo así deja a IRIS sin «IRIS Stage
Link» y no lo dice en ningún sitio que se vea.

Uso: python check_import.py <ruta a iris_stage_link.py> [paquete.irisstage]

Con un paquete, comprueba además que se abre y que sus archivos están donde
la escena dice.
"""

import importlib.util
import os
import sys
import tempfile
import types


class _Any:
    """Cualquier cosa de `unreal`: se puede llamar, leer y usar de
    decorador."""

    def __init__(self, name="unreal"):
        self._name = name

    def __getattr__(self, name):
        return _Any(self._name + "." + name)

    def __call__(self, *args, **kwargs):
        # Como decorador (@unreal.uclass(), @unreal.ufunction(...)), devuelve
        # lo decorado tal cual.
        if (self._name.endswith("()") and len(args) == 1 and not kwargs
                and (callable(args[0]) or isinstance(args[0], type))):
            return args[0]
        return _Any(self._name + "()")


class _Unreal(types.ModuleType):
    BlueprintFunctionLibrary = object

    def __getattr__(self, name):
        return _Any("unreal." + name)


sys.modules["unreal"] = _Unreal("unreal")
path = sys.argv[1]
spec = importlib.util.spec_from_file_location("iris_stage_link", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
assert hasattr(module, "IrisStageLink"), "falta la clase IrisStageLink"

# AM.U2: un asset encaja en las medidas de su pieza. Una puerta de 2 × 0,1 ×
# 2,2 m en un hueco de 0,9 × 2,1 m: se estrecha, no cambia de fondo y queda
# apoyada en el suelo.
turn, scale, centre = module._fit_plan((200, 10, 220), (0, 0, 110), (90, 0, 210))
assert not turn and abs(scale[0] - 0.45) < 1e-9 and scale[1] == 1
assert abs(scale[2] - 210 / 220) < 1e-9 and abs(centre[2]) < 1e-9
# Tumbada al revés (lo ancho de lado): se gira en vez de deformarla.
turn, scale, centre = module._fit_plan((10, 100, 200), (0, 5, 100), (90, 12, 200))
assert turn and abs(scale[0] - 1.2) < 1e-9 and abs(scale[1] - 0.9) < 1e-9
assert abs(centre[0] + 4.5) < 1e-9 and abs(centre[1]) < 1e-9
# Un material vinculado vale para su ranura, aunque el importador le
# añada algo al nombre; el id más largo gana.
module._material_links = {"brick": "/Game/A.A", "brick-old": "/Game/B.B"}
assert module._slot_link("IRIS_brick-old") == "/Game/B.B"
assert module._slot_link("IRIS_brick_old_1") == "/Game/B.B"
assert module._slot_link("IRIS_brick") == "/Game/A.A"
assert module._slot_link("IRIS_plaster") is None
if len(sys.argv) > 2:
    with tempfile.TemporaryDirectory() as dest:
        data = module.read_package(sys.argv[2], dest)
        assert data["full"] is True, "el paquete debe ser la escena entera"
        structure = data.get("structure")
        if structure:
            assert os.path.isfile(os.path.join(structure["folder"], structure["file"]))
        for scan in data.get("scans", []):
            name = os.path.basename(scan["file"])
            assert os.path.isfile(os.path.join(data["scanFolders"][0], name)), name
print("OK")
