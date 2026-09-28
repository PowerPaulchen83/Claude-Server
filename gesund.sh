#!/bin/bash
# Gesundheitspruefung fuer Docker/Unraid (HEALTHCHECK im Dockerfile).
# Gesund = der Dienst "claude remote-control" laeuft.
# Waehrend der 60-s-Pause nach einem Abbruch fehlt er kurz - Docker meldet
# erst nach 3 Fehlversuchen in Folge "unhealthy", das faengt die Pause ab.
if pgrep -f 'claude remote-contro[l]' >/dev/null; then
    echo "ok: Remote Control laeuft"
    exit 0
fi
if [ ! -f "${CLAUDE_CONFIG_DIR:-/config}/.credentials.json" ]; then
    echo "krank: nicht angemeldet"
else
    echo "krank: Remote Control laeuft nicht"
fi
exit 1
