# claude-server

🇬🇧 [English](README.md) · 🇩🇪 **Deutsch**

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
- [Container-Wächter (optional)](#container-wächter-optional)
- [Dateien in diesem Projekt](#dateien-in-diesem-projekt)
- [Fehlersuche](#fehlersuche)

---

## Was der Container macht

- Beim ersten Start installiert er Claude Code über den offiziellen Installer nach `/config/.local`.
  Danach **aktualisiert sich Claude Code selbst**. Dafür braucht es kein neues Image.
- Er startet `claude remote-control` in einer Schleife. Bricht die Verbindung ab, startet er nach 60 s neu.
- Anmeldung, Einstellungen und Gedächtnis liegen in `/config` (appdata), **nie im Image**.
- Eine **Gesundheitsprüfung** läuft alle 60 s: Unraid zeigt den Container als *healthy*, solange Remote Control läuft, und nach etwa 3 Minuten ohne als *unhealthy*.
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
| Sonderrechte | Start mit `--cap-drop=ALL` und `no-new-privileges` (siehe [Installation](#installation-auf-unraid)). |
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
2. **Am einfachsten: mit der Vorlage.** In den Vorlagen-Ordner von Unraid laden (Unraid-Terminal):
   ```bash
   wget -O /boot/config/plugins/dockerMan/templates-user/my-Claude-Server.xml \
     https://raw.githubusercontent.com/PowerPaulchen83/Claude-Server/main/unraid/claude-server.xml
   ```
   Dann **Docker → Add Container → Template: Claude-Server**, den **Arbeitsordner** eintragen, **Apply**.

   > ⚠️ Nur für eine **neue** Installation. Gibt es schon einen Container `Claude-Server`,
   > überschreibt der Befehl dessen gespeicherte Einstellungen.

   **Oder von Hand: Docker → Add Container**:

   | Feld | Wert |
   |---|---|
   | Name | `Claude-Server` |
   | Repository | `ghcr.io/powerpaulchen83/claude-server:latest` |
   | Network Type | `bridge` |
   | Pfad `/config` | `/mnt/user/appdata/claude-server` (rw) |
   | Pfad `/workspace` | ein Arbeitsordner, z. B. `/mnt/user/…/Claude` (rw) |
   | Extra Parameters (Advanced View) | `--hostname claude-server --security-opt=no-new-privileges --cap-drop=ALL --memory=4g --cpus=4` |

3. **Apply**. Im Log steht danach „Noch nicht angemeldet …“. Das ist beim ersten Start richtig so.

**Was die Extra Parameters bewirken**

| Parameter | Bedeutung |
|---|---|
| `--cap-drop=ALL` | nimmt dem Container alle Linux-Sonderrechte; Claude braucht keine davon |
| `--security-opt=no-new-privileges` | niemand im Container kann nachträglich mehr Rechte bekommen (z. B. über `su`) |
| `--memory=4g --cpus=4` | Obergrenzen, damit der Container den Server nie ausbremst |
| `--hostname claude-server` | fester Name statt zufälliger Kennung |

Mit diesen Grenzen funktioniert trotzdem alles: Dateien, git, Netzwerk, `ping`, Updates.

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
| Image (Debian + Werkzeuge) | GitHub baut es **am 1. jeden Monats** neu (und bei jeder Änderung außer reiner Doku). Danach zeigt Unraid im Docker-Tab ein Update an, ein Klick auf **Update** genügt. |

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

## Container-Wächter (optional)

`unraid/container-waechter.sh` ist ein kleines Skript für den **Unraid-Host** (nicht für den Container).
Es schickt über die normalen Unraid-Benachrichtigungen (z. B. Telegram, E-Mail) eine Nachricht, wenn

- ein Container mit Gesundheitsprüfung **unhealthy** wird (z. B. dieser hier) oder
- ein Container mit **Unraid-Autostart** nicht läuft,

und noch eine, wenn alles wieder in Ordnung ist. Gemeldet wird erst, wenn das Problem 2 Läufe
hintereinander besteht (ca. 10 Min.). Kurze Unterbrechungen wie das Appdata-Backup bleiben so still.

**Einrichten:** Settings → User Scripts → Add New Script → Inhalt der Datei einfügen →
Zeitplan **Custom** `*/5 * * * *`.

**Einstellungen** (oben im Skript):

| Einstellung | Standard | Bedeutung |
|---|---|---|
| `SPRACHE` | `de` | `en` für englische Meldungen |
| `MELDEN` | `ja` | `nein` = **keine Benachrichtigungen**, nur ein Eintrag im Unraid-Systemprotokoll |
| `ENTWARNUNG` | `ja` | `nein` = keine „wieder in Ordnung“-Meldung, nur Probleme |
| `SCHWELLE` | `2` | wie viele Läufe (je 5 Min.) ein Problem bestehen muss, bevor gemeldet wird |

Ob eine Meldung per Telegram, E-Mail oder nur im Browser ankommt, stellst du in Unraid unter
**Settings → Notifications** pro Stufe ein (der Wächter nutzt *Warnung* für Probleme und *Hinweis* für „wieder in Ordnung“).

Beispiel:
```
⚠️ PowerServer: Claude-Server ist ungesund
Seit ca. 10 Min. ungesund. Prüfung meldet: krank: Remote Control laeuft nicht
```

## Dateien in diesem Projekt

| Datei | Zweck |
|---|---|
| `Dockerfile` | Bauanleitung für das Image |
| `entrypoint.sh` | Startskript: Installation, Anmeldeprüfung, Remote-Control-Schleife |
| `notschluessel.sh` | erzeugt bzw. zeigt den SSH-Notschlüssel (im Image als `notschluessel`) |
| `gesund.sh` | Gesundheitsprüfung (im Image als `gesund`) |
| `unraid/claude-server.xml` | Unraid-Vorlage mit allen Einstellungen |
| `unraid/container-waechter.sh` | optionaler Wächter für den Unraid-Host, siehe [Container-Wächter](#container-wächter-optional) |
| `neu-bauen.sh` | Notweg: Image auf dem Unraid selbst bauen |
| `.github/workflows/bauen.yml` | GitHub baut und veröffentlicht das Image |
| `CHANGELOG.de.md` | was sich wann geändert hat (englisch: `CHANGELOG.md`) |

## Fehlersuche

| Im Log steht … | Bedeutung / Lösung |
|---|---|
| `Noch nicht angemeldet` | [Erste Anmeldung](#erste-anmeldung) durchführen |
| `/config ist nicht beschreibbar` | `chown -R 99:100 /mnt/user/appdata/claude-server` |
| `login expired` | `docker exec -it Claude-Server claude` → `/login` |
| `Remote Control beendet … Neustart in 60 s` | meist kurz kein Netz, er startet von selbst neu |
| Docker-Tab zeigt *unhealthy* | `docker exec Claude-Server gesund` aufrufen: `nicht angemeldet` = [Erste Anmeldung](#erste-anmeldung) durchführen; `Remote Control laeuft nicht` = Log ansehen |
| Unraid zeigt bei Update „not available“ | Ist das GitHub-Paket öffentlich? (GitHub → Packages → claude-server → Package settings) |

## Lizenz

MIT
