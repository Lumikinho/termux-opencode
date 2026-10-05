#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail

DISTRO="debian"
CFG="$HOME/.config/opencode"
LOG="$HOME/opencode-install.log"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# o instalador coloca o binário aqui; com --shared-home é o mesmo arquivo nos dois lados
BIN_ON_HOST="$HOME/.opencode/bin/opencode"
BIN_IN_PROOT="/root/.opencode/bin/opencode"

CURRENT=0
TOTAL=6
BAR_W=30
ART_W=106
FILL_CH="█"; EMPTY_CH="░"
# se aparecer lixo (�): FILL_CH="#"; EMPTY_CH="-"

# linhas que são só barra de progresso do curl (filtradas do log)
NOISE='^[#=O[:space:]-]*([0-9.]+%)?$'

# ---------- log ----------
[ -f "$LOG" ] && mv -f "$LOG" "$LOG.old"
: > "$LOG"

log()    { printf '[%s] %s\n' "$(date +%T)" "$*" >> "$LOG"; }
logcmd() { local l="$1"; shift; log "$l: $("$@" 2>&1 | tr '\r\n' '  ' | cut -c1-300)"; }

on_exit() {
  local rc=$?
  printf '\033[?25h'
  log "=== script finalizado (código $rc) ==="
}
trap on_exit EXIT

log "##### Instalação iniciada em $(date) #####"

# ---------- interface ----------
show_banner() {
  local f cols found=""
  cols="$(tput cols 2>/dev/null || echo 80)"
  for f in "$SCRIPT_DIR/banner.ans" "$HOME/.config/opencode-installer/banner.ans"; do
    [ -r "$f" ] && { found="$f"; break; }
  done
  log "banner: arquivo='${found:-nenhum}' colunas=$cols necessário=$ART_W"
  if [ -n "$found" ] && [ "$cols" -ge "$ART_W" ]; then
    cat "$found"
    printf '\033[0m\n'
    return
  fi
  echo "=== Instalador OpenCode + proot-distro ($DISTRO) ==="
  if [ -n "$found" ]; then
    echo "(banner oculto: terminal com $cols colunas, precisa de $ART_W."
    echo " Gire o celular ou diminua a fonte com a pinça.)"
  fi
}

draw() {
  local status="$1" spin="${2:- }" elapsed="${3:-0}"
  local pct=$((CURRENT * 100 / TOTAL))
  local filled=$((pct * BAR_W / 100))
  local bar="" i
  for ((i = 0; i < BAR_W; i++)); do
    if [ "$i" -lt "$filled" ]; then bar+="$FILL_CH"; else bar+="$EMPTY_CH"; fi
  done
  printf '\r\033[2K[%d/%d] %s %s (%ss)\n\r\033[2K%s %3d%%\033[1A' \
    "$((CURRENT + 1))" "$TOTAL" "$status" "$spin" "$elapsed" "$bar" "$pct"
}

fail() {
  log "!!! FALHA no passo: $1"
  printf '\033[2B\n'
  echo "ERRO no passo: $1"
  echo "--- últimas linhas do log ($LOG) ---"
  tail -n 20 "$LOG"
  exit 1
}

run_step() {
  local label="$1"; shift
  local spinner='|/-\' i=0 start=$SECONDS rc
  log ">>> INÍCIO: $label"
  ( "$@" 2>&1 | tr '\r' '\n' | { grep -avE "$NOISE" || true; } >> "$LOG" ) &
  local pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    draw "$label" "${spinner:i++%4:1}" "$((SECONDS - start))"
    sleep 0.2
  done
  wait "$pid"; rc=$?
  log "<<< FIM: $label (código $rc, $((SECONDS - start))s)"
  [ "$rc" -eq 0 ] || fail "$label"
  CURRENT=$((CURRENT + 1))
  draw "$label" "OK" "$((SECONDS - start))"
}

# step <rótulo> <checagem|""> <execução>
step() {
  local label="$1" check="$2" fn="$3"
  if [ -n "${FORCE:-}" ]; then
    log "--- $label: FORCE ativo, ignorando checagem"
  elif [ -n "$check" ]; then
    if "$check" >> "$LOG" 2>&1; then
      log "--- $label: checagem '$check' OK → pulando"
      CURRENT=$((CURRENT + 1))
      draw "$label (já instalado)" "--" "0"
      sleep 0.4
      return
    fi
    log "--- $label: checagem '$check' falhou → executando"
  fi
  run_step "$label" "$fn"
}

