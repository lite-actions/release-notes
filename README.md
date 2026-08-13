# Release Notes Generator

A composite GitHub Action (pure shell) that generates **abbreviated release
notes** from [Conventional Commits](https://www.conventionalcommits.org/) — the
user-facing changes since the last release, for deciding whether to upgrade.

The notes contain the **repository title**, the **release version**, and the
changes since the last release, collated as:

1. **BREAKING CHANGES** (bold, first)
2. Features
3. Fixes

Non-user-facing commits (docs, chore, refactor, ci, …) are excluded. No
Node/Docker — just `bash`, `git`, `sed`, `grep`.

## Usage

```yaml
- uses: lite-actions/git-checkout@v1
  with:
    fetch-depth: 0 # needed so "since last release" can be resolved
- uses: lite-actions/release-notes@v1
  with:
    title: "My Project" # optional; defaults to the repo name
- run: cat RELEASE_NOTES.md
```

## Inputs

| Input         | Default             | Description                                               |
| ------------- | ------------------- | --------------------------------------------------------- |
| `title`       | repository name     | Heading title for the notes.                              |
| `from`        | latest `vX.Y.Z` tag | Base ref/commit for the range.                            |
| `to`          | `HEAD`              | Head ref/commit for the range.                            |
| `version`     | computed            | Explicit version; otherwise bumped from the commit types. |
| `output-file` | `RELEASE_NOTES.md`  | File to write.                                            |

## Outputs

| Output    | Description                                             |
| --------- | ------------------------------------------------------- |
| `version` | The release version used in the notes.                  |
| `file`    | The path the notes were written to.                     |
| `changed` | `true` if there were any BREAKING / feat / fix commits. |

## Version bump

When `version` is not given, it is computed from the commits since the last
`vX.Y.Z` tag: a BREAKING change → major, a `feat` → minor, otherwise patch.

## Example output

```markdown
# My Project

## v2.0.0

**⚠ BREAKING CHANGES**

- node 18 is now required

### Features

- add sso login

### Fixes

- handle empty payload
```
