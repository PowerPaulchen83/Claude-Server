#!/bin/bash
# Startskript Claude-Server (Fassung 28.09.2026, Grundlage: altes Skript vom 14.09.).
#
# Vier Zustaende:
#   0. Claude noch nicht installiert -> offiziellen Installer nach /config/.local
#      laufen lassen (einmalig; danach aktualisiert Claude sich selbst).
#   1. Keine Anmeldung               -> warten und im Log sagen, was zu tun ist.
#   2. Anmeldung da                  -> "claude remote-control" in einer Schleife
#      (beendet sich nach ~10 Min. ohne Netz von selbst).
#   3. docker stop                   -> SIGTERM an claude durchreichen.

set -uo pipefail

KONFIG="${CLAUDE_CONFIG_DIR:-/config}"
ARBEIT="${CLAUDE_WORKSPACE:-/workspace}"
PAUSE="${CLAUDE_RESTART_PAUSE:-60}"

melde() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

melde "Claude-Server startet"

if [ ! -w "$KONFIG" ]; then
    melde "FEHLER: $KONFIG ist nicht beschreibbar."
    melde "Auf dem Host pruefen:  chown -R 99:100 /mnt/user/appdata/claude-server"
    exit 1
fi
if [ ! -d "$ARBEIT" ]; then
    melde "FEHLER: $ARBEIT ist nicht eingebunden."
    exit 1
fi

# 0. Installation (nur beim allerersten Start oder wenn das Programm fehlt).
if ! command -v claude >/dev/null 2>&1; then
    melde "Claude ist noch nicht installiert - installiere nach $KONFIG/.local ..."
    if ! curl -fsSL https://claude.ai/install.sh | bash; then
        melde "FEHLER: Installation fehlgeschlagen. Neuer Versuch in $PAUSE s."
        sleep "$PAUSE"
        exit 1
    fi
fi
melde "Claude Code   : $(claude --version 2>/dev/null || echo unbekannt)"

# Einstellungen nur anlegen, wenn keine da sind (eigene Aenderungen bleiben).
# Kein autoMemoryDirectory: Das Gedaechtnis bleibt in /config, nur fuer
# diesen Container - nicht geteilt mit PC oder Laptop.
if [ ! -f "$KONFIG/settings.json" ]; then
    cat > "$KONFIG/settings.json" <<'JSON'
{
  "language": "german"
}
JSON
    melde "settings.json angelegt (Sprache deutsch, eigenes Gedaechtnis)"
fi

# 1. Anmeldung vorhanden?
if [ ! -f "$KONFIG/.credentials.json" ]; then
    melde "=============================================================="
    melde "  Noch nicht angemeldet. Einmalig im Unraid-Terminal:"
    melde "    docker exec -it Claude-Server claude"
    melde "  /login, Link am PC oeffnen, Code einfuegen, Ordner vertrauen,"
    melde "  /exit. Danach:"
    melde "    docker exec -it Claude-Server claude remote-control"
    melde "  'Enable Remote Control? (y/n)' mit y, Strg+C, Container neu starten."
    melde "=============================================================="
    melde "Warte. (Container laeuft weiter, damit docker exec moeglich ist.)"
    while true; do sleep 3600; done
fi

cd "$ARBEIT" || exit 1

KIND=""
beende() {
    melde "Stoppsignal - beende Claude Code."
    [ -n "$KIND" ] && kill -TERM "$KIND" 2>/dev/null
    wait "$KIND" 2>/dev/null
    exit 0
}
trap beende TERM INT

melde "Anmeldung gefunden, starte Remote Control (Sitzungen 'server-...')."

# Bewusst OHNE --dangerously-skip-permissions: Rueckfragen landen beim Benutzer.
while true; do
    claude remote-control --remote-control-session-name-prefix server &
    KIND=$!
    wait "$KIND"
    RC=$?
    KIND=""
    melde "Remote Control beendet (Code $RC). Neustart in $PAUSE s."
    melde "Bei 'login expired':  docker exec -it Claude-Server claude  ->  /login"
    sleep "$PAUSE"
done
