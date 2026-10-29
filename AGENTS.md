# AGENTS.md

- The shared rules for workflow, deploy, logging, cost and Docker are in [CLAUDE.md](CLAUDE.md). Each session works on its own branch; `main` only changes through a PR from that branch with a squash merge.
- Read [README.md](README.md) before larger changes.
- `src/index.js` is written for Workers Static Assets. What gets deployed is `dist/worker.js`, which `build.mjs` builds with `public/` embedded and the production variables injected. Change the source, not `dist/`.
- Only `/bilder/*` is public. Everything else requires sign-in: a Cloudflare Access JWT in production, or `AUTH_MODE=password` in a self-hosted install. Never set `AUTH_MODE` or `LOCAL_DEV` in production.
- Scan R2 incrementally: dimensions come from `customMetadata` or the edge cache, and a range read happens only once per object version. No full rescan per request.
- Run `npm test` before pushing.
- The code contains no personal values, only placeholders (`__NAME__`) declared in `cloudflare.example.env` and filled in by `tools/render.mjs` at deploy and by `docker/entrypoint.sh` in the container. See the rule in `CLAUDE.md`. Update `CHANGELOG.md` and the version in `package.json` for every new image.
- Never put API tokens or other secrets in the repository or public documentation.
- Everything is written in English.
