# Changelog

Versions follow [semver](https://semver.org). The Docker image is tagged `X.Y.Z`, `X.Y`, `X` and `latest`.

## 1.3.0 – 2026-10-18

- Settings can be given once in `/data/import.env` instead of in `docker-compose.yml`: they are saved to `/data/settings.env`, readable only by the container, and the import file is deleted. `NAME=` removes a setting; non-empty compose variables still win.
- The project now lives in its own repository, so the image builds from the repo root with `docker build -t dumpen .`.

## 1.2.0 – 2026-10-17

- First Docker image: the Worker runs in workerd via `wrangler dev --local`, with the R2 buckets stored under `/data`.
- `AUTH_MODE` chooses the login: `password` (built-in login page and session cookie) or `cloudflare-access` (Access JWT, as on Cloudflare). `docker-compose.yml` has an optional Cloudflare Tunnel service for the Access route.
- The App Launcher theme feature also accepts a plain API token (`CLOUDFLARE_API_TOKEN`) instead of a Secrets Store binding.
- Applying a theme no longer writes a backup; the result is confirmed and re-read from Cloudflare.
- ZIP import names a missing or generic theme folder after the ZIP file.
- Image filter view, theme library with ZIP download and delete, and automatic cataloguing on R2 import.
- R2 scans are incremental instead of rescanning everything.
