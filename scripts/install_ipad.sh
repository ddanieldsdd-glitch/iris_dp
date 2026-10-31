#!/usr/bin/env bash
# Compila IRIS DP firmada con el equipo personal de Xcode y la instala en el
# iPad y el iPhone emparejados con este Mac, por Wi‑Fi o cable. La firma
# gratuita dura 7 días: en modo --auto se renueva sola en cada dispositivo
# cuando le quedan menos de 3,5 días o hay un main nuevo con el CI en verde,
# en cuanto el Mac y ese dispositivo coinciden encendidos. Como instalar
# cierra la app, de día solo lo hace si quedan menos de 1,5 días.
#
#   install_ipad.sh                    instala el último main con CI en verde
#   install_ipad.sh --ref <rama>       instala esa rama o commit (sin mirar el CI)
#   install_ipad.sh --device <nombre>  solo en ese dispositivo (nombre o id)
#   install_ipad.sh --auto             lo que ejecuta la tarea programada
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
ONLY_DEVICE="${IRIS_IPAD_DEVICE:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto) AUTO=1 ;;
    --ref) REF="$2"; shift ;;
    --device) ONLY_DEVICE="$2"; shift ;;
    *) echo "Opción desconocida: $1" >&2; exit 2 ;;
  esac
  shift
done

