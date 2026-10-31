"""Carga iris_stage_link.py fuera de Unreal, con un módulo `unreal` de
mentira, para pillar fallos al importarlo (un nombre usado antes de
definirlo, una errata): en Unreal, un fallo así deja a IRIS sin «IRIS Stage
Link» y no lo dice en ningún sitio que se vea.

Uso: python check_import.py <ruta a iris_stage_link.py>
"""

import importlib.util
import sys
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
print("OK")
