# feature-development

Project configuration for the `feature-development` skill. Only non-default choices are
recorded here; everything unlisted uses the skill's defaults.

## Branch convention

Branches follow the `week_<number>` pattern (e.g. `week_seven`, `week_eight`) and are
branched from `main`.

Ask the human for the week number before creating the branch — it cannot be inferred
reliably from the existing branches.

## Committing

Make small, logical, frequent commits so code review stays easy. One coherent change per
commit.

**Before every commit,** run `bin/rubocop` and fix anything it reports. Apply the
modifications needed to satisfy it — the working tree must be RuboCop-clean at the moment
of the commit, not afterwards. Do not commit and rely on CI to catch style issues.

All commit messages are written **strictly in English**:

- **Title:** imperative mood, describing what the commit does
  (`Add byte size extraction to OG job`, not `Added...` or `Adding...`).
- **Body:** explain **what** changed and **why**. The diff already shows the how.

Never commit API keys, tokens, passwords, or any sensitive data. Before committing, verify
that any file carrying configuration of that kind is covered by `.gitignore` — `/.env*`
and `/config/*.key` are already ignored; confirm rather than assume for anything new.

## Detected project settings

- **Review hand-off:** delegate to the `code-review` skill
- **Verification:** delegate to the `run` skill

Build, test, lint, and run commands, the testing strategy, and the project's architecture
live in `CLAUDE.md` — follow that file, do not duplicate it here.
