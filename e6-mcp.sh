#!/usr/bin/env bash
#
# add-e6-mcp.sh — interactive wizard to connect Claude Code / Claude Desktop
# to your e6data cluster's MCP server.
#
# Run it bare for the wizard, or pass flags to run headless:
#   ./add-e6-mcp.sh --host URL --user EMAIL --password PAT --cluster NAME [--target both]
#   --target: claude-code | claude-desktop | both (default both)
#
# On any failure it offers to restart from the top (re-enter all details).
# Zero install: curl, sed, plutil (macOS), claude CLI. No python / node / mcp-remote.
#
set -euo pipefail

# ---------- colors (auto-off when output isn't a terminal) ----------
if [[ -t 1 ]]; then
  P=$'\033[38;5;99m'; G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; D=$'\033[2m'; B=$'\033[1m'; X=$'\033[0m'
else
  P='' ; G='' ; R='' ; Y='' ; D='' ; B='' ; X=''
fi

banner() {
  printf '%s' "$P"
  cat <<'ART'

       __       _       _
  ___ / /_   __| | __ _| |_ __ _
 / _ \ '_ \ / _` |/ _` | __/ _` |
|  __/ (_) | (_| | (_| | || (_| |
 \___|\___/ \__,_|\__,_|\__\__,_|

   MCP Connector Setup · Connect Claude to your e6 cluster

ART
  printf '%s' "$X"
}
step() { printf "   %s⠿%s %-28s " "$D" "$X" "$1"; }
ok()   { printf "%s✓%s %s\n" "$G" "$X" "${1:-}"; }
fail() { printf "%s✗%s %s\n" "$R" "$X" "${1:-}"; }

# On failure: offer to restart the whole wizard fresh (re-enter everything via exec).
retry_or_quit() {   # $1 = exit code if the user declines
  if [[ -t 0 ]]; then
    echo
    read -r -p "   ${B}↻${X} Retry from the start (re-enter details)? ${D}[Y/n]${X} : " _r
    case "${_r:-y}" in [nN]*) ;; *) echo; exec "$0";; esac
  fi
  exit "${1:-1}"
}

# ---------- flags ----------
HOST="" ; USER_EMAIL="" ; PASSWORD="" ; CLUSTER="" ; NAME="e6data" ; TARGET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)            HOST="$2"; shift 2;;
    --user)            USER_EMAIL="$2"; shift 2;;
    --password|--pat)  PASSWORD="$2"; shift 2;;
    --cluster)         CLUSTER="$2"; shift 2;;
    --name)            NAME="$2"; shift 2;;
    --target)          TARGET="$2"; shift 2;;
    -h|--help)         grep '^#' "$0" | grep -v '^#!' | sed 's/^#\{1,\} \{0,1\}//'; exit 0;;
    *) echo "unknown option: $1 (try --help)" >&2; exit 1;;
  esac
done

banner

# ---------- collect any missing values (prompt only on a TTY) ----------
ask() {  # var  label  [default]
  local _n="$1" _label="$2" _def="${3:-}" _hint="" _in=""
  [[ -n "${!_n}" ]] && return 0
  [[ -t 0 ]] || { echo "${R}ERROR:${X} missing --$_n (running non-interactively)" >&2; exit 1; }
  [[ -n "$_def" ]] && _hint=" ${D}[$_def]${X}"
  read -r -p "   ${B}▸${X} $_label$_hint: " _in
  printf -v "$_n" '%s' "${_in:-$_def}"
}
asksecret() {  # var  label
  local _n="$1" _label="$2"
  [[ -n "${!_n}" ]] && return 0
  [[ -t 0 ]] || { echo "${R}ERROR:${X} missing --$_n (running non-interactively)" >&2; exit 1; }
  read -r -s -p "   ${B}▸${X} $_label: " "$_n"; echo
}

echo "   Let's connect Claude to your e6 cluster."
echo
ask       HOST        "Cluster host URL"
ask       USER_EMAIL  "e6 email"
asksecret PASSWORD    "PAT / password"
ask       CLUSTER     "Cluster name"
HOST="${HOST%/}"

if [[ -z "$TARGET" ]]; then
  if [[ -t 0 ]]; then
    echo "   ${B}▸${X} Add to:"
    echo "       1) Claude Code"
    echo "       2) Claude Desktop"
    echo "       3) Both ${D}[default]${X}"
    read -r -p "     choice [3]: " _t
    case "${_t:-3}" in 1) TARGET=claude-code;; 2) TARGET=claude-desktop;; *) TARGET=both;; esac
  else
    TARGET=both
  fi
fi

