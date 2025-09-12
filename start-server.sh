#!/usr/bin/env bash
# Rising Storm 2: Vietnam — easy launcher (Wine + Xvfb)
# Usage: ./rs2.sh start|stop|restart|status|tail|update
set -euo pipefail

### ── EDITABLE SETTINGS ──────────────────────────────────────────────────────
# Wine prefix and server folder (change if you used a different prefix)
RS2_PREFIX="${RS2_PREFIX:-$HOME/.wine}"
RS2_DIR="${RS2_DIR:-$RS2_PREFIX/drive_c/rs2server}"
BIN_REL="Binaries/Win64/VNGame.exe"

# Map & mode
MAP="${MAP:-VNTE-CuChi}"
GAME_MODE="${GAME_MODE:-ROGame.ROGameInfoTerritories}"  # e.g. ROGame.ROGameInfoSupremacy

# Player limits
MIN_PLAYERS="${MIN_PLAYERS:-0}"
MAX_PLAYERS="${MAX_PLAYERS:-64}"

# Ports
GAME_PORT="${GAME_PORT:-7777}"        # UDP
QUERY_PORT="${QUERY_PORT:-27015}"     # UDP
WEBADMIN_PORT="${WEBADMIN_PORT:-8080}"# TCP

# Bind address for the server. Set to "auto" to use your first host IP, or set
# a specific IP (e.g., 192.168.1.50). Leave blank to let the game choose.
MULTIHOME="${MULTIHOME:-auto}"

# Extra Unreal/RS2 args (safe defaults)
EXTRA_ARGS="${EXTRA_ARGS:--unattended -NoSound}"

# How to run headless + wine binaries (change if you prefer plain `wine`)
XVFB_RUN="${XVFB_RUN:-/usr/bin/xvfb-run -a}"
WINE_BIN="${WINE_BIN:-/usr/bin/wine}"

# Optional tmux session name. If tmux exists, we’ll use it to keep the server
# alive in the background. Set empty ("") to run in the foreground.
TMUX_SESSION="${TMUX_SESSION:-rs2}"

# SteamCMD for updates: use Linux steamcmd if present, else Windows steamcmd under Wine
LINUX_STEAMCMD="${LINUX_STEAMCMD:-/usr/games/steamcmd}"
WINSTEAMCMD_DIR="${WINSTEAMCMD_DIR:-$HOME/.local/share/winsteamcmd}"
WIN_STEAMCMD_EXE="$WINSTEAMCMD_DIR/steamcmd.exe"
STEAM_USER="${STEAM_USER:-}"   # set this if you want `./rs2.sh update` to log in automatically
### ───────────────────────────────────────────────────────────────────────────

APPID=418480
MAP_TOKEN="${MAP}?Game=${GAME_MODE}?MinPlayers=${MIN_PLAYERS}?MaxPlayers=${MAX_PLAYERS}"
EXE="$RS2_DIR/$BIN_REL"
LOG_DIR="$RS2_DIR/ROGame/Logs"
STDOUT_LOG="$RS2_DIR/rs2_stdout.log"

detect_ip() {
  if [[ "$MULTIHOME" == "auto" ]]; then
    hostname -I 2>/dev/null | awk '{print $1}'
  else
    echo -n "$MULTIHOME"
  fi
}

ensure_basics() {
  [[ -x "$WINE_BIN" ]] || { echo "wine not found at $WINE_BIN"; exit 1; }
  [[ -x "$(command -v xvfb-run)" ]] || { echo "xvfb-run not found. sudo apt install xvfb"; exit 1; }
  [[ -f "$EXE" ]] || { echo "Server binary not found at: $EXE"; exit 1; }

  # Steam app id file (helps Steam API init)
  echo "$APPID" > "$RS2_DIR/steam_appid.txt"

  # Put steamclient64.dll next to the EXE if missing (common Wine gotcha)
  if [[ ! -f "$RS2_DIR/Binaries/Win64/steamclient64.dll" ]]; then
    mkdir -p "$WINSTEAMCMD_DIR"
    if [[ ! -f "$WIN_STEAMCMD_EXE" ]]; then
      curl -sSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip -o "$WINSTEAMCMD_DIR/steamcmd.zip"
      (cd "$WINSTEAMCMD_DIR" && unzip -o steamcmd.zip >/dev/null)
    fi
    cp -n "$WINSTEAMCMD_DIR/steamclient64.dll" "$RS2_DIR/Binaries/Win64/" 2>/dev/null || true
  fi
}

