#!/usr/bin/env bash
# Compila IRIS DP firmada con el equipo personal de Xcode y la instala en el
# iPad por Wi‑Fi o cable. La firma gratuita dura 7 días: en modo --auto se
# renueva sola cuando quedan menos de 3,5 días o hay un main nuevo con el CI
# en verde, en cuanto el Mac y el iPad coinciden encendidos. Como instalar
# cierra la app, de día solo lo hace si quedan menos de 1,5 días.
#
#   install_ipad.sh                 instala el último main con CI en verde
#   install_ipad.sh --ref <rama>    instala esa rama o commit (sin mirar el CI)
#   install_ipad.sh --auto          lo que ejecuta la tarea programada
#
# Trabaja con su propio clon del repo, fuera de ~/Documents: macOS no deja
# que la tarea programada lea esa carpeta («Operation not permitted»), y así
# tampoco toca las carpetas en las que se trabaja.
set -euo pipefail

BUNDLE_ID="com.ddanieldsdd.irisdp"
GITHUB_REPO="ddanieldsdd-glitch/iris_dp"
STATE_DIR="$HOME/Library/Application Support/IRIS-DP-installer"
REPO="${IRIS_REPO:-$STATE_DIR/repo}"
BUILD_DIR="${IRIS_BUILD_DIR:-$STATE_DIR/iris_dp_ipad}"
# Claves de la nube para compilar: copia guardada por setup_ipad_install.sh.
ENV_FILE="${IRIS_ENV_FILE:-$STATE_DIR/.env}"
STATE="$STATE_DIR/state.json"
TEAM_FILE="$STATE_DIR/team_id"
LOG_DIR="$HOME/Library/Logs/IRIS-DP"
LOG="$LOG_DIR/install_ipad.log"
PROFILES="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
RENEW_BELOW_DAYS=3.5

mkdir -p "$STATE_DIR" "$LOG_DIR"

AUTO=0
REF=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto) AUTO=1 ;;
    --ref) REF="$2"; shift ;;
    *) echo "Opción desconocida: $1" >&2; exit 2 ;;
  esac
  shift
done

log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"; }
notify() {
  osascript -e "display notification \"$2\" with title \"IRIS DP · iPad\" subtitle \"$1\"" \
    >/dev/null 2>&1 || true
}
# Si algo falla sin aviso propio, que quede en el registro y, una vez al día,
# en una notificación: antes fallaba en silencio cada hora.
on_error() {
  local code=$? line=$1
  log "Error inesperado (línea $line, código $code)."
  if [[ "$(state_get error_warned_on)" != "$(date +%F)" ]]; then
    notify "La instalación automática ha fallado" "Mira $LOG"
    state_set "error_warned_on=$(date +%F)"
  fi
  exit "$code"
}
# Ejecuta con límite de tiempo (macOS no trae `timeout`).
with_timeout() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' "$s" "$@"; }

# Una sola ejecución a la vez.
# A mano se espera a que acabe la automática; la automática se retira.
LOCK="$STATE_DIR/lock"
WAITED=0
until mkdir "$LOCK" 2>/dev/null; do
  if [[ -n "$(find "$LOCK" -maxdepth 0 -mmin +120 2>/dev/null)" ]]; then
    rm -rf "$LOCK"; continue
  fi
  [[ $AUTO == 1 ]] && exit 0
  [[ $WAITED == 0 ]] && echo "Hay otra instalación en marcha; espero a que acabe…"
  WAITED=1
  sleep 10
done
trap 'rm -rf "$LOCK"' EXIT
trap 'on_error $LINENO' ERR

state_get() {
  [[ -f "$STATE" ]] || return 0
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2],""))' \
    "$STATE" "$1" 2>/dev/null || true
}
state_set() {
  python3 - "$STATE" "$@" <<'PY'
import json, os, sys
path, *pairs = sys.argv[1:]
data = json.load(open(path)) if os.path.exists(path) else {}
for pair in pairs:
    key, value = pair.split("=", 1)
    data[key] = value
json.dump(data, open(path, "w"), indent=2)
PY
}
# Días que faltan para una fecha ISO (negativo si ya pasó).
days_left() {
  python3 -c 'import sys,datetime as d
t=d.datetime.fromisoformat(sys.argv[1])
print(round((t-d.datetime.now(d.timezone.utc)).total_seconds()/86400,2))' "$1"
}

