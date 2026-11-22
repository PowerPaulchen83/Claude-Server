#!/bin/bash
# Einrichtung Claude-Server (Gegenstueck zu einrichten.ps1 auf den Windows-Geraeten).
# Wird bei jedem Start von entrypoint.sh aufgerufen. Aendert nichts an Anmeldung,
# MCP-Zugaengen oder Gedaechtnis (die liegen dauerhaft in /config).
#
# Zentrale Sperren (optional): eine managed-settings.json vom Host, NUR LESEND
# nach /etc/claude-code eingebunden (Unraid: Pfad mit Access Mode "Read Only").
# Claude laeuft als Benutzer 99 und kann sie dann nicht aendern. Sie liegen
# bewusst nicht im Image, weil jede Installation eigene Regeln hat.

KONFIG="${CLAUDE_CONFIG_DIR:-/config}"
ZENTRAL="/etc/claude-code/managed-settings.json"

melde() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# 1. Zentrale Sperren vorhanden und gueltig?
if [ -r "$ZENTRAL" ] && jq -e . "$ZENTRAL" >/dev/null 2>&1; then
    melde "Zentrale Sperren: $(jq '.permissions.deny | length' "$ZENTRAL") Sperren, $(jq '.permissions.ask | length' "$ZENTRAL") Nachfragen"
else
    melde "Hinweis: keine gueltigen zentralen Sperren unter $ZENTRAL"
fi
if [ -e "$ZENTRAL" ] && [ -w "$ZENTRAL" ]; then
    melde "WARNUNG: $ZENTRAL ist fuer Claude beschreibbar - nur lesend einbinden"
fi

# 2. Eigene Einstellungen nur anlegen, wenn keine da sind (eigene Aenderungen bleiben).
if [ ! -f "$KONFIG/settings.json" ]; then
    cat > "$KONFIG/settings.json" <<'JSON'
{
  "language": "german"
}
JSON
    melde "settings.json angelegt (Sprache deutsch)"
fi
