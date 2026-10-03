#!/bin/bash
#description=Container-Waechter: meldet ungesunde oder unerwartet gestoppte Container ueber die Unraid-Benachrichtigungen (z. B. Telegram).
#
# Container-Waechter / container watchdog
#
# Laeuft auf dem Unraid-Host (User Scripts, Zeitplan: alle 5 Minuten, "*/5 * * * *").
# Meldet ueber das Unraid-Benachrichtigungssystem:
#   - Container mit Gesundheitspruefung, die "unhealthy" sind
#   - Container mit Unraid-Autostart, die nicht laufen
#   - Container aus MUSS_LAUFEN (z. B. die Teile von Nextcloud AIO), die nicht laufen
#   - Laufwerke aus PLATZ, die zu voll sind (z. B. das Protokoll-Laufwerk /var/log)
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
# Reports unhealthy containers, autostart containers and MUSS_LAUFEN containers
# (e.g. Nextcloud AIO parts) that are not running, and filesystems from PLATZ
# that are too full (e.g. /var/log), via Unraid notifications, plus one "back to normal" message. SPRACHE=en for English.
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

# Container, die laufen muessen, auch ohne Unraid-Autostart (Muster, mehrere mit Leerzeichen).
# Containers that must run even without Unraid autostart (patterns, space separated).
MUSS_LAUFEN="nextcloud-aio-*"
# Ausnahmen davon: Container, die nur kurz laufen und dann absichtlich stoppen.
# Exceptions: containers that run briefly and stop on purpose.
AUSNAHMEN="nextcloud-aio-domaincheck nextcloud-aio-borgbackup"
# Laeuft einer dieser Container (Backup/Update), werden MUSS_LAUFEN-Container nicht geprueft.
# While one of these runs (backup/update), MUSS_LAUFEN containers are not checked.
PAUSE_WENN_LAEUFT="nextcloud-aio-borgbackup"
# Laufwerke pruefen: Pfad:Grenze-in-Prozent (leer = aus).
# Filesystems to check: path:limit-in-percent (empty = off).
PLATZ="/var/log:80 /var/lib/docker:85"

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

muss_laufen() {
    local m
    for m in $AUSNAHMEN; do [ "$1" = "$m" ] && return 1; done
    for m in $MUSS_LAUFEN; do
        # shellcheck disable=SC2254
        case "$1" in $m) return 0;; esac
    done
    return 1
}

# behandle Schluessel Problem(leer=ok) Betreff Text Betreff-OK
behandle() {
    local key=$1 problem=$2
    local z=${ALT_Z[$key]:-0} g=${ALT_G[$key]:-0}
    if [ -n "$problem" ]; then
        z=$((z + 1))
        if [ "$z" -ge "$SCHWELLE" ] && [ "$g" = "0" ]; then
            melden warning "$3" "$4"
            g=1
        fi
    else
        if [ "$g" = "1" ]; then
            melden normal "$5" "$(t "Wieder in Ordnung seit $JETZT." "Back to normal since $JETZT.")"
        fi
        z=0
        g=0
    fi
    if [ "$z" -gt 0 ] || [ "$g" = "1" ]; then
        NEU+="$key $z $g"$'\n'
    fi
}

# Zustand unveraendert uebernehmen (z. B. waehrend Backup) / keep state unchanged
behalten() {
    [ -n "${ALT_Z[$1]}" ] && NEU+="$1 ${ALT_Z[$1]} ${ALT_G[$1]}"$'\n'
}

declare -A ALT_Z ALT_G
if [ -f "$STATUS" ]; then
    while read -r n z g; do
        [ -n "$n" ] && ALT_Z[$n]=$z && ALT_G[$n]=$g
    done < "$STATUS"
fi

NEU=""
JETZT=$(date '+%H:%M')

PAUSE="nein"
for c in $PAUSE_WENN_LAEUFT; do
    [ "$(docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null)" = "true" ] && PAUSE="ja"
done

while read -r n; do
    [ -z "$n" ] && continue
    zustand=$(docker inspect -f '{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$n" 2>/dev/null) || continue
    laeuft=${zustand%%|*}
    gesund=${zustand#*|}

    problem=""
    if [ "$laeuft" != "running" ]; then
        if autostart_an "$n"; then
            problem="gestoppt"
        elif muss_laufen "$n"; then
            if [ "$PAUSE" = "ja" ]; then behalten "$n"; continue; fi
            problem="gestoppt"
        fi
    elif [ "$gesund" = "unhealthy" ]; then
        problem="ungesund"
    fi

    minuten=$(( (${ALT_Z[$n]:-0} + 1) * INTERVALL ))
    betreff="" text=""
    if [ "$problem" = "ungesund" ]; then
        ausgabe=$(docker inspect -f '{{range .State.Health.Log}}{{.Output}}{{end}}' "$n" 2>/dev/null | grep -v '^[[:space:]]*$' | tail -n 1)
        betreff=$(t "⚠️ $SERVER: $n ist ungesund" "⚠️ $SERVER: $n is unhealthy")
        text=$(t "Seit ca. $minuten Min. ungesund. Prüfung meldet: ${ausgabe:-keine Angabe}" "Unhealthy for about $minuten min. Check says: ${ausgabe:-n/a}")
    elif [ "$problem" = "gestoppt" ]; then
        info=$(docker inspect -f '{{.State.ExitCode}}|{{.State.FinishedAt}}' "$n" 2>/dev/null)
        code=${info%%|*}
        seit=$(date -d "${info#*|}" '+%d.%m. %H:%M' 2>/dev/null || echo "?")
        if autostart_an "$n"; then
            text=$(t "Gestoppt seit $seit (Exit-Code $code), obwohl Autostart an ist." "Stopped since $seit (exit code $code) although autostart is on.")
        else
            text=$(t "Gestoppt seit $seit (Exit-Code $code), sollte aber laufen." "Stopped since $seit (exit code $code) but should be running.")
        fi
        betreff=$(t "⚠️ $SERVER: $n läuft nicht" "⚠️ $SERVER: $n is not running")
    fi
    behandle "$n" "$problem" "$betreff" "$text" \
        "$(t "✅ $SERVER: $n ist wieder in Ordnung" "✅ $SERVER: $n is back to normal")"
done < <(docker ps -a --format '{{.Names}}')

for e in $PLATZ; do
    pfad=${e%%:*}
    grenze=${e##*:}
    [ -d "$pfad" ] || continue
    prozent=$(df -P "$pfad" 2>/dev/null | awk 'NR==2 {sub("%", "", $5); print $5}')
    [ -n "$prozent" ] || continue
    problem=""
    [ "$prozent" -ge "$grenze" ] && problem="voll"
    behandle "platz:$pfad" "$problem" \
        "$(t "⚠️ $SERVER: $pfad ist zu $prozent % voll" "⚠️ $SERVER: $pfad is $prozent % full")" \
        "$(t "Grenze ist $grenze %. Wird es ganz voll, können Dienste Fehler machen." "Limit is $grenze %. If it fills up completely, services may fail.")" \
        "$(t "✅ $SERVER: $pfad wieder unter $grenze %" "✅ $SERVER: $pfad back below $grenze %")"
done

printf '%s' "$NEU" > "$STATUS"