start_cmd() {
  local ip; ip="$(detect_ip)"
  local multihome_arg=()
  [[ -n "$ip" ]] && multihome_arg=(-MultiHome="$ip")

  # Build command
  echo "Launching RS2 server from: $RS2_DIR"
  echo "Map token: $MAP_TOKEN"
  echo "Ports: game=$GAME_PORT/udp query=$QUERY_PORT/udp webadmin=$WEBADMIN_PORT/tcp"
  echo "MultiHome: ${ip:-'(unset)'}"
  echo

  cd "$RS2_DIR"
  SteamAppId=$APPID SteamGameId=$APPID \
  WINEPREFIX="$RS2_PREFIX" \
  $XVFB_RUN "$WINE_BIN" "./$BIN_REL" \
    server "$MAP_TOKEN" \
    -log -Port="$GAME_PORT" -QueryPort="$QUERY_PORT" -WebAdminPort="$WEBADMIN_PORT" \
    "${multihome_arg[@]}" $EXTRA_ARGS
}

start_tmux() {
  command -v tmux >/dev/null || { echo "tmux not installed; starting in foreground."; start_cmd; return; }
  tmux has-session -t "$TMUX_SESSION" 2>/dev/null && { echo "Session '$TMUX_SESSION' already running."; return; }
  mkdir -p "$LOG_DIR"
  cd "$RS2_DIR"
  # Run inside tmux and tee stdout (Unreal also logs to $LOG_DIR)
  tmux new-session -d -s "$TMUX_SESSION" -c "$RS2_DIR" \
    "SteamAppId=$APPID SteamGameId=$APPID WINEPREFIX='$RS2_PREFIX' $XVFB_RUN $WINE_BIN './$BIN_REL' server '$MAP_TOKEN' -log -Port='$GAME_PORT' -QueryPort='$QUERY_PORT' -WebAdminPort='$WEBADMIN_PORT' $( [[ -n $(detect_ip) ]] && echo -MultiHome=$(detect_ip) ) $EXTRA_ARGS 2>&1 | stdbuf -oL -eL tee '$STDOUT_LOG'"
  echo "Started in tmux session: $TMUX_SESSION"
  echo "Attach with: tmux attach -t $TMUX_SESSION"
}

stop_all() {
  # If tmux, kill the session
  if command -v tmux >/dev/null && tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    tmux kill-session -t "$TMUX_SESSION"
    echo "Stopped tmux session '$TMUX_SESSION'."
  fi
  # Kill any stray VNGame.exe and cleanly stop wineserver for this prefix
  pkill -f "Binaries/Win64/VNGame\.exe" 2>/dev/null || true
  WINEPREFIX="$RS2_PREFIX" wineserver -k || true
}

status() {
  echo "== Processes =="
  pgrep -fa "VNGame\.exe" || echo "(none)"
  echo
  echo "== Ports =="
  sudo ss -ulnp | egrep -E ":(?:$GAME_PORT|$QUERY_PORT)\b" || echo "(no UDP ports open)"
  sudo ss -ltnp  | egrep -E ":(?:$WEBADMIN_PORT)\b" || echo "(no WebAdmin port open)"
  echo
  echo "== Logs =="
  ls -1t "$LOG_DIR" 2>/dev/null | head || echo "(no logs yet)"
}

tail_logs() {
  mkdir -p "$LOG_DIR"
  local latest
  latest="$(ls -1t "$LOG_DIR"/*.log 2>/dev/null | head -1 || true)"
  if [[ -n "${latest:-}" ]]; then
    echo "Tailing: $latest"
    tail -n 200 -F "$latest"
  else
    echo "No logs yet in $LOG_DIR"
  fi
}

update_server() {
  echo "Updating RS2 server to latest build..."
  mkdir -p "$RS2_DIR"
  if [[ -x "$LINUX_STEAMCMD" ]]; then
    # Recommend logging in with the account that owns RS2
    "$LINUX_STEAMCMD" \
      +@sSteamCmdForcePlatformType windows \
      +login "${STEAM_USER:-anonymous}" \
      +force_install_dir "$RS2_DIR" \
      +app_update "$APPID" validate +quit
  else
    # Fallback to Windows SteamCMD under Wine
    mkdir -p "$WINSTEAMCMD_DIR"
    [[ -f "$WIN_STEAMCMD_EXE" ]] || {
      curl -sSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip -o "$WINSTEAMCMD_DIR/steamcmd.zip"
      (cd "$WINSTEAMCMD_DIR" && unzip -o steamcmd.zip >/dev/null)
    }
    WINEPREFIX="$RS2_PREFIX" $XVFB_RUN $WINE_BIN "$WIN_STEAMCMD_EXE" \
      +@sSteamCmdForcePlatformType windows \
      +login "${STEAM_USER:-anonymous}" \
      +force_install_dir C:\\rs2server \
      +app_update "$APPID" validate +quit
  fi
  echo "Update finished."
}

case "${1:-}" in
  start)   ensure_basics; [[ -n "$TMUX_SESSION" ]] && start_tmux || start_cmd ;;
  stop)    stop_all ;;
  restart) stop_all; sleep 1; ensure_basics; [[ -n "$TMUX_SESSION" ]] && start_tmux || start_cmd ;;
  status)  status ;;
  tail)    tail_logs ;;
  update)  update_server ;;
  *) echo "Usage: $0 {start|stop|restart|status|tail|update}"; exit 1 ;;
esac
