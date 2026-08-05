# IRIS DP en iPad — SideStore (gratis)

Guía paso a paso para instalar y actualizar IRIS DP en iPad sin pagar Apple Developer.

---

## Resumen

| Qué | Cómo |
|-----|------|
| Generar `.ipa` en Mac | `./scripts/build_ipad.sh` |
| Generar todo (Mac+Win+iPad) | `./scripts/release.sh 1.0.6` → GitHub Actions |
| Instalar en iPad | SideStore + `.ipa` |
| Actualizar | Descargar IPA nuevo → SideStore |
| Datos / proyectos | Misma cuenta Supabase + sync |

---

## Parte 1 — SideStore (solo la primera vez)

### En el Mac

1. Abre **https://sidestore.io**
2. Descarga **SideServer** (Mac) e instálalo
3. Descarga el archivo **SideStore.ipa** (lo usarás en el iPad)

### En el iPad

1. Conecta el iPad al Mac por **USB**
2. Abre **SideServer** en el Mac y sigue el asistente de emparejamiento
3. En el iPad, instala **SideStore** (desde SideServer o AltStore/SideStore según la guía actual de sidestore.io)
4. Abre **SideStore** y comprueba que aparece emparejado con el Mac

> SideStore debe refrescar la firma cada **~7 días** en Wi‑Fi. IRIS DP te avisará a los 5 días.

---

## Parte 2 — Instalar IRIS DP

### Opción A — Desde GitHub Release (recomendado tras `./scripts/release.sh`)

1. En el Mac, espera a que GitHub Actions termine
2. Abre el Release en GitHub → descarga **IRIS-DP.ipa**
3. **AirDrop** al iPad (o guárdalo en Archivos)
4. En el iPad: **Compartir → SideStore** (o ábrelo desde SideStore)

### Opción B — Build local en tu Mac (ahora mismo, sin esperar CI)

```bash
cd "/Users/danieldiaz/Documents/IRIS DP/iris_dp"
./scripts/build_ipad.sh
```

El IPA queda en:
```
build/ios/ipa/IRIS-DP.ipa
```

Pásalo al iPad (AirDrop) → abrir con **SideStore**.

### Opción C — Desde la app en otro dispositivo

Si ya tienes IRIS DP en Mac con sesión iniciada:

**Ajustes → Estado del sistema → Descargar para iPad**

---

## Parte 3 — Primera configuración en iPad

1. Abre **IRIS DP**
2. **Inicia sesión** con el mismo email que en Mac
3. Pulsa el icono de **nube** para sincronizar
4. Tus proyectos aparecerán igual que en Mac

---

## Actualizar IRIS DP en iPad

1. Descarga el **IRIS-DP.ipa** nuevo (Release o `./scripts/build_ipad.sh`)
2. Abre con **SideStore** (instala encima de la versión anterior)
3. Abre la app → **sync**

O desde el iPad con la app ya instalada: banner **Descargar IPA** → SideStore.

---

## Automatizar releases (Mac + iPad + Windows)

### Una vez — secretos en GitHub

Repo → **Settings → Secrets and variables → Actions**:

| Secreto | Valor |
|---------|--------|
| `SUPABASE_URL` | Tu Project URL |
| `SUPABASE_ANON_KEY` | Clave anon |
| `SUPABASE_SERVICE_ROLE_KEY` | Clave service_role (rotada) |

### Cada versión nueva — un solo comando

```bash
cd "/Users/danieldiaz/Documents/IRIS DP/iris_dp"
chmod +x scripts/release.sh
./scripts/release.sh 1.0.6
```

Eso hace todo:

1. Actualiza `pubspec.yaml`
2. Commit + tag `v1.0.6`
3. Push → **GitHub Actions** genera `.dmg`, `.zip`, `.ipa`
4. Crea GitHub Release
5. Registra las 3 plataformas en Supabase

Solo sube build (+1) sin cambiar versión:

```bash
./scripts/release.sh
```

---

## Problemas frecuentes

| Problema | Solución |
|----------|----------|
| La app no abre tras ~7 días | Abre **SideStore** en Wi‑Fi para refrescar |
| No descarga el IPA desde la app | Repo GitHub privado → hazlo público o AirDrop el IPA |
| Build iOS falla | `sudo xcodebuild -license accept` |
| SideStore no empareja | Cable USB, confía en el ordenador en el iPad |
