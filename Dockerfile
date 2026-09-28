# Claude-Server: Claude Code als Dauerdienst auf Unraid (Fassung 28.09.2026).
#
# Unterschied zum alten Image (claude-code-home):
#   - Claude ist NICHT im Image eingebaut. Das Startskript installiert es beim
#     ersten Start nach /config/.local (appdata). Dort darf der Container
#     schreiben -> Claude aktualisiert sich selbst, auch ohne Neubau.
#   - Kein Node mehr noetig (der offizielle Installer bringt ein fertiges Programm).
#
# Normalerweise baut GitHub das Image (siehe .github/workflows/bauen.yml und
# README.md) - dann zeigt Unraid Updates wie bei jedem anderen Container.
# Selbst bauen (Notweg): neu-bauen.sh im selben Ordner.

# stable = immer die aktuelle Debian-Hauptversion (Stand 09/2026: 13 trixie).
FROM debian:stable-slim

# git/ripgrep: Projektarbeit und Suche. curl: Installer + MCP-Pruefungen.
# tini: sauberer Init-Prozess. procps: ps/top. jq: JSON lesen.
# openssh-client: Notfallzugang zum Unraid (Schluessel nur bei Bedarf aktiv).
# python3: kleine Auswertungen, Dokument-Skills.
# iputils-ping/dnsutils/netcat/iproute2: Netzwerk pruefen (ping, dig, nc, ip).
# less/file/unzip: Dateien ansehen und entpacken.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        ripgrep \
        curl \
        ca-certificates \
        procps \
        tini \
        jq \
        openssh-client \
        python3 \
        iputils-ping \
        dnsutils \
        netcat-openbsd \
        iproute2 \
        less \
        file \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# Unraid-Konvention nobody(99):users(100).
RUN useradd -u 99 -g 100 -o -d /config -s /bin/bash claude

# Alles Veraenderliche liegt unter /config (appdata): Anmeldung, Einstellungen,
# Gedaechtnis und das Claude-Programm selbst.
# NICHT setzen: DISABLE_TELEMETRY, DO_NOT_TRACK, DISABLE_AUTOUPDATER,
# CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC - sonst gehen Remote Control
# bzw. die Updates nicht.
ENV HOME=/config \
    CLAUDE_CONFIG_DIR=/config \
    PATH=/config/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY notschluessel.sh /usr/local/bin/notschluessel
COPY gesund.sh /usr/local/bin/gesund
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/notschluessel /usr/local/bin/gesund

# Unraid zeigt damit "healthy"/"unhealthy" im Docker-Tab.
# start-period: Zeit fuer die Erstinstallation von Claude beim allerersten Start.
HEALTHCHECK --interval=60s --timeout=10s --start-period=5m --retries=3 \
    CMD ["/usr/local/bin/gesund"]

WORKDIR /workspace
USER 99:100

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