# ── iPad ────────────────────────────────────────────────────────────────────
find_ipad() {
  local json; json="$(mktemp)"
  with_timeout 60 xcrun devicectl list devices --json-output "$json" >/dev/null 2>&1 || true
  python3 - "$json" "${IRIS_IPAD_DEVICE:-}" <<'PY'
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    sys.exit(0)
wanted = sys.argv[2]
for d in devices:
    hw = d.get("hardwareProperties", {})
    if wanted and wanted not in (d.get("identifier"), hw.get("udid")):
        continue
    if not wanted and hw.get("deviceType") != "iPad":
        continue
    if d.get("connectionProperties", {}).get("pairingState") == "paired":
        print(d["identifier"]); break
PY
  rm -f "$json"
}
ipad_reachable() {
  with_timeout 90 xcrun devicectl device info details --device "$1" >/dev/null 2>&1
}

# ── Qué instalar ────────────────────────────────────────────────────────────
if [[ ! -d "$REPO/.git" ]]; then
  log "Preparo un clon propio del repo en ${REPO}…"
  git clone -q "https://github.com/$GITHUB_REPO.git" "$REPO" >>"$LOG" 2>&1 || {
    log "No pude clonar el repo (¿sin red?)."
    exit 1
  }
fi
if ! FETCH_ERR="$(git -C "$REPO" fetch -q --prune origin 2>&1)"; then
  if [[ "$FETCH_ERR" == *"not permitted"* ]]; then
    log "macOS no deja leer $REPO: $FETCH_ERR"
    notify "Sin permiso para leer el repo" "Mira $LOG"
    exit 1
  fi
  log "Sin red para git fetch; uso lo que hay."
fi

green_main_sha() {
  gh run list -R "$GITHUB_REPO" --branch main --workflow CI --status success \
    --limit 1 --json headSha -q '.[0].headSha' 2>/dev/null || true
}

if [[ -n "$REF" ]]; then
  # Una rama de GitHub vale aunque no exista en el clon como rama local.
  SHA="$(git -C "$REPO" rev-parse --verify -q "$REF^{commit}" \
    || git -C "$REPO" rev-parse --verify "origin/$REF^{commit}")"
  LABEL="$REF"
else
  SHA="$(green_main_sha)"
  if [[ -z "$SHA" ]]; then
    SHA="$(state_get installed_sha)"
    [[ -n "$SHA" ]] || SHA="$(git -C "$REPO" rev-parse origin/main)"
    log "No pude consultar el CI; uso ${SHA:0:7}."
  fi
  if ! git -C "$REPO" cat-file -e "$SHA^{commit}" 2>/dev/null; then
    log "${SHA:0:7} aún no está en local; uso origin/main."
    SHA="$(git -C "$REPO" rev-parse origin/main)"
  fi
  LABEL="main"
fi

