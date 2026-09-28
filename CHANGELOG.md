# Changelog

🇬🇧 **English** · 🇩🇪 [Deutsch](CHANGELOG.de.md)

## 2026-09-28
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
