# Dumpen

**Documentation:** [pissmyran.github.io/dumpen](https://pissmyran.github.io/dumpen/) – home, documentation and Docker on one searchable site.

Dumpen is a private image archive for app icons and theme images. It runs as a Cloudflare Worker with the images in R2 and sign-in through Cloudflare Access. It needs no database, KV or queue.

## Features

- **Gallery** with an overview, app images, theme images, grid and list views, search, sorting and filters for app, theme and size.
- **Upload** of PNG images at exactly 512 × 512 or 1254 × 1254 pixels, at most 12 MB. The size is read from the image's own bytes, not from the file name.
- **ZIP import** of many images at once, with a review list before uploading.
- **Theme library** where a whole theme can be downloaded as a ZIP or deleted.
- **Stable public links** to every image, to paste into for example an app's logo field.
- **Use in App Launcher** (the *Använd i App Launcher* button; the interface is in Swedish): applies a theme's icons to the Cloudflare Access apps (optional, needs an API token).
- **Import from an older bucket:** images in an existing R2 bucket can be listed and copied in without changing the originals.
- Works on mobile and with a keyboard. No external libraries or CDN; the Worker serves everything.

## How it works

- **Sign-in:** everything except `/bilder/*` requires a valid Cloudflare Access JWT. The Worker checks the signature, issuer, AUD and expiry itself, also for the static pages.
- **Public images:** `/bilder/*` is open for reading (`GET` and `HEAD`) and needs its own Access application for that path with the policy *Bypass → Everyone*. If the zone has *Hotlink Protection* turned on, a configuration rule that turns it off for `/bilder/` is also needed, or the images will not show on other sites.
- **Storage:** new images are saved under `gallery/` in the gallery bucket:

  ```text
  gallery/apps/<app>/<app>-512x512-<id>.png
  gallery/themes/<theme>/<app>/<theme>-<app>-1254x1254-<id>.png
  ```

  App, theme and size are also saved as metadata on each image, so the listing never needs to read the images again.
- **Older bucket:** images under `apps/` and `uploads/` in the older bucket are shown under `/bilder/apps/…` and `/bilder/uploads/…` and can be copied to `imported/` in the gallery bucket. Nothing in the older bucket is overwritten.

## ZIP import

The archive is unpacked in the browser with the bundled `pako` decoder. Each PNG is then sent on its own through `POST /api/upload`, so the server checks size, file type, resolution and name exactly as for a normal upload.

App and theme are read from the folder or file names:

- `apps/<app>/<app>-512.png` → `gallery/apps/<app>/…`
- `themes/<theme>/<app>/<app>-1254.png` → `gallery/themes/<theme>/<app>/…`
- `<app>-512.png` → `gallery/apps/<app>/…`
- `<app>-<theme>-512.png` → `gallery/themes/<theme>/<app>/…`

The folder names `appar` and `teman` work too. Ambiguous names must be fixed in the review list; no image is guessed into the wrong app. Rows can be deselected, and failed rows can be sent again without duplicating saved images.

**Limits:** at most 80 MB per ZIP, 100 images and 140 MB of unpacked data, at most 12 MB per image, only 512 × 512 or 1254 × 1254. Archives with unsafe paths are stopped. Folders, text files and macOS system files in the archive are skipped.

## Local development

1. `npm install`
2. Create a local `.dev.vars` with the line `LOCAL_DEV=true`. It turns off the Access check for `localhost` and must never exist in production.
3. `npm run dev`

## Tests

```bash
npm test && npm run check
```

## Deploying to your own Cloudflare account

The code contains no account details. Wherever a value of your own is needed, such as a domain, a resource id or keys, there is a placeholder (`__NAME__`). Every placeholder is listed in `cloudflare.example.env`, with a comment on where the value comes from. The values only end up in Cloudflare, never in the repo.

**Option 1: deploy from your own computer.**

1. Copy `cloudflare.example.env` to a file of your own outside the repo and fill in your values.
2. Render a copy with your values: `node tools/render.mjs <your-file.env> build [overlay-dir]`. The tool stops if a value is missing. Files in the overlay directory are copied on top, for example your own images.
3. Add the token for the App Launcher feature as the secret `WORKERS_API_TOKEN` in Secrets Store (optional).
4. Deploy: `npx wrangler deploy --cwd build`.
5. Delete `build/`.

**Option 2: Workers Builds with the GitHub connection.** Add the values as *build variables* in Cloudflare (Workers → your Worker → Settings → Build), set the build command to `node tools/render.mjs - build` and the deploy command to `npx wrangler deploy --cwd build`. Build only the production branch, so no preview versions are created.

## Running with Docker

Dumpen is available as a ready-made image on Docker Hub, `docker.io/driftaegis/dumpen`. You do not need to build anything: `docker-compose.yml` names the image like this, and `docker compose up -d` pulls it.

In `docker-compose.yml`:

```yaml
    image: docker.io/driftaegis/dumpen:2
```

The tag `2` gives every update within version 2; `X.Y` gives only fixes and `X.Y.Z` exactly one version. Every setting is described in [docker/README.md](docker/README.md), and the changes are listed in [CHANGELOG.md](CHANGELOG.md). To build the image yourself from source: `docker build -t dumpen .` in the repo root.

## Contributing

Questions and ideas go to [Discussions](https://github.com/pissmyran/.github/discussions), bugs and suggestions as issues here. Read [CONTRIBUTING.md](https://github.com/pissmyran/.github/blob/main/CONTRIBUTING.md) before opening a pull request. Report security problems privately through the Security tab.

## License

MIT, see [LICENSE](LICENSE). The bundled `pako` is MIT licensed, see [PAKO-LICENSE.txt](PAKO-LICENSE.txt).
