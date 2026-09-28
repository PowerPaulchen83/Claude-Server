# claude-server

Claude Code als **Dauerdienst auf einem Unraid-Server**. Man spricht per
[Remote Control](https://code.claude.com/docs/en/remote-control) mit ihm, vom Handy
(Claude-App) oder von claude.ai/code aus. Er läuft rund um die Uhr, ohne offenes Terminal.

> Privates Hobbyprojekt, ohne Gewähr. Lies den Abschnitt [Sicherheit](#sicherheit),
> bevor du es nutzt.

---

## Inhalt

- [Was der Container macht](#was-der-container-macht)
- [Sicherheit](#sicherheit)
- [Installation auf Unraid](#installation-auf-unraid)
- [Erste Anmeldung](#erste-anmeldung)
- [Updates](#updates)
- [SSH-Notschlüssel](#ssh-notschlüssel)
- [Dateien in diesem Projekt](#dateien-in-diesem-projekt)
- [Fehlersuche](#fehlersuche)

---

## Was der Container macht

- Beim ersten Start installiert er Claude Code über den offiziellen Installer nach `/config/.local`.
  Danach **aktualisiert sich Claude Code selbst**. Dafür braucht es kein neues Image.
- Er startet `claude remote-control` in einer Schleife. Bricht die Verbindung ab, startet er nach 60 s neu.
- Anmeldung, Einstellungen und Gedächtnis liegen in `/config` (appdata), **nie im Image**.
- Das Image selbst enthält nur Debian (`stable-slim`) und ein paar Werkzeuge:
  git, ripgrep, curl, jq, ssh-Client, python3, ping, dig, nc, ip, less, file, unzip.

## Sicherheit

Grundsatz: **Claude darf wenig. Mehr gibt es nur, wenn der Besitzer es ausdrücklich freischaltet.**

| Was | Wie hier gelöst |
|---|---|
| Rückfragen | Läuft **ohne** `--dangerously-skip-permissions`. Jede Änderung muss am Handy bestätigt werden. |
| Benutzer | Läuft als `99:100` (Unraid `nobody:users`), nicht als root. |
| Docker | **Kein** Docker-Socket. Wer den Socket hat, ist praktisch root auf dem Server, auch wenn er „nur lesend“ eingebunden ist. |
| Dateien | Nur `/config` (appdata des Containers) und `/workspace` (ein Arbeitsordner). Keine weiteren Shares. |
| Ports | Keine. Remote Control baut nur eine Verbindung **nach außen** zu Anthropic auf. |
| Zugangsdaten | Nichts davon steht im Image oder in diesem Projekt. Die Anmeldung liegt in `/config/.credentials.json`. |
| SSH | Eigener Schlüssel pro Installation, **normalerweise nicht aktiv** (siehe [SSH-Notschlüssel](#ssh-notschlüssel)). |

Zum Server-Zugriff nutzt Claude MCP-Server (z. B. einen Unraid-MCP im Nur-lesen-Modus), die in
`/config` eingerichtet werden. Die gehören nicht zu diesem Projekt.

**Empfehlungen:** Zwei-Faktor-Anmeldung für das Claude-Konto einschalten und appdata sichern.

## Installation auf Unraid

1. Ordner anlegen (Unraid-Terminal):
   ```bash
   mkdir -p /mnt/user/appdata/claude-server
   chown 99:100 /mnt/user/appdata/claude-server
   ```
2. **Docker → Add Container**:

   | Feld | Wert |
   |---|---|
   | Name | `Claude-Server` |
   | Repository | `ghcr.io/powerpaulchen83/claude-server:latest` |
   | Network Type | `bridge` |
   | Pfad `/config` | `/mnt/user/appdata/claude-server` (rw) |
   | Pfad `/workspace` | ein Arbeitsordner, z. B. `/mnt/user/…/Claude` (rw) |
   | Extra Parameters | *(leer)* |

3. **Apply**. Im Log steht danach „Noch nicht angemeldet …“. Das ist beim ersten Start richtig so.

## Erste Anmeldung

Einmalig im Unraid-Terminal:

```bash
docker exec -it Claude-Server claude
```
1. `/login` eingeben, den Link am PC öffnen, den Code einfügen.
2. Dem Ordner `/workspace` vertrauen, dann `/exit`.

```bash
docker exec -it Claude-Server claude remote-control
```
3. Die Frage „Enable Remote Control? (y/n)“ mit `y` beantworten, dann `Strg+C`.
4. Container neu starten. Die Sitzungen erscheinen in der Claude-App mit dem Namen `server-…`.

## Updates

Es gibt **zwei Teile**, die sich getrennt aktualisieren:

| Teil | Wie |
|---|---|
| Claude Code | automatisch, von selbst |
| Image (Debian + Werkzeuge) | GitHub baut es **am 1. jeden Monats** neu (und bei jeder Änderung). Danach zeigt Unraid im Docker-Tab ein Update an, ein Klick auf **Update** genügt. |

Neu bauen von Hand: Auf GitHub unter **Actions → Image bauen → Run workflow**.

> **Achtung:** Wenn sich im Projekt 60 Tage lang nichts ändert, pausiert GitHub den
> Monatsplan und schickt eine Mail. Dann unter **Actions → Image bauen → Enable workflow** wieder einschalten.

**Notweg ohne GitHub:** Auf dem Unraid selbst bauen:
```bash
bash "/pfad/zu/diesem/ordner/neu-bauen.sh"
```
Danach im Docker-Tab: Container → **Edit → Apply**.

## SSH-Notschlüssel

Für echte Notfälle kann Claude per SSH auf den Unraid-Host, **aber nur, wenn der Besitzer
den Schlüssel gerade freigeschaltet hat**.

- **Jede Installation erzeugt ihren eigenen Schlüssel.** Im Image und in diesem Projekt ist
  **kein** Schlüssel enthalten. Einen Standard-Schlüssel gibt es nicht.
- Der geheime Teil bleibt in `/config/.ssh/`. Er verlässt den Container nie.

**Ablauf im Notfall**
1. Im Container `notschluessel` aufrufen. Beim ersten Mal wird der Schlüssel erzeugt, danach wird nur die Zeile angezeigt.
2. Die ausgegebene Zeile (beginnt mit `from="…"`) in Unraid unter
   **Users → root → SSH authorized keys** eintragen.
3. Claude erledigt die eine Aufgabe, **jeder Befehl nach Rückfrage**.
4. **Die Zeile in Unraid wieder löschen.** Damit ist der Zugang wieder zu.

`from="…"` bedeutet, dass der Schlüssel nur aus dem Docker-Netz gilt (Standard `172.17.0.0/16`).
Wenn das Netz anders ist, die Container-Variable `NOTSCHLUESSEL_FROM` setzen.

## Dateien in diesem Projekt

| Datei | Zweck |
|---|---|
| `Dockerfile` | Bauanleitung für das Image |
| `entrypoint.sh` | Startskript: Installation, Anmeldeprüfung, Remote-Control-Schleife |
| `notschluessel.sh` | erzeugt bzw. zeigt den SSH-Notschlüssel (im Image als `notschluessel`) |
| `neu-bauen.sh` | Notweg: Image auf dem Unraid selbst bauen |
| `.github/workflows/bauen.yml` | GitHub baut und veröffentlicht das Image |
| `CHANGELOG.md` | was sich wann geändert hat |

## Fehlersuche

| Im Log steht … | Bedeutung / Lösung |
|---|---|
| `Noch nicht angemeldet` | [Erste Anmeldung](#erste-anmeldung) durchführen |
| `/config ist nicht beschreibbar` | `chown -R 99:100 /mnt/user/appdata/claude-server` |
| `login expired` | `docker exec -it Claude-Server claude` → `/login` |
| `Remote Control beendet … Neustart in 60 s` | meist kurz kein Netz, er startet von selbst neu |
| Unraid zeigt bei Update „not available“ | Ist das GitHub-Paket öffentlich? (GitHub → Packages → claude-server → Package settings) |

## Lizenz

MIT