# ---------- menu ----------
clear
show_banner
echo
echo "Qual versão instalar?"
echo "  1) opencode v1"
echo "  2) opencode v2 (BETA)"
echo
while true; do
  read -rp "Opção [1-2]: " CHOICE
  case "$CHOICE" in
    1) MAJOR=1; LABEL="opencode v1";        URL="https://opencode.ai/install";     break ;;
    2) MAJOR=2; LABEL="opencode v2 (BETA)"; URL="https://opencode.ai/v2/install";  break ;;
    *) echo "Opção inválida." ;;
  esac
done
log "menu: opção $CHOICE → $LABEL ($URL)"
echo

KEEP_PW=""
if [ -s "$CFG/password" ]; then
  read -rp "Já existe uma senha salva. Manter? [S/n]: " A
  case "$A" in n|N) ;; *) KEEP_PW=1 ;; esac
fi

if [ -z "$KEEP_PW" ]; then
  while true; do
    read -rsp "Escolha a senha do opencode: " P1; echo
    [ -z "$P1" ] && { echo "Senha vazia não permitida."; continue; }
    read -rsp "Confirme a senha: " P2; echo
    [ "$P1" != "$P2" ] && { echo "Senhas não conferem."; continue; }
    break
  done
  OPENCODE_PASS="$P1"
  unset P1 P2
fi
# nunca registramos o valor da senha
if [ -n "$KEEP_PW" ]; then log "senha: mantida a existente"; else log "senha: nova (valor não registrado)"; fi

# ---------- diagnóstico ----------
log "=== DIAGNÓSTICO ==="
log "arch: $(uname -m) | kernel: $(uname -r)"
log "PREFIX=$PREFIX | HOME=$HOME"
log "FORCE='${FORCE:-}'"
logcmd "espaço livre" df -h "$PREFIX"
logcmd "proot-distro" proot-distro --version
if command -v curl >/dev/null 2>&1; then
  logcmd "rede (opencode.ai)" curl -sS -m 10 -o /dev/null -w 'HTTP %{http_code}' https://opencode.ai
else
  log "curl não encontrado no Termux (será usado só dentro do Debian)"
fi
log "estado atual: major instalado='$(cat "$CFG/major" 2>/dev/null || echo '-')' binário=$(ls -l "$BIN_ON_HOST" 2>&1)"
log "=== FIM DO DIAGNÓSTICO ==="

# ---------- checagens ----------
check_proot()  { command -v proot-distro; }

check_debian() { ls -d "$PREFIX/var/lib/proot-distro/containers/$DISTRO"; }

check_deps() {
  proot-distro login "$DISTRO" --shared-tmp --shared-home -- \
    bash -c 'command -v curl && command -v unzip && command -v tar && ls /etc/ssl/certs/ca-certificates.crt'
}

check_opencode() {
  local m
  m="$(cat "$CFG/major" 2>/dev/null)"
  log "check_opencode: marcador='${m:--}' esperado='$MAJOR' | binário: $(ls -l "$BIN_ON_HOST" 2>&1)"
  [ "$m" = "$MAJOR" ] && [ -x "$BIN_ON_HOST" ]
}

# ---------- passos ----------
step_termux_update() {
  log "pkg update"
  pkg update -y
}

step_proot() {
  log "pkg install proot-distro"
  pkg install -y proot-distro
}

step_debian() {
  log "proot-distro install $DISTRO"
  proot-distro install "$DISTRO"
}

step_debian_deps() {
  log "apt-get dentro do Debian"
  proot-distro login "$DISTRO" --shared-tmp --shared-home -- \
    bash -c "export DEBIAN_FRONTEND=noninteractive; apt-get update && apt-get install -y curl ca-certificates unzip tar"
}

