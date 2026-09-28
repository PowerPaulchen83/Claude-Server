# Änderungen

🇬🇧 [English](CHANGELOG.md) · 🇩🇪 **Deutsch**

## 2026-09-28
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
