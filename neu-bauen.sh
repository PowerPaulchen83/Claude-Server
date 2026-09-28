#!/bin/bash
# Claude-Server-Image neu bauen (auf dem Unraid ausfuehren, z. B. als User Script).
# Holt das aktuelle Debian und die neuesten Werkzeug-Versionen.
# Der laufende Container merkt davon nichts - erst "Edit -> Apply" im
# Docker-Tab startet ihn mit dem neuen Image. Gedaechtnis und Anmeldung
# liegen in appdata und bleiben erhalten.

set -euo pipefail
cd "$(dirname "$0")"

ALT=$(docker image inspect -f '{{.Id}}' claude-server:latest 2>/dev/null || true)

echo "Baue claude-server:latest neu ..."
docker build --pull --no-cache -t claude-server:latest .

NEU=$(docker image inspect -f '{{.Id}}' claude-server:latest)

# Nur das eigene alte Image entfernen, und nur wenn es niemand mehr benutzt.
if [ -n "$ALT" ] && [ "$ALT" != "$NEU" ]; then
    docker rmi "$ALT" >/dev/null 2>&1 \
        && echo "Altes Image entfernt." \
        || echo "Altes Image wird noch benutzt - bleibt bis nach Edit -> Apply."
fi

echo "Fertig. Jetzt im Docker-Tab: Claude-Server -> Edit -> Apply."
