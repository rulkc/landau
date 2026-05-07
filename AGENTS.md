This file is the context for coding agents (Claude Code, Codex, OpenHands, …) working on this repository. The human-facing editing guide lives in [`docs/editing.md`](docs/editing.md).

## Project context

`landau` is the public website for the **LANDAU Kernel** initiative — an *upstream-first* Linux kernel fork project led by the [Russian Linux Kernel Community (RULKC)](https://rulkc.org). Content-only repo: project description, events, news, contact channels.

Authoritative content language is **Russian**. English appears only in the project name, slogan, and a few section headings.

## Stack

- **Hugo extended**, version pinned in `.hugo-version`; tarball SHA256 in `.hugo-sha256`. Both bumped weekly via `.github/workflows/hugo-update.yml`.
- **Theme** is `pages-themes/hacker` flattened into plain CSS at `static/css/hacker.css`. Source commit recorded in the file header. Sprites: `static/images/{bkg,bullet}.png`.
- **Layouts** are minimal Go templates in `layouts/_default/{baseof,single,list}.html` + `layouts/index.html`.
- **Domain**: `landau.one`, served by nginx on a self-hosted server. Production builds rsync into the nginx docroot.

## Repository layout

```
.github/
  workflows/      ci, spelling, release-drafter, release-deploy, hugo-update
  release-drafter.yml   # changelog template
  dependabot.yml        # github-actions ecosystem
.hugo-version           # pinned Hugo version
.hugo-sha256            # pinned linux-amd64 tarball SHA256
hugo.toml               # baseURL=https://landau.one/, relativeURLs=true
archetypes/             # `hugo new` templates
content/
  _index.md             # home
  events/               # event page bundles (photos sit alongside index.md)
  news/                 # placeholder section
layouts/                # Go templates
static/                 # css, images, rulkc.png — copied verbatim
scripts/spellcheck.sh   # awk markdown stripper + hunspell driver
docs/editing.md         # editor's quick reference
```

## URL conventions

- `relativeURLs = true` in `hugo.toml`: HTML `href`/`src` starting with `/` are rewritten to relative paths. RSS, sitemap, canonical, og:url stay absolute against `baseURL`.
- In markdown, write internal links with leading slash (`[home](/)`, `[event](/events/open-mic-001/)`); Hugo rewrites them. Avoid `./foo.md`-style links.
- The event page `content/events/open-mic-001/index.md` carries `aliases: ['/open_mic_27_03_2026.html']` for backwards compatibility with the previous GitHub Pages URL.

## Theme update procedure

Theme is lifted (not a submodule) — upstream changes rarely. To refresh:

1. Pick a new `pages-themes/hacker` commit SHA.
2. Re-flatten its `_sass/` files into `static/css/hacker.css` (variables inlined). Update the file's comment header with the new SHA.
3. If the upstream `bkg.png` / `bullet.png` changed, refresh `static/images/`.
4. Verify with `hugo server` that nothing rendered differently.

There is no SCSS toolchain in the repo on purpose.

## CI and release pipeline

PR-based, manually-published model:

1. Feature branch → PR to `main`.
2. On every push and PR: **`ci.yml`** (Hugo build with `--panicOnWarning`, artifact uploaded ≤ 7 days / ≤ 10 newest) and **`spelling.yml`** (codespell + `scripts/spellcheck.sh`) run.
3. After merge to `main`: **`release-drafter.yml`** computes the next CalVer tag and refreshes the draft GitHub Release with all merged PRs since the previous tag, listed flat. Concurrently, **`release-deploy.yml`** rsyncs the build to the **beta** target — `${DEPLOY_SSH_PATH}.beta` — with `HUGO_PARAMS_VERSION=beta-<short-sha>`. Beta lets the maintainer eyeball the merged state on a separate URL before publishing.
4. Maintainer publishes the draft release manually → the same **`release-deploy.yml`** runs again, now on `release: published`, building with `HUGO_PARAMS_VERSION=<tag>` and rsyncing to the **prod** target — `${DEPLOY_SSH_PATH}` — then pruning published releases (and tags) past the 7 most recent.

Push to `main` does **not** publish to prod (`landau.one`) — that requires explicit "Publish release" in the GitHub UI (or `release-deploy.yml` via `workflow_dispatch`). Push only updates the beta target and the draft release.

### Versioning (CalVer `YYYY.MM.N`)

Tag `YYYY.MM.N` is computed from the latest existing tag:

- Same year+month → `N = latest.N + 1`.
- New month or no tags yet → `N = 0`.

The first release of any month is `.0`. Bash uses the `10#` prefix when incrementing `N` to avoid octal interpretation of `08`/`09`.

### Footer version

`layouts/_default/baseof.html` reads `site.Params.version` and renders it in a footer. `ci.yml` sets `HUGO_PARAMS_VERSION=dev-<short-sha>` for sanity-build artifacts; `release-deploy.yml` sets it to `beta-<short-sha>` for beta deploys and to the release tag for prod deploys; a bare `hugo server` falls back to `dev`.

### Spell checking

- **codespell** scans English typos via `.codespellrc` (skips hidden dirs by default).
- **hunspell** via `scripts/spellcheck.sh` strips YAML frontmatter, code, HTML, URLs, emails, and common markdown punctuation, then runs `hunspell -d ru_RU,en_US -l` filtered through `.spellcheck-allow.txt`. The CI workflow pulls dictionaries directly from a pinned `LibreOffice/dictionaries` commit (Ubuntu's `hunspell-ru` package conflicts with `postgresql-common` triggers on the GitHub Actions runner image and ends up not installing the dictionary files).
- Script is Bash 3.2-compatible (no `mapfile`).

### Supply chain

- All Action versions pinned (e.g. `actions/checkout@v6.0.2`). Dependabot watches the `github-actions` ecosystem.
- Hugo is bumped by `.github/workflows/hugo-update.yml` (weekly cron). 7-day release soak; smoke-test build before opening the bump PR.
- No third-party action is used for release/artifact pruning — both run via `gh api` directly.
- Deploy secrets in repo settings: `DEPLOY_SSH_KEY` (full PEM), `DEPLOY_SSH_HOST`, `DEPLOY_SSH_USER`, `DEPLOY_SSH_PATH` (nginx docroot, no trailing slash), `DEPLOY_SSH_KNOWNHOSTS` (output of `ssh-keyscan -t ed25519,rsa <host>`).

## Editorial conventions

- Top-level page heading uses an emoji prefix (`# ⚛️ …`, `# 🎙️ …`). Brand voice.
- Section dividers are `---` on their own line.
- Event pages follow `archetypes/events.md` shape: 📅/⏰/📍/👥 block at top, registration block at bottom, "⬅️ Вернуться на главную" backlink last.
- Contact channels in `_index.md` are rendered as a two-column markdown table; the logo card is a separate single-row table. Preserve.
- Russian typography: keep punctuation, em-dashes, and quotation marks.
