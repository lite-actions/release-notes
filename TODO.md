# TODO

Deferred until **after** this action is published to the GitHub Marketplace:

- [ ] Add automated **changelog** generation (maintain `CHANGELOG.md` on merge to
      `main`), mirroring the setup in `mrdoodles/versioning-tests`.
- [ ] Add automated **release notes** (`RELEASE_NOTES.md`) by dogfooding this
      action.

Notes:

- This repo currently has no branch protection, so a simple direct-push
  changelog commit on merge is sufficient — no auto-merged-PR machinery or PAT
  secrets required.
- If branch protection is added later, switch to the auto-merged-PR flow used in
  versioning-tests (needs `CHANGELOG_BOT_TOKEN` + `CHANGELOG_APPROVE_TOKEN`
  secrets and `MrDClaudeBot` as a collaborator / code owner).
