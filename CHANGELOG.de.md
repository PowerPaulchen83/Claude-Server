# Änderungen

🇬🇧 [English](CHANGELOG.md) · 🇩🇪 **Deutsch**

## 2026-10-03
- Container-Wächter: prüft auch Container, die ohne Unraid-Autostart laufen müssen (`MUSS_LAUFEN`, Standard: Teile von Nextcloud AIO; Pause während des AIO-Backups), und den Füllstand von Laufwerken (`PLATZ`, Standard `/var/log` 80 %, Docker-vDisk 85 %).

## 2026-09-29
- Unraid-Vorlage `unraid/claude-server.xml` mit den empfohlenen Sicherheitseinstellungen (`--cap-drop=ALL`, `no-new-privileges`, Speicher-/CPU-Grenzen).
- README: Installation per Vorlage, Erklärung der Extra Parameters.

## 2026-09-28
- Container-Wächter: Benachrichtigungen abschaltbar (`MELDEN`, `ENTWARNUNG`); alles wird immer ins Systemprotokoll geschrieben.
- `unraid/container-waechter.sh`: optionaler Wächter für den Unraid-Host (ungesunde bzw. gestoppte Autostart-Container → Unraid-Benachrichtigungen, deutsch oder englisch).
- Gesundheitsprüfung: Unraid zeigt *healthy*/*unhealthy* (`gesund`, alle 60 s, 3 Versuche, 5 Min. Anlaufzeit).
- Doku jetzt auf Englisch (`README.md`, `CHANGELOG.md`) und Deutsch (`README.de.md`, `CHANGELOG.de.md`).
- Reine Doku-Änderungen lösen keinen neuen Image-Bau mehr aus.

## 2026-09-28
- Grundsystem von `debian:bookworm-slim` auf `debian:stable-slim` umgestellt (immer die aktuelle Debian-Version).
- Werkzeuge ergänzt: openssh-client, python3, iputils-ping, dnsutils, netcat-openbsd, iproute2, less, file, unzip.
- `notschluessel`: SSH-Notschlüssel, der pro Installation selbst erzeugt wird und normalerweise nicht aktiv ist.
- GitHub baut das Image automatisch (monatlich und bei jeder Änderung), damit Unraid Updates anzeigt.
- Dokumentation (README) geschrieben.

## 2026-09-28 (erste Fassung)
- Claude Code wird nicht mehr ins Image eingebaut, sondern beim ersten Start nach `/config/.local` installiert und aktualisiert sich selbst.
- Remote Control als Dauerdienst, bewusst ohne `--dangerously-skip-permissions`.
