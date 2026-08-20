# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Scope

A composite **GitHub Action** (pure shell) that generates **abbreviated release
notes** from Conventional Commits — the *user-facing* changes since the last
release, for deciding whether to upgrade. Output is a markdown file
(`RELEASE_NOTES.md` by default) with the **repository title**, the **version**,
and the changes collated as **BREAKING (bold, first) → Features → Fixes**.
Everything else (docs, chore, refactor, ci, perf, …) is intentionally excluded.

This is the abbreviated counterpart to a full changelog: **release notes here
have NO commit SHAs** (they're for end users); changelogs keep SHAs. The
`mrdoodles/versioning-tests` changelog workflow consumes this action, so the
output format is effectively a contract — the tests lock it down.

## Layout

- `action.yml` — composite action; one shell step runs `scripts/generate.sh`
  with `INPUT_*` env and exposes outputs `version`, `file`, `changed`.
- `scripts/generate.sh` — all the logic.
- `tests/test.sh` — assert-based suite over the generated markdown.
- `.github/workflows/ci.yml` — shellcheck + tests.
- `README.md`, `LICENSE` (MIT), `TODO.md` (deferred work).

## How `generate.sh` works

- Inputs (env): `INPUT_TITLE` (default: repo name from `GITHUB_REPO`),
  `INPUT_FROM` (default: latest `vX.Y.Z` tag), `INPUT_TO` (default `HEAD`),
  `INPUT_VERSION` (default: computed), `INPUT_OUTPUT_FILE` (default
  `RELEASE_NOTES.md`).
- Range = `FROM..TO` or `<last-tag>..HEAD`. `last_tag` matches full semver only
  (`v[0-9]*.[0-9]*.[0-9]*`) so **moving major tags like `v1` are ignored**.
- Classifies commits into **breaking / feat / fix only** (subject `!` or body
  `BREAKING CHANGE`/`BREAKING-CHANGE` → breaking; `feat:` / `fix:` by type).
- Version = explicit `INPUT_VERSION`, else bump the last tag: breaking→major,
  feat→minor, else patch.
- Writes `# <title>` / `## v<version>` / `**⚠ BREAKING CHANGES**` (bold) /
  `### Features` / `### Fixes`, omitting empty sections; falls back to
  "_No user-facing changes since …_". **No SHAs.**

## Commands

```bash
bash tests/test.sh
shellcheck -x --severity=warning scripts/*.sh tests/*.sh
# Manual run:
INPUT_TITLE="My Project" GITHUB_REPO="owner/repo" bash scripts/generate.sh && cat RELEASE_NOTES.md
```

## Coding style

- Pure `bash` with `set -euo pipefail`; must pass
  `shellcheck -x --severity=warning` (CI enforces).
- **The output format is the spec.** Any change to headings/ordering/content
  must update `tests/test.sh`. Notably a test asserts **no `(sha)` appears** in
  the output — don't reintroduce commit SHAs (they were removed in v1.0.1).
- Quote `done` when used as a literal (shell keyword → SC1010); prefer
  `awk`/`printf` over `sed | head` (SIGPIPE under pipefail).
- Keep it dependency-free (`bash`, `git`, `sed`, `grep`).

## Versioning & releasing

Releases are cut by `release.yml` (`workflow_dispatch`) — never by hand, and
never through the GitHub web UI:

```bash
gh workflow run release.yml --repo lite-actions/release-notes
```

It computes the version from the commits since the last `vX.Y.Z` tag, tags the
release, force-moves `@vN`, and publishes the GitHub Release with the generated
notes as its body. `@vN` is the moving major tag consumers use.

**Never create a release through the web UI.** The "publish to the Marketplace"
checkbox is required only for an action's *first* publish; once a listing
exists, releases cut by the workflow appear on it automatically — verified
2026-08-20 on `git-checkout`, where `v1.1.0` reached the listing with nothing
ticked. Using the UI afterwards is what produced the `v1.12` and `1.3.5` tags,
and left `@v1` pointing at an old commit three times. The workflow types
nothing, so it cannot mistype.

## Conventions

- Public repo with a **protected `main`** — all changes go via PR. Required
  checks are `validate`, `lint` and `test`; `enforce_admins` is on, one
  approving review is needed, and `require_last_push_approval` means the last
  pusher cannot self-approve (use the `MrDClaudeBot` identity). `main` also
  **requires signed commits**, so rebase merges are rejected — GitHub cannot
  sign them; merge or squash instead.
- Conventional Commits for messages; co-authored commits use the bot identity:
  `Co-Authored-By: Claude <309050497+MrDClaudeBot@users.noreply.github.com>`.
- **Never use `git worktree`.** Work in the clone directly, or push a branch and
  use a fresh clone. If a branch is already checked out elsewhere and `git
  switch` refuses it, do not reach for a worktree — push from the current branch
  with `git push origin HEAD:<branch>` instead.
- **`TODO.md`** tracks deferred work: add changelog + release-notes automation to
  this repo *after* it's published to the Marketplace.
