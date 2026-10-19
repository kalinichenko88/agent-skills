---
name: release
description: Use when releasing the kalinichenko plugin from main.
disable-model-invocation: true
argument-hint: "[major|minor|patch]"
---

# Release

A release is a `vX.Y.Z` tag on `main`, the same `version` in
`.codex-plugin/plugin.json`, a section in `CHANGELOG.md` and a GitHub release
with that section as its notes. Codex reinstalls the plugin when the `version`
field changes. Claude Code tracks commits instead, which is why
`.claude-plugin/plugin.json` carries no `version` — never add one.

This skill is the only place `version` and `CHANGELOG.md` change; pull requests
leave them alone. It releases what is already on `main`: merging a pull request
is a separate decision, never a step of the release.

Each command runs in a fresh shell, so `$last` and `$version` below stand for
values: write the real ones (`v0.1.0`, `0.2.0`) into every later command.

1. **Start from `main`.** Run `git fetch origin --tags`. Stop and say why if the
   branch is not `main` or the tree is dirty. Behind `origin/main`: `git merge
   --ff-only origin/main`. Stop if that fails, or if `HEAD` is still not
   `origin/main` — local commits the remote does not have.
2. **Read what is unreleased.** `last=$(git describe --tags --abbrev=0 --match 'v[0-9]*')`, then
   `git log --format=%s "$last"..HEAD` and `git diff --name-only "$last"..HEAD`.
   No commits since the tag: stop, there is nothing to release. If
   `jq -r .version .codex-plugin/plugin.json` is not `${last#v}`, stop: the field
   moved outside a release, and that has to be undone first.
3. **Pick the level.** `$ARGUMENTS` when it is `major`, `minor` or `patch`;
   empty, the highest that applies; anything else, stop and say it is not a
   level. A subject's type is everything before its first `:` —
   `feat(github)!` is type `feat`, scope `github`, breaking:

   | Level | When |
   | --- | --- |
   | major | a type ends in `!`, or `hooks/hooks.json` changed — Codex users must trust the hooks again in `/hooks` |
   | minor | a type is `feat` |
   | patch | anything else, reverts included |

   Bump `${last#v}` by that level — a minor resets the patch, a major resets
   both. Show the subjects, the level and the new version, and wait for a yes.
4. **Write the changelog section.** Insert it into `CHANGELOG.md` above the
   previous version's `## ` heading, under a heading `## $version - YYYY-MM-DD`
   with today's date. One line per subject from step 2, in `git log` order,
   grouped by type under `### Added` (`feat`), `### Fixed` (`fix`) and
   `### Changed` (every other type); leave out a group with no lines. A line is
   the subject without its type: `feat(github): check the citations (#24)`
   becomes `- github: check the citations (#24)`, and a subject with no scope
   keeps its sentence, first letter upper-case. Breaking subjects (`!`) get
   `(breaking)` after the PR number.
5. **Bump and check.**
   `tmp=$(mktemp) && jq --arg v "$version" '.version = $v' .codex-plugin/plugin.json >"$tmp" && mv "$tmp" .codex-plugin/plugin.json`,
   then `make check`. If the check fails, restore both files and stop.
6. **Commit, tag and push together.**

   ```sh
   git commit -m "chore(release): bump the Codex version to $version" -- .codex-plugin/plugin.json CHANGELOG.md
   git tag -a "v$version" -m "v$version"
   git push --atomic origin main "v$version"
   ```

   `--atomic` lands the commit and the tag together or not at all. A rejected
   push means `main` moved: `git tag -d "v$version" && git reset --keep HEAD~1`,
   then start again at step 1. Never rebase or amend the release commit — the
   tag points at it.
7. **Publish the GitHub release** with the new section, heading left out, as
   its notes:

   ```sh
   awk -v h="## $version " 'index($0, h) == 1 {p = 1; next} /^## / {p = 0} p' CHANGELOG.md \
     | gh release create "v$version" --title "v$version" --notes-file -
   ```

   If this fails, nothing needs undoing: fix the cause and run it again.
8. **Report** the new tag, the release URL and the update commands from the
   README's *Update* section.
