# CLAUDE.md – dumpen

Guidance for Claude Code in `pissmyran/dumpen`. The service dumpen: an image gallery for app icons and themes on Cloudflare R2, plus a Docker image for self-hosting.

The shared rules for all repos live in [STYRNING.md](https://github.com/pissmyran/.github/blob/main/STYRNING.md) in `pissmyran/.github`. The core rules below are a verbatim copy and stay in Swedish, because the copy is compared character by character with the source. Compare the version in the marker with the source at the start of every session (`curl -sS https://raw.githubusercontent.com/pissmyran/.github/main/STYRNING.md`); if the copy is older, update it first in a separate PR (`docs: sync core rules from .github`).

## Core rules

<!-- kärnregler:start version=2026-10-28 källa=https://github.com/pissmyran/.github/blob/main/STYRNING.md -->
1. **Inga personliga värden.** Repot är publikt. Skriv aldrig in riktiga id:n, domäner, e-postadresser, namn, nycklar, betallänkar eller kontouppgifter i kod, konfiguration, tester, dokumentation eller commit-meddelanden. Använd platshållare och `example.com`-värden.
2. **Inga hemligheter.** Tokens, lösenord, sessioner och nycklar hamnar aldrig i Git, loggar, issues eller publik dokumentation. Hemligheter läggs in utanför repot (Cloudflare, GitHub-miljöer, `wrangler secret put`).
3. **Gren och pull request.** Varje session börjar från senaste `main` (`git fetch origin main`) på en egen gren. `main` ändras bara genom en PR som squash-mergas. Ingen pushar direkt till `main`. En sessions arbete hålls i en PR.
4. **Testa lokalt före varje push.** Det finns inga testkontroller i CI. Repots egna tester och kontroller (avsnittet Kommandon i repots `CLAUDE.md`) är den enda testgrinden. Pusha aldrig med fallerande tester, och skriv tester för det du ändrar.
5. **Rör aldrig workflows.** `.github/workflows/`, `.github/actions/` och `CODEOWNERS` ändras inte av Claude, inte ens för att laga ett fel. Ingen kontroll stoppar det längre, men regeln gäller fullt ut. Behövs en ändring: beskriv den i ett issue och låt ägaren göra den. Bara Renovate och Dependabot får uppdatera dem.
6. **Granskning.** CodeRabbit, Sourcery och Codex granskar, och CodeQL (GitHubs standardinställning) skannar. Varje granskningstråd måste lösas innan merge. Svara i tråden med vad du ändrade, eller med skälet om fyndet är brus.
7. **Auto-merge sist.** Slå på auto-merge först när granskningsbotarna har granskat den senaste commiten (CodeRabbit hoppar över `docs/` och `*.md`; för sådana ändringar räcker Sourcery och Codex), alla trådar är lösta och alla kontroller som körs på PR:en är gröna, även de som reglerna inte kräver (till exempel `Dokumentation`).
8. **Laga orsaken, inte symptomet.** När något fallerar eller en granskning kräver ändring: läs allt, hitta orsaken och gör om den delen rätt. Små uppenbara fel får rättas direkt. Försvaga aldrig ett test, hoppa aldrig över en kontroll och tysta aldrig en varning.
9. **Säkerhet först.** Säkerhetslarm (CodeQL, Dependabot, Renovate) går före annat arbete. Länka issuet med `Closes #n`.
10. **Senaste versionerna.** Lägg aldrig till nya låsningar till ett versionsnummer; använd `@latest`, `node`, `latest` och versionsintervall. Befintliga låsningar som Renovate håller aktuella (till exempel `packageManager`, `requirements-docs.txt`, `.node-version`, lockfiler och actions låsta med commit-SHA) behålls och ändras bara av Renovate.
11. **Commits och titlar.** Sessionen signerar commits själv. Ändra aldrig gits användare, e-post eller signering, och använd aldrig `--no-verify`. PR-titeln blir commiten på `main` och skrivs på engelska enligt Conventional Commits: `typ: beskrivning` eller `typ(område): beskrivning`, med typ feat, fix, docs, refactor, perf, test, build, ci, chore, style eller revert.
12. **Dokumentation i samma PR.** Ändras beteende, inställningar eller kommandon uppdateras `README.md`, `docs/` och repots `CLAUDE.md` i samma PR.
13. **Inga lösa grenar.** Radera grenen när PR:en är mergad eller stängd. PR:er från forkar är förslag: gör ändringen själv på en egen gren om den är önskad, och stäng originalet med tack och länk.
14. **Noll kronor.** Slå aldrig på något som kan kosta pengar.
15. **GitHub bara via REST.** `gh pr` och `gh issue` fungerar inte i molnsessioner (GraphQL är avstängt). Använd `gh api` och de särskilda `ccr`-vägarna; se avsnittet GitHub från sessionen.
<!-- kärnregler:slut -->

## About the repo

One of four sibling repos (`dumpen`, `jobb`, `klarsprak`, `politiker`) that share the same pattern for placeholders, deploy, Docker and documentation. Read `AGENTS.md`, `README.md` and `docs/` before larger changes.

| Directory | Entry | Handlers | Bindings |
|---|---|---|---|
| `.` | `src/index.js` (built by `build.mjs`) | fetch | R2 for the gallery and an older bucket, Secrets Store |

## Commands

Test and check syntax:

```bash
npm test && npm run check
```

Also run, for what you changed: `npx --yes prettier@latest --check .` (settings in `.prettierrc.json`, line width 100; fix with `--write`), `shellcheck` on `.sh` files and `jq empty` on `.json` files. Tests that read source files must not depend on formatting; call the real code instead.

## Rules for this repo

- **Language:** everything in this repo is English, including the documentation, PR titles and bodies, commit messages, review replies and labels. Only the core rules block above stays in Swedish. The app's interface and older code comments are still Swedish; translate comments when you touch the file, and change the interface language only as its own task.

## Architecture

- **The build:** `src/index.js` is written for Workers Static Assets. What gets deployed is `dist/worker.js`, which `build.mjs` builds with `public/` embedded. Change the source, never `dist/`.
- **Access:** only `/bilder/*` is public. Everything else requires an Access JWT, or a password session with `AUTH_MODE=password` when self-hosting. Never set `AUTH_MODE` or `LOCAL_DEV` in production.
- **R2 is scanned incrementally:** metadata is saved on write, the edge cache is used, and a range read happens only once per object version. No full rescan per request.

## Placeholders and deploy

- **The code is generic** and only contains `__NAME__` placeholders. Every placeholder in use must be declared in `cloudflare.example.env` with a sample value and a comment on where the real value comes from.
- **`node tools/render.mjs <values.env | -> <outdir> [overlay]`** copies the repo, fills in every declared placeholder (and stops if a value is missing), lays the overlay directory on top, removes routes with an empty pattern and links `node_modules`. With `-` the values come from environment variables.
- **Production** is deployed by Workers Builds (Cloudflare's GitHub connection) when a PR is merged to `main`, with the values as build variables in Cloudflare: build with `node tools/render.mjs - build`, deploy with `npx wrangler deploy --cwd build`. Only `main` is built.
- **Self-deploying** from a private value file works the same way: render, run `npx wrangler deploy --cwd build` and throw away the rendered copy. Secrets are added with `npx wrangler secret put`.
- **Migrations:** deploy the new Worker before running a migration that drops tables or columns.
- **Tests** run on the unrendered source and therefore see the placeholders.

## Cost and logging

- **The free plan:** aim for Workers Free, 10 ms CPU per request. No full inventory or rescan per cron run, request or added object; work incrementally and save derived data when it is written.
- **Logging:** logs with sampling 1 and invocation logs, traces 0.01, query strings masked and Workers Issues on. Log errors and warnings and at most one or two lines per run. Handled errors only reach Issues through `console.error`.

## Documentation

`README.md`, `docker/README.md` and `docs/` are also the documentation site on GitHub Pages (`pissmyran.github.io/dumpen`), built with Zensical (`zensical.toml`, `requirements-docs.txt`) and published from `main` by `.github/workflows/pages.yml`. The app sits behind Cloudflare Access, so the documentation is only published on GitHub.

- **Build locally:** install Zensical with `pip install -r requirements-docs.txt` (preferably in a virtual environment), then run `node tools/docs-site.mjs && zensical build` (output in `site/`). `tools/docs-site.mjs` makes the README the home page and points links to files outside the site at GitHub.
- **The wiki** is mirrored one way by `.github/workflows/wiki.yml`. Never edit the wiki.
- **The README** must keep the `**Documentation:**` line at the top. New pages under `docs/` go into `nav` in `zensical.toml`; their titles also become the wiki page names.

## Docker and release

- **Files:** `Dockerfile` (build from the root: `docker build -t dumpen .`), `docker-compose.yml`, `CHANGELOG.md` and `docker/` (`README.md` is the Docker Hub page, plus `entrypoint.sh`, `import-settings.sh` and the container's wrangler configuration).
- **Runtime:** the Worker runs in workerd through `wrangler dev --local` with all state under `/data`. The entrypoint renders the source with `tools/render.mjs` from the container's environment, with defaults that work out of the box, and generates missing encryption keys once into `/data`. Existing keys are never overwritten. The images start empty and never read from anyone's Cloudflare resources.
- **Settings** come from `docker-compose.yml`, or once from `/data/import.env`, which `import-settings.sh` merges into `/data/settings.env` and then deletes. Non-empty compose variables win.
- **Keep in sync:** `docker/README.md`, `docker-compose.yml` and `CHANGELOG.md` must agree with each other. The documentation names the Docker Hub image to use in compose instead of building from the repo.
- **Release:** bump the version in `package.json` in the PR following semver and add `## X.Y.Z – YYYY-MM-DD` to `CHANGELOG.md`. When the PR reaches `main`, `release.yml` creates the tag and release and calls `docker.yml`, which publishes `X.Y.Z`, `X.Y`, `X` and `latest` to Docker Hub. A merge without a version bump releases nothing. If the Docker job fails, re-run the failed jobs in the release run ("Re-run failed jobs"). If the release stopped after the tag was created, run `docker.yml` manually (workflow_dispatch on the tag); otherwise no image is published. If the session lacks permission, ask the owner. The workflow files are never changed.

## Review in this repo

- **Gate:** `main` requires a PR, linear history, resolved review threads and CodeQL without errors or serious alerts. No other checks are required, but the ones that run must be green. The local tests under Commands are the test gate.
- **CodeRabbit:** inherits the central configuration in `pissmyran/coderabbit`. The repo's `.coderabbit.yaml` points out risk areas with their own review instructions; read the part for the files you change before you start.
- **Sourcery and Codex:** also review, as GitHub apps without their own configuration here, and they review documentation too. Treat their threads like CodeRabbit's.
- **Extra care:** access control, R2 scanning and ZIP import.

## GitHub from a session

GraphQL is disabled, so `gh pr` and `gh issue` do not work. Use REST:

- Open a PR: `gh api repos/pissmyran/dumpen/pulls -f base=main -f head=<branch> -f title='…' -f body='…'`
- PR from a branch: `gh api 'repos/pissmyran/dumpen/pulls?head=pissmyran:<branch>&state=open'`
- Issue: `gh api repos/pissmyran/dumpen/issues/<n>` and `…/issues/<n>/comments`
- Review threads: `gh api repos/pissmyran/dumpen/pulls/<n>/ccr/review_threads`
- Reply in a thread: `gh api repos/pissmyran/dumpen/pulls/<n>/comments/<id>/replies -f body='…'`
- Resolve a thread: `gh api -X POST repos/pissmyran/dumpen/pulls/<n>/ccr/comments/<id>/resolve`
- Checks: `gh api repos/pissmyran/dumpen/commits/<sha>/check-runs`
- Enable auto-merge: `gh api -X PUT repos/pissmyran/dumpen/pulls/<n>/ccr/auto_merge -f merge_method=squash`
- If the PR is already mergeable (auto-merge is then refused), squash-merge directly: `gh api -X PUT repos/pissmyran/dumpen/pulls/<n>/merge -f merge_method=squash`
- Close a PR: `gh api -X PATCH repos/pissmyran/dumpen/pulls/<n> -f state=closed`
- Delete a branch: GitHub deletes the branch on merge. A closed PR's branch is deleted with `git push origin --delete <branch>` (the API route is blocked).