log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"; }
notify() {
  osascript -e "display notification \"$2\" with title \"IRIS DP\" subtitle \"$1\"" \
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
# Estado de cada dispositivo: claves «<id>.<clave>».
dev_get() { state_get "$1.$2"; }
dev_set() {
  local id="$1"; shift
  local pairs=() p
  for p in "$@"; do pairs+=("$id.$p"); done
  state_set "${pairs[@]}"
}
# Días que faltan para una fecha ISO (negativo si ya pasó).
days_left() {
  python3 -c 'import sys,datetime as d
t=d.datetime.fromisoformat(sys.argv[1])
print(round((t-d.datetime.now(d.timezone.utc)).total_seconds()/86400,2))' "$1"
}
at_least() { python3 -c "import sys; sys.exit(0 if float(sys.argv[1]) >= float(sys.argv[2]) else 1)" "$1" "$2"; }

# ── Dispositivos ────────────────────────────────────────────────────────────
# Una línea por iPad o iPhone emparejado: «id<TAB>tipo<TAB>nombre<TAB>udid».
find_devices() {
  local json; json="$(mktemp)"
  with_timeout 60 xcrun devicectl list devices --json-output "$json" >/dev/null 2>&1 || true
  python3 - "$json" "$ONLY_DEVICE" <<'PY'
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    sys.exit(0)
wanted = sys.argv[2]
for d in devices:
    hw = d.get("hardwareProperties", {})
    name = d.get("deviceProperties", {}).get("name", "")
    kind = hw.get("deviceType", "")
    if kind not in ("iPad", "iPhone"):
        continue
    if wanted and wanted not in (d.get("identifier"), hw.get("udid"), name):
        continue
    if d.get("connectionProperties", {}).get("pairingState") == "paired":
        print(f'{d["identifier"]}\t{kind}\t{name or kind}\t{hw.get("udid", "")}')
PY
  rm -f "$json"
}
device_reachable() {
  with_timeout 90 xcrun devicectl device info details --device "$1" >/dev/null 2>&1
}

DEVICES=()
while IFS= read -r line; do DEVICES+=("$line"); done < <(find_devices)
if [[ ${#DEVICES[@]} == 0 ]]; then
  log "No veo ningún iPad ni iPhone emparejado; se reintentará."
  [[ $AUTO == 1 ]] && exit 0
  echo "Conecta el dispositivo por cable una vez y acepta «Confiar en este ordenador»." >&2
  exit 1
fi

# Antes solo había un iPad y su estado iba sin prefijo: pasa al primer iPad.
if [[ -n "$(state_get installed_sha)" && -z "$(state_get migrated_devices)" ]]; then
  for line in "${DEVICES[@]}"; do
    IFS=$'\t' read -r ID KIND NAME UDID <<<"$line"
    [[ "$KIND" == "iPad" ]] || continue
    dev_set "$ID" "installed_sha=$(state_get installed_sha)" "installed_ref=$(state_get installed_ref)" \
      "expires=$(state_get expires)" "last_success=$(state_get last_success)"
    state_set "migrated_devices=1"
    break
  done
fi

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
  MAIN_SHA="$(git -C "$REPO" rev-parse --verify -q "$REF^{commit}" \
    || git -C "$REPO" rev-parse --verify "origin/$REF^{commit}")"
  MAIN_LABEL="$REF"
else
  MAIN_SHA="$(green_main_sha)"
  if [[ -z "$MAIN_SHA" ]]; then
    MAIN_SHA="$(git -C "$REPO" rev-parse origin/main)"
    log "No pude consultar el CI; uso ${MAIN_SHA:0:7}."
  fi
  if ! git -C "$REPO" cat-file -e "$MAIN_SHA^{commit}" 2>/dev/null; then
    log "${MAIN_SHA:0:7} aún no está en local; uso origin/main."
    MAIN_SHA="$(git -C "$REPO" rev-parse origin/main)"
  fi
  MAIN_LABEL="main"
fi

# ── ¿A cuáles les hace falta? ───────────────────────────────────────────────
# Cada entrada: «id<TAB>nombre<TAB>sha<TAB>etiqueta<TAB>de_día».
TODO=()
TARGET_UDIDS=()
HOUR=$((10#$(date +%H)))
for line in "${DEVICES[@]}"; do
  IFS=$'\t' read -r ID KIND NAME UDID <<<"$line"
  SHA="$MAIN_SHA"; LABEL="$MAIN_LABEL"; DAY_INSTALL=0
  EXPIRES="$(dev_get "$ID" expires)"
  if [[ $AUTO == 1 ]]; then
    # La primera instalación en cada dispositivo se hace a mano.
    INSTALLED_SHA="$(dev_get "$ID" installed_sha)"
    [[ -n "$INSTALLED_SHA" ]] || continue
    # Si se instaló una rama a mano, se renueva esa rama hasta que main la
    # contenga; entonces se vuelve a main.
    INSTALLED_REF="$(dev_get "$ID" installed_ref)"
    if [[ "$INSTALLED_REF" != "main" ]] \
        && ! git -C "$REPO" merge-base --is-ancestor "$INSTALLED_SHA" "$SHA" 2>/dev/null; then
      NEW_BRANCH_SHA="$(git -C "$REPO" rev-parse --verify -q "origin/$INSTALLED_REF^{commit}" \
        || git -C "$REPO" rev-parse --verify -q "$INSTALLED_REF^{commit}" || true)"
      SHA="${NEW_BRANCH_SHA:-$INSTALLED_SHA}"
      LABEL="$INSTALLED_REF"
    fi
    LEFT=-99
    [[ -n "$EXPIRES" ]] && LEFT="$(days_left "$EXPIRES")"
    if at_least "$LEFT" "$RENEW_BELOW_DAYS" && [[ "$SHA" == "$INSTALLED_SHA" ]]; then
      continue
    fi
    # Instalar cierra la app. Si no corre prisa, solo de madrugada
    # (2:00–6:59); con menos de 1,5 días de firma, a cualquier hora.
    if (( HOUR < 2 || HOUR >= 7 )); then
      at_least "$LEFT" 1.5 && continue
      DAY_INSTALL=1
    fi
  fi
  if ! device_reachable "$ID"; then
    log "$NAME no responde (¿dormido, bloqueado o en otra Wi‑Fi?); se reintentará."
    if [[ $AUTO == 1 && -n "$EXPIRES" ]]; then
      TODAY="$(date +%F)"
      if ! at_least "$(days_left "$EXPIRES")" 1.5 && [[ "$(dev_get "$ID" warned_on)" != "$TODAY" ]]; then
        notify "La firma caduca pronto en $NAME" "Enciéndelo y desbloquéalo en la misma Wi‑Fi que el Mac."
        dev_set "$ID" "warned_on=$TODAY"
      fi
    fi
    [[ $AUTO == 1 ]] || echo "Enciende $NAME, desbloquéalo y ponlo en la misma Wi‑Fi (o por cable)." >&2
    continue
  fi
  TODO+=("$ID"$'\t'"$NAME"$'\t'"$SHA"$'\t'"$LABEL"$'\t'"$DAY_INSTALL")
  [[ -n "$UDID" ]] && TARGET_UDIDS+=("$UDID")
done

if [[ ${#TODO[@]} == 0 ]]; then
  [[ $AUTO == 1 ]] && exit 0
  exit 1
fi

TEAM="$(cat "$TEAM_FILE" 2>/dev/null || true)"
if [[ -z "$TEAM" ]]; then
  log "Falta el equipo de firma. Ejecuta scripts/setup_ipad_install.sh."
  notify "Falta configurar la firma" "Ejecuta scripts/setup_ipad_install.sh"
  exit 1
fi

# ── Compilar ────────────────────────────────────────────────────────────────
BUILT_SHA=""
APP="$BUILD_DIR/build/ios/iphoneos/Runner.app"
build_sha() {
  local sha="$1"
  # Carpeta de compilación propia.
  if [[ ! -d "$BUILD_DIR/.git" && ! -f "$BUILD_DIR/.git" ]]; then
    git -C "$REPO" worktree add --detach "$BUILD_DIR" "$sha" >>"$LOG" 2>&1
  fi
  git -C "$BUILD_DIR" checkout -q --detach --force "$sha"
  git -C "$BUILD_DIR" clean -qfd -e build -e .dart_tool -e ios/Pods
  cp "$ENV_FILE" "$BUILD_DIR/.env" 2>/dev/null \
    || log "Aviso: sin $ENV_FILE, la app saldrá sin nube. Ejecuta scripts/setup_ipad_install.sh."

  # El proyecto trae la firma apagada para que el CI compile sin firma. Aquí,
  # solo en esta carpeta, se enciende con el equipo personal.
  sed -i '' -e 's/CODE_SIGNING_ALLOWED = NO;/CODE_SIGNING_ALLOWED = YES;/' \
    -e 's/CODE_SIGNING_REQUIRED = NO;/CODE_SIGNING_REQUIRED = YES;/' \
    -e 's/"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]" = "";/"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Development";/' \
    "$BUILD_DIR/ios/Runner.xcodeproj/project.pbxproj"
  local cfg f
  for cfg in Debug Release; do
    f="$BUILD_DIR/ios/Flutter/$cfg.xcconfig"
    sed -i '' -e '/^CODE_SIGNING_ALLOWED=/d' -e '/^CODE_SIGNING_REQUIRED=/d' -e '/^CODE_SIGN_IDENTITY=/d' \
      -e '/^DEVELOPMENT_TEAM=/d' -e '/^CODE_SIGN_STYLE=/d' "$f"
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

  local defines=() k
  if [[ -f "$BUILD_DIR/.env" ]]; then
    set -a; source "$BUILD_DIR/.env"; set +a
    for k in SUPABASE_URL SUPABASE_ANON_KEY CLOUDINARY_CLOUD_NAME CLOUDINARY_UPLOAD_PRESET; do
      [[ -n "${!k:-}" ]] && defines+=("--dart-define=$k=${!k}")
    done
  fi

  flutter_build() {
    (
      cd "$BUILD_DIR"
      flutter pub get >>"$LOG" 2>&1
      flutter build ios --release --no-tree-shake-icons ${defines[@]+"${defines[@]}"} >>"$LOG" 2>&1
    )
  }
  flutter_build || {
    log "La compilación falló (detalle en $LOG)."
    notify "No se pudo compilar" "Mira $LOG"
    return 1
  }

  # El perfil de firma solo vale en los dispositivos dados de alta en el
  # equipo. Uno nuevo se da de alta compilando una vez para él en concreto;
  # luego se vuelve a compilar para que el perfil los incluya a todos.
  local missing=() udid
  for udid in ${TARGET_UDIDS[@]+"${TARGET_UDIDS[@]}"}; do
    profile_has_device "$udid" || missing+=("$udid")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    for udid in "${missing[@]}"; do
      log "Doy de alta $udid en el equipo de firma…"
      (
        cd "$BUILD_DIR/ios"
        xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release \
          -destination "id=$udid" -derivedDataPath "$BUILD_DIR/build/alta_dispositivo" \
          -allowProvisioningUpdates -allowProvisioningDeviceRegistration build >>"$LOG" 2>&1
      ) || log "No pude dar de alta $udid (detalle en $LOG)."
    done
    flutter_build || {
      log "La compilación falló (detalle en $LOG)."
      notify "No se pudo compilar" "Mira $LOG"
      return 1
    }
  fi
  BUILT_SHA="$sha"
}
profile_has_device() {
  security cms -D -i "$APP/embedded.mobileprovision" 2>/dev/null | python3 -c '
import plistlib, sys
sys.exit(0 if sys.argv[1] in plistlib.loads(sys.stdin.buffer.read()).get("ProvisionedDevices", []) else 1)' "$1"
}

# ── Instalar ────────────────────────────────────────────────────────────────
FAILED=0
for entry in "${TODO[@]}"; do
  IFS=$'\t' read -r ID NAME SHA LABEL DAY_INSTALL <<<"$entry"
  log "Instalando ${SHA:0:7} ($LABEL) en $NAME…"
  dev_set "$ID" "last_attempt=$(date -u +%FT%TZ)"
  if [[ "$BUILT_SHA" != "$SHA" ]]; then
    build_sha "$SHA" || exit 1
  fi
  NEW_EXPIRES="$(security cms -D -i "$APP/embedded.mobileprovision" 2>/dev/null | python3 -c '
import plistlib, sys, datetime as d
e = plistlib.loads(sys.stdin.buffer.read())["ExpirationDate"]
print(e.replace(tzinfo=d.timezone.utc).isoformat())')"
  [[ $DAY_INSTALL == 1 ]] && notify "Renovando la firma en $NAME" "IRIS DP se cerrará un momento."

  OUT="$(mktemp)"
  if ! with_timeout 600 xcrun devicectl device install app --device "$ID" "$APP" >"$OUT" 2>&1; then
    cat "$OUT" >>"$LOG"
    if grep -q "DeviceLocked" "$OUT"; then
      log "$NAME está bloqueado: desbloquéalo una vez tras cada reinicio para que acepte instalaciones."
    elif grep -qi "provision\|not included" "$OUT"; then
      log "La firma no incluye $NAME: conéctalo por cable y ejecuta este script a mano una vez."
    else
      log "La instalación en $NAME falló (¿bloqueado o fuera de la Wi‑Fi?)."
    fi
    [[ $AUTO == 1 ]] || notify "No se pudo instalar en $NAME" "Desbloquéalo y vuelve a probar."
    rm -f "$OUT"
    FAILED=1
    continue
  fi
  cat "$OUT" >>"$LOG"; rm -f "$OUT"

  dev_set "$ID" "installed_sha=$SHA" "installed_ref=$LABEL" "expires=$NEW_EXPIRES" \
    "last_success=$(date -u +%FT%TZ)" "warned_on=" "name=$NAME"
  UNTIL="$(python3 -c 'import sys,datetime as d; print(d.datetime.fromisoformat(sys.argv[1]).astimezone().strftime("%d/%m %H:%M"))' "$NEW_EXPIRES")"
  log "Instalada ${SHA:0:7} en $NAME. Firma válida hasta $UNTIL."
  notify "IRIS DP instalada en $NAME" "Versión ${SHA:0:7} · válida hasta $UNTIL"
done

exit "$FAILED"
