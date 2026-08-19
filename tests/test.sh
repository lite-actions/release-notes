#!/usr/bin/env bash
#
# Exercises generate.sh and asserts the output. Run: bash tests/test.sh
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEN="${ROOT}/scripts/generate.sh"

pass=0
fail=0
check() { # description  condition-exit-code
  if [ "$2" -eq 0 ]; then echo "  ok   - $1"; pass=$((pass + 1))
  else echo "  FAIL - $1"; fail=$((fail + 1)); fi
}

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
cd "${tmp}" || exit 1
git init -q
git config user.email test@example.com
git config user.name test
# The scratch repo inherits global config. With commit.gpgsign / tag.gpgsign
# set, `git tag v1.4.0` below becomes a signed annotated tag with no message
# and dies with "fatal: no tag message?", so the baseline tag never exists and
# the version assertions fail. main requires signed commits, so every
# contributor has signing configured - this would fail for all of them.
git config commit.gpgsign false
git config tag.gpgsign false

export GITHUB_OUTPUT="${tmp}/out"
export GITHUB_REPO="acme/widget"

# Baseline release, then one of each user-facing change plus noise.
git commit -q --allow-empty -m "chore: init"
git tag v1.4.0
git commit -q --allow-empty -m "feat: add sso login"
git commit -q --allow-empty -m "fix(api): handle empty payload"
git commit -q --allow-empty -m "docs: tweak readme"
git commit -q --allow-empty -F - <<'EOF'
refactor!: drop node 16

BREAKING CHANGE: node 18 is now required
EOF

bash "${GEN}" >/dev/null
notes="$(cat RELEASE_NOTES.md)"
echo "----- generated RELEASE_NOTES.md -----"; echo "${notes}"; echo "--------------------------------------"

grep -q '^# widget$' RELEASE_NOTES.md; check "title = repo name (widget)" $?
grep -q '^## v2.0.0$' RELEASE_NOTES.md; check "version bumped to v2.0.0 (breaking)" $?
grep -q '^\*\*⚠ BREAKING CHANGES\*\*$' RELEASE_NOTES.md; check "BREAKING heading is bold" $?
grep -q 'node 18 is now required' RELEASE_NOTES.md; check "breaking description shown" $?
grep -q '^### Features$' RELEASE_NOTES.md; check "Features section present" $?
grep -q 'add sso login' RELEASE_NOTES.md; check "feature listed" $?
grep -q '^### Fixes$' RELEASE_NOTES.md; check "Fixes section present" $?
grep -q 'handle empty payload' RELEASE_NOTES.md; check "fix listed" $?
grep -q 'docs: tweak readme' RELEASE_NOTES.md && echo "  FAIL - docs leaked in" && fail=$((fail+1)) || { echo "  ok   - non-user-facing (docs) excluded"; pass=$((pass+1)); }

# Ordering: BREAKING before Features before Fixes.
awk '/BREAKING CHANGES/{b=NR} /### Features/{f=NR} /### Fixes/{x=NR} END{exit !(b<f && f<x)}' RELEASE_NOTES.md
check "order is BREAKING -> Features -> Fixes" $?

# Release notes must NOT contain commit SHAs.
if grep -qE '\([0-9a-f]{7,}\)' RELEASE_NOTES.md; then
  check "no commit SHAs in release notes" 1
else
  check "no commit SHAs in release notes" 0
fi

# version output
grep -q '^version=2.0.0$' "${GITHUB_OUTPUT}"; check "emits version=2.0.0" $?

# A newline in an output value would inject step outputs the action never
# declared. INPUT_VERSION is the reachable path; it must be refused, and nothing
# at all should be written.
inj_out="${tmp}/inject-out"
: > "${inj_out}"
if GITHUB_OUTPUT="${inj_out}" INPUT_VERSION="$(printf '1.0.0\nmalicious=true')" \
     bash "${GEN}" >/dev/null 2>&1; then
  check "multi-line INPUT_VERSION is refused" 1
else
  check "multi-line INPUT_VERSION is refused" 0
fi
grep -q '^malicious=' "${inj_out}" && check "no injected output key" 1 || check "no injected output key" 0

echo
echo "passed: ${pass}, failed: ${fail}"
[ "${fail}" -eq 0 ]