step_install() {
  local rc
  log "executando instalador: $URL"
  proot-distro login "$DISTRO" --shared-tmp --shared-home -- \
    bash -c "set -o pipefail; curl -fsSL $URL | bash"
  rc=$?
  log "instalador terminou com código $rc"
  log "~/.opencode/bin: $(ls -la "$HOME/.opencode/bin" 2>&1 | tr '\n' ' ')"
  [ "$rc" -eq 0 ] || return 1

  if [ ! -x "$BIN_ON_HOST" ]; then
    log "ERRO: $BIN_ON_HOST não existe ou não é executável"
    log "busca por binários opencode no Debian:"
    proot-distro login "$DISTRO" --shared-tmp --shared-home -- \
      bash -c "find / -xdev -type f -name 'opencode*' 2>/dev/null | head -n 20"
    return 1
  fi

  mkdir -p "$CFG"
  printf '%s' "$MAJOR" > "$CFG/major"
  log "binário OK em $BIN_ON_HOST | marcador major=$MAJOR gravado"
}

make_wrapper() {
  local out="$PREFIX/bin/opencode"
  log "gerando wrapper em $out"
  rm -f "$out" "$PREFIX/bin/opencode2"
  rm -f "$CFG/bin_path" "$CFG/bin_opencode" "$CFG/bin_opencode2"
  cat > "$out" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

DISTRO="$DISTRO"
BIN="$BIN_IN_PROOT"
EOF
  cat >> "$out" <<'EOF'
PW_FILE="$HOME/.config/opencode/password"

ENVS=()
add_env() { ENVS+=(--env "$1=$2"); }

add_env PREFIX "${PREFIX:-/data/data/com.termux/files/usr}"
while IFS='=' read -r k v; do
  case "$k" in TERMUX_*|TERMUX__*) add_env "$k" "$v" ;; esac
done < <(env)
[ -z "${TERMUX__USER_ID:-}" ] && add_env TERMUX__USER_ID 0

if [ -z "${OPENCODE_SERVER_PASSWORD:-}" ] && [ -r "$PW_FILE" ]; then
  OPENCODE_SERVER_PASSWORD="$(cat "$PW_FILE")"
fi
add_env OPENCODE_SERVER_PASSWORD "${OPENCODE_SERVER_PASSWORD:-}"
add_env OPENCODE_PASSWORD "${OPENCODE_SERVER_PASSWORD:-}"

exec env -u LD_PRELOAD proot-distro login "$DISTRO" --shared-tmp --shared-home \
  "${ENVS[@]}" -- "$BIN" "$@"
EOF
  chmod 700 "$out"
  if bash -n "$out"; then log "wrapper: sintaxe OK"; else log "wrapper: ERRO de sintaxe"; return 1; fi
}

step_config() {
  log "criando diretórios de config"
  mkdir -p "$CFG" "$HOME/.local/share/opencode" "$HOME/.local/state/opencode"

  if [ ! -e "$CFG/opencode.jsonc" ]; then
    printf '{\n  "$schema": "https://opencode.ai/config.json"\n}\n' > "$CFG/opencode.jsonc"
    log "opencode.jsonc criado"
  else
    log "opencode.jsonc já existe, mantido"
  fi

  if [ -z "${KEEP_PW:-}" ]; then
    printf '%s' "$OPENCODE_PASS" > "$CFG/password"
    chmod 600 "$CFG/password"
    log "senha gravada em $CFG/password (chmod 600)"
  else
    log "senha existente mantida"
  fi

  make_wrapper
}

# ---------- execução ----------
printf '\033[?25l'
echo
run_step "Atualizando pacotes do Termux"      step_termux_update
step "Instalando o proot-distro"              check_proot    step_proot
step "Instalando o Debian (pode demorar)"     check_debian   step_debian
step "Instalando dependências do Debian"      check_deps     step_debian_deps
step "Instalando $LABEL"                      check_opencode step_install
run_step "Configurando senha e wrapper"       step_config

# ---------- verificação final ----------
printf '\033[2B\n'
log "=== VERIFICAÇÃO FINAL ==="
VER="$(timeout 30 "$PREFIX/bin/opencode" --version 2>&1 | sed 's/\x1b\[[0-9;]*[A-Za-z]//g' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
log "opencode --version => ${VER:-<não detectada>} (esperado major $MAJOR)"
if [ -n "$VER" ] && [ "${VER%%.*}" != "$MAJOR" ]; then
  log "AVISO: versão detectada difere da escolhida"
  echo "Aviso: instalada ${VER}, mas você escolheu a v$MAJOR (veja o log)."
fi

echo "Pronto! Comando instalado: opencode ($LABEL)${VER:+ — versão $VER}"
[ "$MAJOR" = "2" ] && echo "Interface web: opencode pair"
echo "Log completo em: $LOG"
