# Changelog

🇬🇧 **English** · 🇩🇪 [Deutsch](CHANGELOG.de.md)

## 2026-10-03
- Container watchdog: also checks containers that must run without Unraid autostart (`MUSS_LAUFEN`, default: Nextcloud AIO parts; paused during AIO backup) and filesystem usage (`PLATZ`, default `/var/log` 80 %, Docker vDisk 85 %).

## 2026-09-29
- Unraid template `unraid/claude-server.xml` with the recommended security settings (`--cap-drop=ALL`, `no-new-privileges`, memory/CPU limits).
- README: installation via template, explanation of the extra parameters.

## 2026-09-28
- Container watchdog: notifications are optional (`MELDEN`, `ENTWARNUNG`); everything is always written to the system log.
- `unraid/container-waechter.sh`: optional watchdog for the Unraid host (unhealthy / stopped autostart containers → Unraid notifications, German or English).
- Health check: Unraid shows *healthy*/*unhealthy* (`gesund`, every 60 s, 3 retries, 5 min start period).
- Documentation now in English (`README.md`, `CHANGELOG.md`) and German (`README.de.md`, `CHANGELOG.de.md`).
- Documentation-only changes no longer trigger an image rebuild.

## 2026-09-28
- Base image switched from `debian:bookworm-slim` to `debian:stable-slim` (always the current Debian release).
- Tools added: openssh-client, python3, iputils-ping, dnsutils, netcat-openbsd, iproute2, less, file, unzip.
- `notschluessel`: SSH emergency key, generated per installation and normally not active.
- GitHub builds the image automatically (monthly and on every change) so Unraid shows updates.
- Documentation (README) written.

## 2026-09-28 (first version)
- Claude Code is no longer baked into the image; it is installed into `/config/.local` on first start and updates itself.
- Remote Control as an always-on service, deliberately without `--dangerously-skip-permissions`.
