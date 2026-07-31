#!/usr/bin/env bash
#
# Generate abbreviated release notes from Conventional Commits.
#
# Includes only user-facing changes since the last release, collated as:
#   BREAKING CHANGES (bold, first)  ->  Features  ->  Fixes
#
# Inputs (env):
#   INPUT_TITLE        Heading title (default: repository name).
#   INPUT_FROM         Base ref/commit (default: latest vX.Y.Z tag).
#   INPUT_TO           Head ref/commit (default: HEAD).
#   INPUT_VERSION      Explicit version (default: computed from the commits).
#   INPUT_OUTPUT_FILE  File to write (default: RELEASE_NOTES.md).
#   GITHUB_REPO        owner/repo, used for the default title.
#
# Outputs (to $GITHUB_OUTPUT): version, file, changed
#
set -euo pipefail

: "${GITHUB_OUTPUT:=/dev/stdout}"
emit() { printf '%s=%s\n' "$1" "$2" >> "${GITHUB_OUTPUT}"; }

TITLE="${INPUT_TITLE:-}"
if [ -z "${TITLE}" ]; then
  repo="${GITHUB_REPO:-}"
  TITLE="${repo##*/}"
  TITLE="${TITLE:-Release Notes}"
fi
FROM="${INPUT_FROM:-}"
TO="${INPUT_TO:-HEAD}"
VERSION="${INPUT_VERSION:-}"
OUT="${INPUT_OUTPUT_FILE:-RELEASE_NOTES.md}"

# Latest full semver tag (ignores moving major tags like v1).
last_tag="$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -n1 || true)"

if [ -n "${FROM}" ]; then
  range="${FROM}..${TO}"
elif [ -n "${last_tag}" ]; then
  range="${last_tag}..${TO}"
else
  range=""
fi

if [ -n "${range}" ]; then
  commits="$(git rev-list --no-merges "${range}")"
else
  commits="$(git rev-list --no-merges "${TO}")"
fi

# ---------------------------------------------------------------------------
# Classify commits: BREAKING / feat / fix only.
# ---------------------------------------------------------------------------
breaks=(); feats=(); fixes=()
while IFS= read -r sha; do
  [ -n "${sha}" ] || continue
  subject="$(git log -1 --format=%s "${sha}")"
  body="$(git log -1 --format=%b "${sha}")"
  desc="$(printf '%s' "${subject}" | sed -E 's/^[a-z]+(\([^)]+\))?!?:[[:space:]]*//')"
  type="${subject%%[(:!]*}"

  # Release notes are for end users; commit SHAs are intentionally omitted.
  if printf '%s' "${subject}" | grep -Eq '^[a-z]+(\([^)]+\))?!:' \
     || printf '%s' "${body}" | grep -Eq '^(BREAKING[ ]CHANGE|BREAKING-CHANGE):'; then
    bc="$(printf '%s' "${body}" | sed -n -E 's/^(BREAKING[ ]CHANGE|BREAKING-CHANGE):[[:space:]]*(.*)/\2/p' | head -n1)"
    [ -n "${bc}" ] || bc="${desc}"
    breaks+=("- ${bc}")
  fi

  case "${type}" in
    feat) feats+=("- ${desc}") ;;
    fix)  fixes+=("- ${desc}") ;;
  esac
done <<< "${commits}"

# ---------------------------------------------------------------------------
# Version (explicit, else bump the last tag by the highest change type).
# ---------------------------------------------------------------------------
if [ -n "${VERSION}" ]; then
  next="${VERSION#v}"
else
  base="${last_tag#v}"; base="${base:-0.0.0}"
  IFS=. read -r ma mi pa <<< "${base}"
  if   [ "${#breaks[@]}" -gt 0 ]; then ma=$((ma + 1)); mi=0; pa=0
  elif [ "${#feats[@]}"  -gt 0 ]; then mi=$((mi + 1)); pa=0
  else                                 pa=$((pa + 1)); fi
  next="${ma}.${mi}.${pa}"
fi

# ---------------------------------------------------------------------------
# Write the notes: title, version, then BREAKING (bold) / Features / Fixes.
# ---------------------------------------------------------------------------
{
  printf '# %s\n\n' "${TITLE}"
  printf '## v%s\n' "${next}"
  if [ "${#breaks[@]}" -gt 0 ]; then
    printf '\n**⚠ BREAKING CHANGES**\n\n'; printf '%s\n' "${breaks[@]}"
  fi
  if [ "${#feats[@]}" -gt 0 ]; then
    printf '\n### Features\n\n'; printf '%s\n' "${feats[@]}"
  fi
  if [ "${#fixes[@]}" -gt 0 ]; then
    printf '\n### Fixes\n\n'; printf '%s\n' "${fixes[@]}"
  fi
  if [ "${#breaks[@]}" -eq 0 ] && [ "${#feats[@]}" -eq 0 ] && [ "${#fixes[@]}" -eq 0 ]; then
    printf '\n_No user-facing changes since %s._\n' "${last_tag:-the start of the project}"
  fi
  printf '\n'
} > "${OUT}"

echo "Wrote ${OUT} for v${next} (breaking=${#breaks[@]}, features=${#feats[@]}, fixes=${#fixes[@]})."
emit version "${next}"
emit file "${OUT}"
if [ "${#breaks[@]}" -gt 0 ] || [ "${#feats[@]}" -gt 0 ] || [ "${#fixes[@]}" -gt 0 ]; then
  emit changed true
else
  emit changed false
fi