# ── ¿Hace falta? (solo en --auto) ───────────────────────────────────────────
EXPIRES="$(state_get expires)"
DAY_INSTALL=0
if [[ $AUTO == 1 ]]; then
  # La primera instalación se hace a mano.
  [[ -n "$(state_get installed_sha)" ]] || exit 0
  # Si se instaló una rama a mano, se renueva esa rama hasta que main la
  # contenga; entonces se vuelve a main.
  INSTALLED_REF="$(state_get installed_ref)"
  INSTALLED_SHA="$(state_get installed_sha)"
  if [[ "$INSTALLED_REF" != "main" ]] \
      && ! git -C "$REPO" merge-base --is-ancestor "$INSTALLED_SHA" "$SHA" 2>/dev/null; then
    NEW_BRANCH_SHA="$(git -C "$REPO" rev-parse --verify -q "origin/$INSTALLED_REF^{commit}" \
      || git -C "$REPO" rev-parse --verify -q "$INSTALLED_REF^{commit}" || true)"
    SHA="${NEW_BRANCH_SHA:-$INSTALLED_SHA}"
    LABEL="$INSTALLED_REF"
  fi
  LEFT=-99
  [[ -n "$EXPIRES" ]] && LEFT="$(days_left "$EXPIRES")"
  NEWER=0
  [[ "$SHA" != "$(state_get installed_sha)" ]] && NEWER=1
  if python3 -c "import sys; sys.exit(0 if float(sys.argv[1]) >= $RENEW_BELOW_DAYS else 1)" "$LEFT" \
      && [[ $NEWER == 0 ]]; then
    exit 0
  fi
  # Instalar cierra la app en el iPad. Si no corre prisa, solo de madrugada
  # (2:00–6:59); con menos de 1,5 días de firma, a cualquier hora.
  HOUR=$((10#$(date +%H)))
  if (( HOUR < 2 || HOUR >= 7 )) \
      && python3 -c "import sys; sys.exit(0 if float(sys.argv[1]) >= 1.5 else 1)" "$LEFT"; then
    exit 0
  fi
  (( HOUR < 2 || HOUR >= 7 )) && DAY_INSTALL=1
fi

DEVICE="$(find_ipad)"
if [[ -z "$DEVICE" ]] || ! ipad_reachable "$DEVICE"; then
  if [[ -z "$DEVICE" ]]; then
    log "No veo el iPad emparejado; se reintentará."
  else
    log "El iPad no responde (¿dormido, bloqueado o en otra Wi‑Fi?); se reintentará."
  fi
  if [[ $AUTO == 1 && -n "$EXPIRES" ]]; then
    LEFT="$(days_left "$EXPIRES")"
    TODAY="$(date +%F)"
    if python3 -c "import sys; sys.exit(0 if float(sys.argv[1]) < 1.5 else 1)" "$LEFT" \
        && [[ "$(state_get warned_on)" != "$TODAY" ]]; then
      notify "La firma caduca pronto" "Enciende el iPad en la misma Wi‑Fi que el Mac para renovarla."
      state_set "warned_on=$TODAY"
    fi
  fi
  [[ $AUTO == 1 ]] && exit 0
  echo "Enciende el iPad, desbloquéalo y ponlo en la misma Wi‑Fi (o por cable)." >&2
  exit 1
fi

TEAM="$(cat "$TEAM_FILE" 2>/dev/null || true)"
if [[ -z "$TEAM" ]]; then
  log "Falta el equipo de firma. Ejecuta scripts/setup_ipad_install.sh."
  notify "Falta configurar la firma" "Ejecuta scripts/setup_ipad_install.sh"
  exit 1
fi

log "Instalando ${SHA:0:7} ($LABEL) en el iPad…"
[[ $DAY_INSTALL == 1 ]] && notify "Renovando la firma" "IRIS DP se cerrará un momento en el iPad."
state_set "last_attempt=$(date -u +%FT%TZ)"

# ── Carpeta de compilación propia ───────────────────────────────────────────
if [[ ! -d "$BUILD_DIR/.git" && ! -f "$BUILD_DIR/.git" ]]; then
  git -C "$REPO" worktree add --detach "$BUILD_DIR" "$SHA" >>"$LOG" 2>&1
fi
git -C "$BUILD_DIR" checkout -q --detach --force "$SHA"
git -C "$BUILD_DIR" clean -qfd -e build -e .dart_tool -e ios/Pods
cp "$ENV_FILE" "$BUILD_DIR/.env" 2>/dev/null \
  || log "Aviso: sin $ENV_FILE, la app saldrá sin nube. Ejecuta scripts/setup_ipad_install.sh."

# El proyecto trae la firma apagada para que el CI compile sin firma. Aquí,
# solo en esta carpeta, se enciende con el equipo personal.
sed -i '' -e 's/CODE_SIGNING_ALLOWED = NO;/CODE_SIGNING_ALLOWED = YES;/' \
  -e 's/CODE_SIGNING_REQUIRED = NO;/CODE_SIGNING_REQUIRED = YES;/' \
  -e 's/"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]" = "";/"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Development";/' \
  "$BUILD_DIR/ios/Runner.xcodeproj/project.pbxproj"
for cfg in Debug Release; do
  f="$BUILD_DIR/ios/Flutter/$cfg.xcconfig"
  sed -i '' -e '/^CODE_SIGNING_ALLOWED=/d' -e '/^CODE_SIGNING_REQUIRED=/d' -e '/^CODE_SIGN_IDENTITY=/d' "$f"
  printf '\nDEVELOPMENT_TEAM=%s\nCODE_SIGN_STYLE=Automatic\n' "$TEAM" >> "$f"
done

# Perfil de firma casi caducado: se borra para que Xcode pida uno nuevo de 7
# días (si no, reinstalar no alargaría la caducidad).
if [[ -d "$PROFILES" ]]; then
  for f in "$PROFILES"/*.mobileprovision; do
    [[ -e "$f" ]] || continue
    security cms -D -i "$f" 2>/dev/null | python3 -c '
import plistlib, sys, datetime as d
p = plistlib.loads(sys.stdin.buffer.read())
app = p.get("Entitlements", {}).get("application-identifier", "")
left = (p["ExpirationDate"].replace(tzinfo=d.timezone.utc) - d.datetime.now(d.timezone.utc)).days
sys.exit(0 if app.endswith("." + sys.argv[1]) and left < 5 else 1)' "$BUNDLE_ID" \
      && { log "Renuevo el perfil de firma: $(basename "$f")"; rm -f "$f"; }
  done
fi

# ── Compilar ────────────────────────────────────────────────────────────────
DEFINES=()
if [[ -f "$BUILD_DIR/.env" ]]; then
  set -a; source "$BUILD_DIR/.env"; set +a
  for k in SUPABASE_URL SUPABASE_ANON_KEY CLOUDINARY_CLOUD_NAME CLOUDINARY_UPLOAD_PRESET; do
    [[ -n "${!k:-}" ]] && DEFINES+=("--dart-define=$k=${!k}")
  done
fi

(
  cd "$BUILD_DIR"
  flutter pub get >>"$LOG" 2>&1
  flutter build ios --release --no-tree-shake-icons ${DEFINES[@]+"${DEFINES[@]}"} >>"$LOG" 2>&1
) || {
  log "La compilación falló (detalle en $LOG)."
  notify "No se pudo compilar" "Mira $LOG"
  exit 1
}

APP="$BUILD_DIR/build/ios/iphoneos/Runner.app"
NEW_EXPIRES="$(security cms -D -i "$APP/embedded.mobileprovision" 2>/dev/null | python3 -c '
import plistlib, sys, datetime as d
e = plistlib.loads(sys.stdin.buffer.read())["ExpirationDate"]
print(e.replace(tzinfo=d.timezone.utc).isoformat())')"

# ── Instalar ────────────────────────────────────────────────────────────────
if ! with_timeout 600 xcrun devicectl device install app --device "$DEVICE" "$APP" >>"$LOG" 2>&1; then
  log "La instalación falló (¿iPad bloqueado o fuera de la Wi‑Fi?)."
  [[ $AUTO == 1 ]] || notify "No se pudo instalar" "Desbloquea el iPad y vuelve a probar."
  exit 1
fi

state_set "installed_sha=$SHA" "installed_ref=$LABEL" "expires=$NEW_EXPIRES" \
  "last_success=$(date -u +%FT%TZ)" "warned_on="
UNTIL="$(python3 -c 'import sys,datetime as d; print(d.datetime.fromisoformat(sys.argv[1]).astimezone().strftime("%d/%m %H:%M"))' "$NEW_EXPIRES")"
log "Instalada ${SHA:0:7}. Firma válida hasta $UNTIL."
notify "IRIS DP instalada" "Versión ${SHA:0:7} · válida hasta $UNTIL"
