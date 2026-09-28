#!/bin/bash
# SSH-Notschluessel fuer den Unraid-Host.
#
# Erzeugt beim ersten Aufruf ein EIGENES Schluesselpaar in /config/.ssh
# (appdata). Im Image ist kein Schluessel enthalten - jede Installation
# hat ihren eigenen. Der geheime Teil verlaesst den Container nie.
#
# Aufruf im Container:  notschluessel
# Gibt die Zeile aus, die man im Notfall in der Unraid-WebUI eintraegt
# (Users -> root -> SSH authorized keys) und danach wieder entfernt.

set -euo pipefail

VERZ="${HOME:-/config}/.ssh"
DATEI="$VERZ/notschluessel_ed25519"
ERLAUBT="${NOTSCHLUESSEL_FROM:-172.17.0.0/16}"   # Docker-Standardnetz

mkdir -p "$VERZ"
chmod 700 "$VERZ"

if [ ! -f "$DATEI" ]; then
    ssh-keygen -q -t ed25519 -N "" -C "claude-server-notschluessel@$(hostname)" -f "$DATEI"
    echo "Neuer Notschluessel erzeugt: $DATEI"
else
    echo "Notschluessel vorhanden: $DATEI"
fi

echo
echo "Diese EINE Zeile nur im Notfall in Unraid eintragen und danach wieder loeschen:"
echo
echo "from=\"$ERLAUBT\" $(cat "$DATEI.pub")"
echo
echo "from=... bedeutet: Der Schluessel gilt nur aus dem Docker-Netz, nicht von"
echo "anderen Geraeten. Anderes Netz? Container-Variable NOTSCHLUESSEL_FROM setzen."
