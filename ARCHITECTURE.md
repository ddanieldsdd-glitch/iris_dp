# IRIS DP — ARCHITECTURE

Esta es la guía arquitectónica oficial para IRIS DP. Todo desarrollo y modificación por parte de agentes de IA debe respetar estrictamente estas reglas.

## 1. Objetivo arquitectónico

IRIS DP está migrando hacia una arquitectura sencilla de tres niveles:

```text
UI
 ↓
State / ViewModel
 ↓
Repository
 ↓
Data sources
```

Los data sources pueden ser:
* Drift / DAO
* Supabase
* File system
* Servicios externos

**NO se debe** convertir la aplicación en una implementación académica de Clean Architecture. 
NO crear carpetas innecesarias como `domain/`, `entities/`, `use_cases/`, `interactors/`, `dto/`, `mappers/` por defecto. Solo crear capas adicionales cuando exista una necesidad real.

---

## 2. Reglas de dependencia

**Regla 1**: `core/` NO puede importar `features/`.
* `core → features` está **PROHIBIDO**.
* Lo correcto es: `features → core` o `features → shared`.

**Regla 2**: Una feature no debe importar directamente otra feature, salvo que exista una dependencia de dominio explícita y justificada. Evitar ciclos.
* Si dos features necesitan el mismo componente: usar `shared`.

**Regla 3**: Los `Screen` y `Widget` no deben acceder directamente a `AppDatabase`.
La dirección correcta es: `Screen -> Notifier / State -> Repository -> DAO / AppDatabase`.

**Regla 4**: La UI nunca debe acceder directamente a Supabase, Drift o AppDatabase. Debe trabajar con abstracciones de estado y dominio.

**Regla 5**: `core/sync` no debe depender de `BuildContext` ni mostrar UI directamente. Debe devolver resultados y delegar a la UI el pintado de dialogs, banners, etc.

---

## 3. Core

`core/` contiene infraestructura transversal.
Ejemplos: `core/database`, `core/cloud`, `core/sync`, `core/storage`, `core/theme`, `core/update`, `core/utils`, `core/widgets`.
**Regla**: Si un componente conoce conceptos específicos de una feature, **no** pertenece a `core`.

---

## 4. Shared

`shared/` contendrá componentes que:
* Conocen conceptos de dominio.
* Son utilizados por **múltiples** features.
Ejemplos: `shared/widgets`, `shared/pdf_export`, `shared/look_bible`.
**No** mover automáticamente código a `shared` a menos que sea compartido por varias features.

---

## 5. Estructura recomendada para nuevas features

Progresivamente adoptaremos:
```text
features/
└── nombre_feature/
    ├── data/
    │   └── nombre_feature_repository.dart
    ├── state/
    │   └── nombre_feature_notifier.dart
    └── ui/
        ├── nombre_feature_screen.dart
        └── widgets/
```
**NO** aplicar esta estructura masivamente todavía. Se hará de forma progresiva.

---

## 6. Repository

El Repository es la puerta de entrada de una feature a los datos.
* La UI nunca debe escribir queries Drift directamente.
* Los métodos del Repository deben hablar en términos del dominio (ej: `getScenesForProject(projectId)` y NO `select(scenes)..where(...)`).

---

## 7. Riverpod

IRIS DP ya utiliza Riverpod. No introducir otro framework de gestión de estado.
Se usa para:
* Dependency injection
* Notifiers / AsyncNotifiers
* Estado de pantallas con lógica
**Ojo**: `setState` sigue siendo válido para estado puramente visual (menús, hover, animaciones). No convertir ciegamente todos los `setState` en Riverpod.

---

## 8. UI

La UI se encarga de:
* Composición visual
* Interacción
* Presentación del estado
* Delegación de acciones
**No** mezclar en un Screen: queries, lógica de sincronización, parsing complejo, reglas de negocio y cientos de widgets. Separar responsabilidades si crece mucho.

---

## 9. Stitch y futura reconstrucción de UI

IRIS DP tiene diseños avanzados realizados en Stitch. Estos diseños **NO** deben implementarse como mockups desconectados.
* Cada componente visual debe conectarse a funcionalidad real y persistente de la app.
* La futura UI debe ser visual + funcional + persistente (no visual + mock).

---

## 10. Principio fundamental para agentes de IA

Antes de modificar código:
1. Leer la feature afectada.
2. Identificar dependencias.
3. Identificar quién utiliza el código.
4. Determinar si el cambio afecta persistencia, sincronización o UI.
5. Hacer el **cambio mínimo necesario**.
6. Ejecutar análisis/tests.
7. Revisar `git diff`.
8. Solo entonces continuar.
**Nunca** hacer una refactorización masiva de golpe.

---

## 11. Migración progresiva

Orden previsto de fases (cada fase se abordará individualmente):
1. FASE 0 - Limpieza
2. FASE 1 - Documentación arquitectónica
3. FASE 2 - Romper core → features
4. FASE 3 - Separar SyncEngine de UI
5. FASE 4 - Romper ciclos entre features
6. FASE 5 - Repository piloto
7. FASE 6 - Repository resto de features
8. FASE 7 - DAOs
9. FASE 8 - Notifier / estado
10. FASE 9 - Router
11. FASE 10 - Shared
12. FASE 11 - Lint arquitectónico

---

## 12. Reglas especiales

* **Visual Bible**: No modificar su UI todavía. La arquitectura futura debe permitir que consuma de Drift y otras fuentes (media services, referencias externas) sin acoplarlas directamente a la UI.
* **Supabase**: Ya está aislado en `core/cloud` y `core/sync`. No importar `supabase_flutter` en nuevas features para lógica de aplicación.
* **Seguridad**: NUNCA incluir claves, credenciales, tokens o el contenido de `.env` en código, commits o prompts. `.env` debe permanecer ignorado en Git.

---

La prioridad de IRIS DP es:
**estabilidad → mantenibilidad → funcionalidad → escalabilidad → UI**
La UI debe ser la expresión visual de una arquitectura funcional.
