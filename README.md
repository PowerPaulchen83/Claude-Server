# claude-server

🇬🇧 **English** · 🇩🇪 [Deutsch](README.de.md)

Claude Code as an **always-on service on an Unraid server**. You talk to it via
[Remote Control](https://code.claude.com/docs/en/remote-control) from your phone
(Claude app) or from claude.ai/code. It runs around the clock without an open terminal.

> Private hobby project, no warranty. Read the [Security](#security) section
> before using it.
>
> Log messages and helper scripts are in German. The troubleshooting table below
> lists the German log lines with their meaning.

---

## Contents

- [What the container does](#what-the-container-does)
- [Security](#security)
- [Installation on Unraid](#installation-on-unraid)
- [First login](#first-login)
- [Updates](#updates)
- [SSH emergency key](#ssh-emergency-key)
- [Container watchdog (optional)](#container-watchdog-optional)
- [Files in this project](#files-in-this-project)
- [Troubleshooting](#troubleshooting)

---

## What the container does

- On first start it installs Claude Code with the official installer into `/config/.local`.
  After that, **Claude Code updates itself**. No new image is needed for that.
- It runs `claude remote-control` in a loop. If the connection drops, it restarts after 60 s.
- Login, settings and memory live in `/config` (appdata), **never in the image**.
- A **health check** runs every 60 s: Unraid shows the container as *healthy* while Remote Control is running, and *unhealthy* after about 3 minutes without it.
- The image itself only contains Debian (`stable-slim`) and a few tools:
  git, ripgrep, curl, jq, ssh client, python3, ping, dig, nc, ip, less, file, unzip.

## Security

Principle: **Claude may do little. More is only possible when the owner explicitly unlocks it.**

| What | How it is handled here |
|---|---|
| Confirmations | Runs **without** `--dangerously-skip-permissions`. Every change has to be approved on the phone. |
| User | Runs as `99:100` (Unraid `nobody:users`), not as root. |
| Docker | **No** Docker socket. Whoever has the socket is effectively root on the server, even if it is mounted "read-only". |
| Files | Only `/config` (the container's appdata) and `/workspace` (one working folder). No other shares. |
| Ports | None. Remote Control only opens an **outbound** connection to Anthropic. |
| Credentials | None of them are in the image or in this project. The login is stored in `/config/.credentials.json`. |
| SSH | Own key per installation, **normally not active** (see [SSH emergency key](#ssh-emergency-key)). |

For server access Claude uses MCP servers (e.g. an Unraid MCP in read-only mode) that are
configured in `/config`. They are not part of this project.

**Recommendations:** Enable two-factor authentication for your Claude account and back up appdata.

## Installation on Unraid

1. Create the folder (Unraid terminal):
   ```bash
   mkdir -p /mnt/user/appdata/claude-server
   chown 99:100 /mnt/user/appdata/claude-server
   ```
2. **Docker → Add Container**:

   | Field | Value |
   |---|---|
   | Name | `Claude-Server` |
   | Repository | `ghcr.io/powerpaulchen83/claude-server:latest` |
   | Network Type | `bridge` |
   | Path `/config` | `/mnt/user/appdata/claude-server` (rw) |
   | Path `/workspace` | a working folder, e.g. `/mnt/user/…/Claude` (rw) |
   | Extra Parameters | *(empty)* |

3. **Apply**. The log will then say „Noch nicht angemeldet …“ (not logged in yet). That is expected on first start.

## First login

Once, in the Unraid terminal:

```bash
docker exec -it Claude-Server claude
```
1. Type `/login`, open the link on your PC, paste the code.
2. Trust the folder `/workspace`, then `/exit`.

```bash
docker exec -it Claude-Server claude remote-control
```
3. Answer „Enable Remote Control? (y/n)“ with `y`, then press `Ctrl+C`.
4. Restart the container. Sessions appear in the Claude app with the name `server-…`.

## Updates

There are **two parts** that update separately:

| Part | How |
|---|---|
| Claude Code | automatically, by itself |
| Image (Debian + tools) | GitHub rebuilds it **on the 1st of every month** (and on every change except pure documentation). Unraid then shows an update in the Docker tab; one click on **Update** is enough. |

Manual rebuild: on GitHub under **Actions → Image bauen → Run workflow**.

> **Note:** If nothing changes in the project for 60 days, GitHub pauses the monthly
> schedule and sends an email. Re-enable it under **Actions → Image bauen → Enable workflow**.

**Fallback without GitHub:** build on the Unraid server itself:
```bash
bash "/path/to/this/folder/neu-bauen.sh"
```
Then in the Docker tab: container → **Edit → Apply**.

## SSH emergency key

For real emergencies Claude can reach the Unraid host via SSH, **but only while the owner
has the key unlocked**.

- **Every installation generates its own key.** There is **no** key in the image or in this
  project. There is no default key.
- The private part stays in `/config/.ssh/` and never leaves the container.

**Emergency procedure**
1. Run `notschluessel` inside the container. The first run creates the key; later runs only print the line.
2. Add the printed line (starts with `from="…"`) in Unraid under
   **Users → root → SSH authorized keys**.
3. Claude does the one task, **every command only after confirmation**.
4. **Delete the line in Unraid again.** Access is closed.

`from="…"` means the key only works from the Docker network (default `172.17.0.0/16`).
If your network differs, set the container variable `NOTSCHLUESSEL_FROM`.

## Container watchdog (optional)

`unraid/container-waechter.sh` is a small script for the **Unraid host** (not for the container).
It sends a message through the normal Unraid notifications (e.g. Telegram, e-mail) when

- a container with a health check becomes **unhealthy** (e.g. this one), or
- a container with **Unraid autostart** is not running,

and one more message when everything is back to normal. It only alerts after the problem has lasted
for 2 runs in a row (about 10 min), so short interruptions such as the appdata backup stay quiet.

**Setup:** Settings → User Scripts → Add New Script → paste the file content →
schedule **Custom** `*/5 * * * *`.

**Options** (at the top of the script):

| Setting | Default | Meaning |
|---|---|---|
| `SPRACHE` | `de` | `en` for English messages |
| `MELDEN` | `ja` | `nein` (no) = **no notifications**, only a line in the Unraid system log |
| `ENTWARNUNG` | `ja` | `nein` (no) = no "back to normal" message, only problems |
| `SCHWELLE` | `2` | how many runs in a row (5 min each) a problem must last before it is reported |

Whether a notification reaches you via Telegram, e-mail or only in the browser is set in Unraid under
**Settings → Notifications** per level (the watchdog uses *warning* for problems and *notice* for "back to normal").

Example:
```
⚠️ PowerServer: Claude-Server is unhealthy
Unhealthy for about 10 min. Check says: krank: Remote Control laeuft nicht
```

## Files in this project

| File | Purpose |
|---|---|
| `Dockerfile` | build instructions for the image |
| `entrypoint.sh` | start script: installation, login check, Remote Control loop |
| `notschluessel.sh` | creates/shows the SSH emergency key (in the image as `notschluessel`) |
| `gesund.sh` | health check (in the image as `gesund`) |
| `unraid/container-waechter.sh` | optional watchdog for the Unraid host, see [Container watchdog](#container-watchdog-optional) |
| `neu-bauen.sh` | fallback: build the image on the Unraid server |
| `.github/workflows/bauen.yml` | GitHub builds and publishes the image |
| `CHANGELOG.md` | what changed when (German: `CHANGELOG.de.md`) |

## Troubleshooting

| Log says … | Meaning / fix |
|---|---|
| `Noch nicht angemeldet` (not logged in) | do the [first login](#first-login) |
| `/config ist nicht beschreibbar` (not writable) | `chown -R 99:100 /mnt/user/appdata/claude-server` |
| `login expired` | `docker exec -it Claude-Server claude` → `/login` |
| `Remote Control beendet … Neustart in 60 s` (ended, restart in 60 s) | usually a short network outage; it restarts by itself |
| Docker tab shows *unhealthy* | Run `docker exec Claude-Server gesund`: `nicht angemeldet` = do the [first login](#first-login); `Remote Control laeuft nicht` = check the log |
| Unraid shows „not available“ for updates | Is the GitHub package public? (GitHub → Packages → claude-server → Package settings) |

## License

MIT
