# CLAUDE.md – dumpen

Guidance for Claude Code in `pissmyran/dumpen`. The service dumpen: an image gallery for app icons and themes on Cloudflare R2, plus a Docker image for self-hosting.

The shared rules for all repos live in [GOVERNANCE.md](https://github.com/pissmyran/.github/blob/main/GOVERNANCE.md) in `pissmyran/.github`. The core rules below are a verbatim copy. At the start of every session, compare the version in the marker with the source:

```sh
curl -fsS https://raw.githubusercontent.com/pissmyran/.github/main/GOVERNANCE.md
```

If the copy is older, update it first in a separate PR (`docs: sync core rules from .github`).

## Core rules

<!-- core-rules:start version=2026-10-29 source=https://github.com/pissmyran/.github/blob/main/GOVERNANCE.md -->
1. **No personal values.** The repository is public. Never write real IDs, domains, email addresses, names, keys, payment links or account details in code, configuration, tests, documentation or commit messages. Use placeholders and `example.com` values.
2. **No secrets.** Tokens, passwords, sessions and keys never end up in Git, logs, issues or public documentation. Secrets live outside the repository (Cloudflare, GitHub environments, `wrangler secret put`, the sandbox proxy).
3. **Stay in scope.** Work only in the repositories you were assigned. Never ask for broader token permissions. If a task needs more, describe it in an issue and let the owner decide.
4. **Branch and pull request.** Every session starts from the latest `main` (`git fetch origin main`) on its own branch. `main` changes only through a squash-merged pull request. Nobody pushes directly to `main`. One session's work stays in one pull request.
5. **Test locally before every push.** CI runs no test checks. The repository's own tests and checks (the Commands section of its `CLAUDE.md`) are the only test gate. Never push with failing tests, and write tests for what you change.
6. **Never touch workflows.** Do not change `.github/workflows/`, `.github/actions/` or `CODEOWNERS`, not even to fix an error. The token has no Workflows permission, so such a push is rejected. If a change is needed, describe it in an issue and let the owner make it. Only Renovate and Dependabot update them.
7. **Review.** CodeRabbit, Sourcery and Codex review, and CodeQL (GitHub default setup) scans. Resolve every review thread before merge. Reply in the thread with what you changed, or with the reason if the finding is noise.
8. **Auto-merge last.** Enable auto-merge only when the review bots have reviewed the latest commit (CodeRabbit skips `docs/` and `*.md`; for those changes Sourcery and Codex are enough), all threads are resolved and every check that runs on the pull request is green, including checks the rules do not require.
9. **Fix the cause, not the symptom.** When something fails or a review asks for a change: read everything, find the cause and redo that part properly. Small obvious errors may be fixed directly. Never weaken a test, skip a check or silence a warning.
10. **Security first.** Security alerts (CodeQL, Dependabot, secret scanning, Renovate) come before other work. Open an issue for each alert and link it from the fix with `Closes #n`. Never copy a secret value into an issue. If an alert would expose an exploitable weakness or a live secret, use a private draft security advisory instead of a public issue.
11. **Latest versions.** Never add new pins to a version number; use `@latest`, `node`, `latest` and version ranges. Existing pins that Renovate keeps current (for example `packageManager`, `requirements-docs.txt`, `.node-version`, lockfiles and actions pinned to a commit SHA) stay, and only Renovate changes them.
12. **Commits and titles.** Commit with the git identity the sandbox provides. Never change git's user, email or signing, and never use `--no-verify`. The pull request title becomes the commit on `main` and follows Conventional Commits in English: `type: description` or `type(scope): description`, with type feat, fix, docs, refactor, perf, test, build, ci, chore, style or revert.
13. **Documentation in the same pull request.** When behaviour, settings or commands change, update `README.md`, `docs/` and the repository's `CLAUDE.md` in the same pull request.
14. **No stray branches.** Delete the branch when the pull request is merged or closed. Pull requests from forks are suggestions: make the change yourself on your own branch if it is wanted, and close the original with thanks and a link.
15. **Zero cost.** Never enable anything that can cost money.
16. **Model before task.** Before every new task, state which model fits it best and that it must be activated before work starts. Switching is not automatic. Do not start the task until the owner has confirmed or switched.
<!-- core-rules:end -->

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

- **Language:** everything in this repo is English, including the documentation, PR titles and bodies, commit messages, review replies and labels. The app's interface and older code comments are still Swedish; write every new or changed comment in English, and change the interface language only as its own task.

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

## Token optimizer

- **What it is:** the platform-skills token optimizer runs in audit mode. `.token-optimizer.yaml` holds the settings, `.token-optimizer/optimize.sh` is the hook script and `.claude/agents/platform-bulk-reader.md` is the cheap reader agent.
- **What it does:** a `PreToolUse` hook in `.claude/settings.json` logs oversized reads, and shell calls it cannot classify, to `.token-optimizer/decisions.log` (git-ignored). The log never holds command text. The hook never blocks a read.
- **Requirements:** `jq` and mikefarah `yq` v4 (the Python `yq` does not work). Create the git-ignored state directory once with `mkdir -p .token-optimizer/state`.
- **Local changes:** `optimize.sh` differs from the skill's original in two places: it never writes command text to the log, and it replaces control characters and caps field length in `log_line`. The hook command starts from `$CLAUDE_PROJECT_DIR`. Reapply these if the script is updated from the skill.
- **Changing it:** switch `mode` to `redirect` only after `.token-optimizer/probe/run-probe.sh` has verified delegation. Set `enabled: false` to turn it off.

## GitHub from the sandbox

The sandbox injects the agent's fine-grained token for `github.com` and `api.github.com`, so `git` and `gh` work as usual. The token reaches only this agent's repositories.

Open a pull request:

```sh
gh pr create --base main --title '<title>' --body '<body>'
```

Show the checks on a pull request:

```sh
gh pr checks <n>
```

List the inline review comments (each `id` is used for replies):

```sh
gh api repos/pissmyran/dumpen/pulls/<n>/comments
```

Reply to a review comment:

```sh
gh api repos/pissmyran/dumpen/pulls/<n>/comments/<id>/replies -f body='<reply>'
```

List the review threads with their node IDs (`id`) and first comment:

```sh
gh api graphql -f query='query { repository(owner: "pissmyran", name: "dumpen") { pullRequest(number: <n>) { reviewThreads(first: 100) { nodes { id isResolved comments(first: 1) { nodes { databaseId body } } } } } } }'
```

Resolve a review thread, using the thread's node ID, not the comment ID:

```sh
gh api graphql -f query='mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { isResolved } } }' -f id='<thread-id>'
```

Enable auto-merge and delete the branch after merge:

```sh
gh pr merge <n> --auto --squash --delete-branch
```

Close a pull request and delete its branch:

```sh
gh pr close <n> --delete-branch
```

List Dependabot alerts:

```sh
gh api repos/pissmyran/dumpen/dependabot/alerts
```

List code scanning alerts:

```sh
gh api repos/pissmyran/dumpen/code-scanning/alerts
```

List secret scanning alerts:

```sh
gh api repos/pissmyran/dumpen/secret-scanning/alerts
```
