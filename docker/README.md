# Dumpen

Dumpen is a private image archive for app icons and theme images. You upload PNG images (512 × 512 or 1254 × 1254), one at a time or many at once as a ZIP. Dumpen recognizes the app, theme and resolution by itself and files the images. Every image gets a stable public link, and whole themes can be downloaded as a ZIP.

Every image is public through its link, `/bilder/...`. Everything else, meaning the gallery, upload and delete, requires sign-in.

## Getting started

The image is on Docker Hub as `docker.io/driftaegis/dumpen`. The compose file below pulls it from there, so you neither clone the repo nor build anything.

1. **Install Docker.** On Windows and Mac: [Docker Desktop](https://www.docker.com/products/docker-desktop/). On Linux: the `docker.io` package (Debian/Ubuntu) or equivalent. Podman works too.
2. **Create a folder** with a file in it named `docker-compose.yml`. Paste the content below.
3. **Fill in** `PUBLIC_URL` (the address you open Dumpen at) and your own `ADMIN_PASSWORD` of at least 8 characters.
4. **Start** it in that folder: `docker compose up -d`
5. **Open** the address and sign in with the password.

```yaml
services:
  dumpen:
    image: docker.io/driftaegis/dumpen:2
    restart: unless-stopped
    ports:
      - "8787:8787"
    environment:
      PUBLIC_URL: "http://localhost:8787"
      AUTH_MODE: "password"
      ADMIN_PASSWORD: "change-me-to-a-long-password"
      CF_ACCESS_TEAM_DOMAIN: ""
      CF_ACCESS_AUD: ""
      WORKERS_API_TOKEN: ""
      CLOUDFLARE_ACCOUNT_ID: ""
    volumes:
      - dumpen-data:/data

  tunnel:
    image: docker.io/cloudflare/cloudflared:latest
    profiles: ["tunnel"]
    restart: unless-stopped
    command: tunnel --no-autoupdate run
    environment:
      TUNNEL_TOKEN: ""
    depends_on:
      - dumpen

volumes:
  dumpen-data:
```

## Sign-in: two ways

Choose with `AUTH_MODE`.

**`password`** (default): a sign-in page with the password in `ADMIN_PASSWORD`. The session lasts 30 days. Changing the password signs everyone out.

**`cloudflare-access`**: Cloudflare Access handles sign-in, with an email code, Google or another identity provider. Dumpen checks the signed Access token itself, so anyone who gets past Access is still not let in. It needs a Cloudflare account with a domain:
1. **Create a tunnel.** Go to Zero Trust → Networks → Tunnels, create a tunnel and point a public hostname at `http://dumpen:8787`. Copy the tunnel token to `TUNNEL_TOKEN`.
2. **Create an Access application.** Go to Zero Trust → Access → Applications, add a *self-hosted* application for the same hostname and create a policy for who may sign in.
3. **Fill in the compose file.** Copy the application's *Application Audience (AUD) Tag* to `CF_ACCESS_AUD` and the team domain (`yourteam.cloudflareaccess.com`) to `CF_ACCESS_TEAM_DOMAIN`. Set `AUTH_MODE: "cloudflare-access"` and `PUBLIC_URL` to the public hostname.
4. **Add an exception for the images.** Create an Access application for `<hostname>/bilder/*` with the policy *Bypass → Everyone*. If the zone has *Hotlink Protection* turned on, a configuration rule that turns it off for `/bilder/` is also needed, or the images will not show on other sites such as App Launcher.
5. **Start with the tunnel:** `docker compose --profile tunnel up -d`

## Settings

| Variable | Required | Default | Meaning |
|---|---|---|---|
| `PUBLIC_URL` | Yes | `http://localhost:8787` | The address Dumpen is reached at. Image links are built from it, so give the public address if the images will be used outside your network. |
| `AUTH_MODE` | No | `password` | `password` or `cloudflare-access`. |
| `ADMIN_PASSWORD` | With `password` | – | At least 8 characters, preferably much longer. |
| `CF_ACCESS_TEAM_DOMAIN` | With `cloudflare-access` | – | For example `yourteam.cloudflareaccess.com`. |
| `CF_ACCESS_AUD` | With `cloudflare-access` | – | The Access application's AUD tag. |
| `WORKERS_API_TOKEN` | No | – | Only for the "Use in App Launcher" feature (the *Använd i App Launcher* button), which applies a theme's icons to your Cloudflare Access apps. Permission: *Access: Apps: Edit*. |
| `CLOUDFLARE_ACCOUNT_ID` | No | – | Your Cloudflare account id, for the same feature. |
| `TUNNEL_TOKEN` (the `tunnel` service) | No | – | Token for Cloudflare Tunnel. |
| `PORT` | No | `8787` | The port inside the container. |

### Settings from a file instead

If you do not want values such as passwords in the compose file, put them as `NAME=value` lines in the file `import.env` in the data volume (the one mounted at `/data`) and restart the container. At start the values are saved to `/data/settings.env`, which only the container can read, and `import.env` is deleted. To change a value later, add a new `import.env` with just that line. A line with `NAME=` and no value removes the setting. Values filled in in the compose file take precedence over saved values.

## Data, backup and updates

- The images live in the volume mounted at `/data`, as local R2 storage under `/data/v3/r2/`. Metadata about app, theme and size follows each image.
- **Back up:** `docker compose stop`, copy the volume and run `docker compose start`. You can also download each theme as a ZIP in the interface. That ZIP file can be imported again exactly as it is.
- **Update:** `docker compose pull && docker compose up -d`.
- **Versions:** the tags follow semver. `1` gives every update within version 1, `1.2` only fixes and `1.2.0` exactly one version.

## HTTPS

The container speaks plain HTTP on port 8787. With `cloudflare-access` the tunnel handles HTTPS. With `password` and access from outside, you need a reverse proxy with a certificate, for example Caddy, Traefik or nginx. The session cookie gets the `Secure` flag automatically when the page is reached over HTTPS.

## Technical overview

- **Runtime:** Dumpen is written as a Cloudflare Worker. In the container it runs in `workerd`, the same runtime Cloudflare uses, through `wrangler dev --local` (Miniflare). The two R2 buckets (`gallery` and `legacy`) become local storage under `/data`. The `legacy` bucket is empty and only exists so the import feature works.
- **Password mode:** the session is a cookie (`HttpOnly`, `SameSite=Strict`) with an expiry and an HMAC-SHA256 signature keyed with `ADMIN_PASSWORD`. Password and signature are compared in constant time, and a wrong password adds a delay. No session data is stored on the server.
- **Access mode:** the RS256 signature is checked against the team's public keys, as are the issuer, AUD and expiry.
- **Changes:** every changing request requires same-origin. Responses have a strict CSP and the other security headers. Images are only served with `GET` and `HEAD`, and only for allowed paths and file types.
- **The image** is based on `node:24-trixie-slim` (Node LTS on Debian stable), runs as the `node` user and has a healthcheck. It only contains source code with placeholders; your values are filled in when the container starts.
- **Limits:** `wrangler dev` is a development server that runs one process on one machine. That is enough for a private image archive but gives neither Cloudflare's scaling nor its CDN. Images are only cached with ordinary `Cache-Control` headers.
- **Troubleshooting:** `docker compose logs -f`.

## Changelog

**2.0.0**
- The token for "Use in App Launcher" is now called `WORKERS_API_TOKEN`, the same name as on Cloudflare. Rename `CLOUDFLARE_API_TOKEN` in your compose file or `import.env`; the old name is no longer read. Also change the tag to `:2` in the compose file, since `:1` stays on version 1.

**1.3.3**
- The image is based on `node:24-trixie-slim`: Node 24 (LTS) on Debian 13 (stable).

**1.3.2**
- `tools/render.mjs` writes each filled-in file in a loop until every byte is written, so a short write cannot leave a truncated file.

**1.3.1**
- Image URLs from the API are only used if they are http(s), so a stored value can never become script in the gallery.
- The Access app sync no longer sends raw error values to the browser.
- `tools/render.mjs` reads and writes each file through the same file descriptor, so the file cannot be swapped between the check and the write.

**1.3.0**
- Settings can be given once in `/data/import.env` instead of in the compose file. They are saved to `/data/settings.env` and the import file is deleted.
- The image is built from the project's own repo: `docker build -t dumpen .`.

**1.2.0**
- First Docker image, with R2 under `/data`.
- Sign-in through `AUTH_MODE`: `password` or `cloudflare-access`, with an optional Cloudflare Tunnel.
- The "Use in App Launcher" feature accepts a plain API token.
- Applying a theme no longer saves a backup. The result is confirmed and re-read from Cloudflare.
- On ZIP import, a theme folder without a name, or with a generic name, is named after the ZIP file.
- Filter view for images and a theme library with ZIP download and delete. Images are catalogued automatically on import.

## License

MIT. The bundled component `pako` is MIT licensed as well.
