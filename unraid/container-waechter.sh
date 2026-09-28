#!/bin/bash
#description=Container-Waechter: meldet ungesunde oder unerwartet gestoppte Container ueber die Unraid-Benachrichtigungen (z. B. Telegram).
#
# Container-Waechter / container watchdog
#
# Laeuft auf dem Unraid-Host (User Scripts, Zeitplan: alle 5 Minuten, "*/5 * * * *").
# Meldet ueber das Unraid-Benachrichtigungssystem:
#   - Container mit Gesundheitspruefung, die "unhealthy" sind
#   - Container mit Unraid-Autostart, die nicht laufen
#   - und einmal "wieder in Ordnung", wenn das Problem vorbei ist
# Gemeldet wird erst, wenn das Problem SCHWELLE Laeufe hintereinander besteht
# (Standard 2 = ca. 10 Min.). Kurze Unterbrechungen wie das Appdata-Backup
# loesen so keinen Alarm aus. Jedes Problem wird nur einmal gemeldet.
#
# Einstellungen oben: MELDEN=nein schaltet die Benachrichtigungen ab (nur syslog),
# ENTWARNUNG=nein unterdrueckt die "wieder in Ordnung"-Meldung. Ob Unraid eine
# Meldung per Telegram, E-Mail oder im Browser zeigt, stellt man in Unraid unter
# Settings -> Notifications pro Stufe ein (Warnungen / Hinweise).
#
# Runs on the Unraid host (User Scripts, schedule every 5 minutes).
# Reports unhealthy containers and autostart containers that are not running
# via Unraid notifications, plus one "back to normal" message. SPRACHE=en for English.
# MELDEN=nein (no) = syslog only, ENTWARNUNG=nein (no) = no "back to normal" message.
# Which channels (Telegram, e-mail, browser) are used is set in Unraid under
# Settings -> Notifications per level (warnings / notices).

SPRACHE="de"      # de = Deutsch, en = English
MELDEN="ja"       # ja = Unraid-Benachrichtigung (Telegram/E-Mail/Browser, je nach Unraid-Einstellung)
                  # nein = nur ins Systemprotokoll (syslog) schreiben, keine Benachrichtigung
                  # yes/ja = send Unraid notification, no/nein = syslog only
ENTWARNUNG="ja"   # ja = auch "wieder in Ordnung" melden, nein = nur Probleme / yes/no: also send "back to normal"
SCHWELLE=2        # Laeufe in Folge, bevor gemeldet wird / runs in a row before alerting
INTERVALL=5       # Minuten zwischen den Laeufen / minutes between runs (only for the text)

STATUS=/tmp/container-waechter.status
AUTOSTART=/var/lib/docker/unraid-autostart
NOTIFY=/usr/local/emhttp/webGui/scripts/notify
SERVER=$(hostname)

t() { if [ "$SPRACHE" = "en" ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }

ja() { case "$1" in ja|yes|j|y|1|true) return 0;; *) return 1;; esac; }

melden() {  # $1=Stufe (warning|normal) $2=Betreff $3=Text
    # Immer ins Systemprotokoll / always to syslog
    logger -t container-waechter "$2 - $3"
    [ "$1" = "normal" ] && ! ja "$ENTWARNUNG" && return 0
    ja "$MELDEN" || return 0
    "$NOTIFY" -e "$(t Container-Waechter 'Container watchdog')" -s "$2" -d "$3" -i "$1"
}

autostart_an() {
    [ -f "$AUTOSTART" ] && awk -v n="$1" '$1==n {f=1} END {exit !f}' "$AUTOSTART"
}

declare -A ALT_Z ALT_G
if [ -f "$STATUS" ]; then
    while read -r n z g; do
        [ -n "$n" ] && ALT_Z[$n]=$z && ALT_G[$n]=$g
    done < "$STATUS"
fi

NEU=""
JETZT=$(date '+%H:%M')

while read -r n; do
    [ -z "$n" ] && continue
    zustand=$(docker inspect -f '{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$n" 2>/dev/null) || continue
    laeuft=${zustand%%|*}
    gesund=${zustand#*|}

    problem=""
    if [ "$laeuft" != "running" ]; then
        autostart_an "$n" && problem="gestoppt"
    elif [ "$gesund" = "unhealthy" ]; then
        problem="ungesund"
    fi

    z=${ALT_Z[$n]:-0}
    g=${ALT_G[$n]:-0}

    if [ -n "$problem" ]; then
        z=$((z + 1))
        if [ "$z" -ge "$SCHWELLE" ] && [ "$g" = "0" ]; then
            minuten=$((z * INTERVALL))
            if [ "$problem" = "ungesund" ]; then
                ausgabe=$(docker inspect -f '{{range .State.Health.Log}}{{.Output}}{{end}}' "$n" 2>/dev/null | grep -v '^[[:space:]]*$' | tail -n 1)
                melden warning \
                    "$(t "⚠️ $SERVER: $n ist ungesund" "⚠️ $SERVER: $n is unhealthy")" \
                    "$(t "Seit ca. $minuten Min. ungesund. Prüfung meldet: ${ausgabe:-keine Angabe}" "Unhealthy for about $minuten min. Check says: ${ausgabe:-n/a}")"
            else
                info=$(docker inspect -f '{{.State.ExitCode}}|{{.State.FinishedAt}}' "$n" 2>/dev/null)
                code=${info%%|*}
                seit=$(date -d "${info#*|}" '+%d.%m. %H:%M' 2>/dev/null || echo "?")
                melden warning \
                    "$(t "⚠️ $SERVER: $n läuft nicht" "⚠️ $SERVER: $n is not running")" \
                    "$(t "Gestoppt seit $seit (Exit-Code $code), obwohl Autostart an ist." "Stopped since $seit (exit code $code) although autostart is on.")"
            fi
            g=1
        fi
    else
        if [ "$g" = "1" ]; then
            melden normal \
                "$(t "✅ $SERVER: $n ist wieder in Ordnung" "✅ $SERVER: $n is back to normal")" \
                "$(t "Wieder in Ordnung seit $JETZT." "Back to normal since $JETZT.")"
        fi
        z=0
        g=0
    fi

    if [ "$z" -gt 0 ] || [ "$g" = "1" ]; then
        NEU+="$n $z $g"$'\n'
    fi
done < <(docker ps -a --format '{{.Names}}')

printf '%s' "$NEU" > "$STATUS"
