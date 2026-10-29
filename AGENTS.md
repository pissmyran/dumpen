# AGENTS.md – dumpen

An image gallery for app icons and themes on Cloudflare R2, plus a Docker image for self-hosting.

Read the shared rules at the start of every session: [GOVERNANCE.md](https://raw.githubusercontent.com/pissmyran/.github/main/GOVERNANCE.md) and [SERVICES.md](https://raw.githubusercontent.com/pissmyran/.github/main/SERVICES.md). Read `README.md` before larger changes.

## Commands

```bash
npm test && npm run check
```

## Rules

- **Entry:** `src/index.js`, built by `build.mjs`. Bindings: R2 for the gallery and an older bucket, Secrets Store.
- **The build:** `src/index.js` is written for Workers Static Assets. What gets deployed is `dist/worker.js`, which `build.mjs` builds with `public/` embedded. Change the source, never `dist/`.
- **Access:** only `/bilder/*` is public. Everything else requires a Cloudflare Access JWT, or `AUTH_MODE=password` when self-hosting. Never set `AUTH_MODE` or `LOCAL_DEV` in production.
- **R2 is scanned incrementally:** metadata is saved on write, the edge cache is used, and a range read happens only once per object version. No full rescan per request.
- **Release:** the version is in `package.json`.
- **Language:** the app's interface and older code comments are Swedish. Write every new or changed comment in English and change the interface language only as its own task.
- **Documentation:** the app sits behind Access, so the documentation is published only on GitHub.
- **Extra care:** access control, R2 scanning and ZIP import.