miss=""
[[ -z "$HOST" ]] && miss+=" host"
[[ -z "$USER_EMAIL" ]] && miss+=" user"
[[ -z "$PASSWORD" ]] && miss+=" password"
[[ -z "$CLUSTER" ]] && miss+=" cluster"
[[ -n "$miss" ]] && { echo "${R}ERROR:${X} missing:$miss" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "${R}ERROR:${X} 'curl' is required." >&2; exit 1; }

MCP_URL="$HOST/api/v2/mcp"

# ---------- review + confirm ----------
if [[ -t 0 ]]; then
  echo
  echo "   ${D}Review:${X}"
  printf "     host     %s\n" "$HOST"
  printf "     user     %s\n" "$USER_EMAIL"
  printf "     cluster  %s\n" "$CLUSTER"
  printf "     target   %s\n" "$TARGET"
  read -r -p "   Proceed? ${D}[Y/n]${X}: " _c
  case "${_c:-y}" in [nN]*) echo "   aborted."; exit 0;; esac
fi
echo

# ---------- authenticate ----------
# NOTE: the PAT/password must not contain a double-quote (") or backslash (\).
step "Authenticating"
RESP="$(curl -s --max-time 30 --location "$HOST/api/v1/authenticate" \
  --header "cluster-name: $CLUSTER" --header 'Content-Type: application/json' \
  --data "{\"user\":\"$USER_EMAIL\",\"password\":\"$PASSWORD\"}" || true)"
SID="$(printf '%s' "$RESP" | sed -n 's/.*"sessionId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
if [[ -z "$SID" ]]; then fail "auth failed — $(printf '%s' "$RESP" | head -c 80)"; retry_or_quit 1; fi
ok "session token acquired"

# ---------- probe endpoint ----------
step "Checking MCP endpoint"
PROBE="$(curl -s -w '|%{http_code}' --max-time 25 -X POST "$MCP_URL" \
  -H "Authorization: Bearer $SID" -H "cluster-name: $CLUSTER" -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' || echo "|000")"
PCODE="${PROBE##*|}"; PBODY="${PROBE%|*}"
if   [[ "$PCODE" == "200" ]]; then ok "reachable (HTTP 200)"
elif printf '%s' "$PBODY" | grep -qi "jwt issuer"; then fail "gateway-blocked (Envoy JWT — platform must whitelist /api/v2/mcp)"; retry_or_quit 2
elif printf '%s' "$PBODY" | grep -qi "suspend"; then  fail "workspace suspended — resume it in the e6 console"; retry_or_quit 2
else fail "HTTP $PCODE — $PBODY"; retry_or_quit 2
fi

SERVER_JSON="{\"type\":\"http\",\"url\":\"$MCP_URL\",\"headers\":{\"Authorization\":\"Bearer $SID\",\"cluster-name\":\"$CLUSTER\"}}"

# ---------- configure clients (only reached when the endpoint is reachable) ----------
setup_cc() {
  step "Adding to Claude Code"
  command -v claude >/dev/null 2>&1 || { fail "'claude' CLI not found — skipped"; return; }
  claude mcp remove "$NAME" -s local >/dev/null 2>&1 || true
  claude mcp add --transport http "$NAME" "$MCP_URL" \
    --header "Authorization: Bearer $SID" --header "cluster-name: $CLUSTER" >/dev/null
  ok "$NAME added"
}
setup_desktop() {
  step "Writing Claude Desktop config"
  command -v plutil >/dev/null 2>&1 || { fail "'plutil' not found (macOS only) — skipped"; return; }
  local cfg="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
  mkdir -p "$(dirname "$cfg")"; [[ -f "$cfg" ]] || echo '{}' >"$cfg"
  plutil -extract mcpServers raw "$cfg" >/dev/null 2>&1 || plutil -insert mcpServers -json '{}' "$cfg"
  plutil -replace "mcpServers.$NAME" -json "$SERVER_JSON" "$cfg"
  ok "config updated (⌘Q + reopen to load)"
}
case "$TARGET" in
  claude-code)    setup_cc;;
  claude-desktop) setup_desktop;;
  both)           setup_cc; setup_desktop;;
  *) echo "${R}ERROR:${X} unknown --target '$TARGET' (claude-code|claude-desktop|both)" >&2; exit 1;;
esac

# ---------- success ----------
echo
printf '%s' "$G"
cat <<'DONE'
   ╭───────────────────────────────────────────────╮
   │   ✅  All set — e6data is connected.            │
   ╰───────────────────────────────────────────────╯
DONE
printf '%s' "$X"
echo "   ${D}•${X} Claude Code   → ready now"
if [[ "$TARGET" != "claude-code" ]]; then echo "   ${D}•${X} Claude Desktop → fully quit (⌘Q) & reopen"; fi
echo "   ${D}•${X} Try: \"list the catalogs in e6data\""
echo "   ${D}token expires ~5h — re-run to refresh.${X}"