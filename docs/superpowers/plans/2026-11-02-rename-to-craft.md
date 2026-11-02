# Rename to craft Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The plugin is `craft`, the repository is `kalinichenko88/craft-skills`, and a person who installed `kalinichenko` finds the way to move from the top of the README.

**Architecture:** A rename in text: manifests, prose, tests and recorded fixtures, by `perl -pi` over the files that `git grep -l` lists. One lint line in the `Makefile` keeps `kalinichenko:` from coming back. New text: a migration guide, a README written for a user, `CONTRIBUTING.md` with the old *Develop* and *Release* sections, and ADR 0002.

**Tech Stack:** bash, git, `gh`, `perl` (for in-place edits that are the same on macOS and Linux), Markdown, the `claude` and `codex` CLIs.

**Spec:** issue #214, its body as of 2026-11-02: `gh issue view 214 --json body --jq .body`.

## Global Constraints

- Plugin name: `craft`. Marketplace name: stays `kalinichenko`. Install: `craft@kalinichenko`.
- Repository: `kalinichenko88/craft-skills`. The owner `kalinichenko88` stays everywhere. No new repository takes the name `agent-skills`: that breaks GitHub's redirect.
- History stays as it is: `docs/superpowers/`, the sections of `CHANGELOG.md`, closed issues, merged PRs.
- `CHANGELOG.md`: the PR changes only its header line. `/release` alone writes a section (the **Release** invariant).
- Test data that uses `kalinichenko88/agent-skills` as a repository stays: `tests/github_scripts_test.sh`, `tests/roadmap_scripts_test.sh`, `tests/hooks_scripts_test.sh`, `tests/fixtures/github/`, `tests/fixtures/roadmap/`, and the paths `/home/eval/agent-skills` in `tests/fixtures/product/logs/`.
- The owner's local folder keeps the name `agent-skills`: Claude Code keys a project's memory and sessions by its path.
- `README.md` keeps the headings `## Install` and `## Update`: `skills/github/filing.md` links `#update`.
- Prose in Simplified Technical English. Commit messages in English, no `Co-Authored-By:`.
- Squash subject: `feat(plugin)!: rename the plugin to craft and the repository to craft-skills`.

## Review Focus

1. A Codex user who moves: Codex takes the hooks of `craft` as new hooks and skips them until the person trusts them in `/hooks`. The guide has that step (Task 4).
2. A person who adds the marketplace again by the new URL: the help of `claude plugin marketplace remove` does not say what happens to the plugins of that marketplace. So the guide puts the optional new add in place of the update, before the install: then nothing is installed from the marketplace while it is away.
3. An open branch or an issue text written before the rename brings `kalinichenko:` back. The lint line of Task 2 fails `make check` on it.
4. An eval run on a machine that still has the old plugin: both keys, `"craft@kalinichenko": false` and `"kalinichenko@kalinichenko": false`, are in the `--settings` of every eval, so only the branch loads (fixed in review round 1).
5. A link to the old README: `#install` and `#update` keep working (Constraints), and the old *Develop* and *Release* anchors have no link in the tree (checked: `git grep -n '#develop\|#release'` prints nothing).

---

### Task 1: Rename the repository on GitHub

An action outside the tree. It is hard to undo: ask the owner for a yes before step 1.

**Files:** none.

**Interfaces:**
- Produces: `https://github.com/kalinichenko88/craft-skills`, with a redirect from `agent-skills` for the web, git and the API.

- [ ] **Step 1: Rename**

Run: `gh repo rename craft-skills --repo kalinichenko88/agent-skills --yes`
Expected: `✓ Renamed repository kalinichenko88/craft-skills`

- [ ] **Step 2: Point the remote at the new URL**

Run: `git remote set-url origin "$(git remote get-url origin | sed 's#/agent-skills\.git$#/craft-skills.git#; s#/agent-skills$#/craft-skills#')" && git remote get-url origin`
Expected: the URL ends in `craft-skills.git`. The worktrees share this remote.

- [ ] **Step 3: Check the redirect**

Run: `gh repo view kalinichenko88/agent-skills --json nameWithOwner --jq .nameWithOwner && git ls-remote https://github.com/kalinichenko88/agent-skills.git HEAD`
Expected: `kalinichenko88/craft-skills`, then one SHA line.

### Task 2: The plugin name in the tree

**Files:**
- Modify: `Makefile` (the `lint` target), `tests/rules_test.sh`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`, `CHANGELOG.md:3`, and every file that the greps of step 3 list.

**Interfaces:**
- Produces: skill names `craft:<skill>`; the settings key `craft@kalinichenko` in the evals.

- [ ] **Step 1: The failing checks**

In `tests/rules_test.sh`, change each expected line that holds `kalinichenko:` to `craft:`. In the `lint` target of `Makefile`, after the `CHANGELOG.md` line, add:

```make
	! git grep -n 'kalinichenko[:]' -- . ':!docs/superpowers' ':!CHANGELOG.md' ':!docs/migrating-from-kalinichenko.md'
```

- [ ] **Step 2: Run them to see them fail**

Run: `make check`
Expected: FAIL. The lint line prints the `kalinichenko:` hits, and `tests/rules_test.sh` fails on its expected lines.

- [ ] **Step 3: Rename**

```bash
git grep -l 'kalinichenko:' -- . ':!docs/superpowers' ':!CHANGELOG.md' | xargs perl -pi -e 's/kalinichenko:/craft:/g'
git grep -l 'kalinichenko@kalinichenko' -- . ':!docs/superpowers' | xargs perl -pi -e 's/kalinichenko\@kalinichenko/craft\@kalinichenko/g'
```

Then by hand:
- the three manifests: `"name": "craft"` in `.claude-plugin/plugin.json`, in `plugins[0]` of `.claude-plugin/marketplace.json`, and in `.codex-plugin/plugin.json`. The top `name` of `marketplace.json` stays `kalinichenko`;
- "the kalinichenko plugin" and `` `kalinichenko` `` as the plugin: `docs/ARCHITECTURE.md:10`, `skills/review-loop/README.md:159`, `.claude/skills/release/SKILL.md:3`, the four prompts in `tests/product_eval.sh` (`ask`, `fork`, `plain`, `store`). `README.md` waits for Task 5;
- `CHANGELOG.md:3`: "Every release of the kalinichenko plugin" becomes "Every release of this plugin".

- [ ] **Step 4: Run the checks**

Run: `make check`
Expected: PASS. Then `git grep -n 'kalinichenko' -- . ':!docs/superpowers' ':!CHANGELOG.md' | grep -v 'kalinichenko88\|@kalinichenko'` prints only: `"name": "kalinichenko"` at `.claude-plugin/marketplace.json:2`, the lint line of `Makefile`, the two footers of `brief.md` (Task 3), and `README.md` lines (Task 5).

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(plugin)!: rename the plugin to craft"
```

### Task 3: The repository name in the tree

**Files:**
- Modify: `rules.md:180-181`, `skills/github/SKILL.md:21`, `skills/github/filing.md` (each `kalinichenko88/agent-skills`, `name: "agent-skills"` in the GraphQL query, "a checkout of `agent-skills`" at `:131`), `skills/github/README.md:37-39`, `homepage` and `repository` in both `plugin.json`, `AGENTS.md:1`, `.claude/CLAUDE.md:1`, `docs/github/brief.md:18`, `docs/roadmap/brief.md:18`.

**Interfaces:**
- Consumes: Task 1, so the new URLs work.

- [ ] **Step 1: Rename**

```bash
git grep -l 'kalinichenko88/agent-skills' -- rules.md skills .claude-plugin .codex-plugin | xargs perl -pi -e 's{kalinichenko88/agent-skills}{kalinichenko88/craft-skills}g'
```

Then by hand: "a checkout of `agent-skills`" becomes `craft-skills` in `rules.md:181`, `skills/github/SKILL.md:21`, `skills/github/filing.md:131` and `skills/github/README.md:39`; `name: "agent-skills"` becomes `name: "craft-skills"` in `skills/github/filing.md`; `# agent-skills` becomes `# craft-skills` in `AGENTS.md` and `.claude/CLAUDE.md`; the footer `"kalinichenko/agent-skills · craft:<skill> skill"` becomes `"kalinichenko88/craft-skills · craft:<skill> skill"` in both `brief.md`.

- [ ] **Step 2: Check what is left**

Run: `make check && git grep -n 'agent-skills' -- . ':!docs/superpowers' ':!CHANGELOG.md' ':!README.md' ':!tests/github_scripts_test.sh' ':!tests/roadmap_scripts_test.sh' ':!tests/hooks_scripts_test.sh' ':!tests/fixtures/github' ':!tests/fixtures/roadmap' ':!tests/fixtures/product/logs'`
Expected: PASS, and the grep prints nothing. `README.md` waits for Task 5.

- [ ] **Step 3: Commit**

```bash
git commit -am "feat(plugin): name the repository craft-skills in the rules, skills and manifests"
```

### Task 4: The migration guide

**Files:**
- Create: `docs/migrating-from-kalinichenko.md`
- Modify: `docs/ARCHITECTURE.md` (*Codemap*: one line for the guide)

**Interfaces:**
- Produces: the path `docs/migrating-from-kalinichenko.md`, which the README note (Task 5) and the release notes (Task 8) link.

- [ ] **Step 1: Write the guide**

One page, for those who installed `kalinichenko`. It says what changed: the plugin `kalinichenko` is now `craft`, the repository `agent-skills` is now `craft-skills`, the marketplace is still `kalinichenko`, and a skill call reads `craft:github`. Then the steps, each command as a code block:

Claude Code:

```sh
claude plugin marketplace update kalinichenko
claude plugin uninstall kalinichenko@kalinichenko
claude plugin install craft@kalinichenko
```

Codex:

```sh
codex plugin marketplace upgrade kalinichenko
codex plugin remove kalinichenko@kalinichenko
codex plugin add craft@kalinichenko
```

Then, in Codex: run `codex`, open `/hooks`, and trust the three hooks of `craft`.

Your own files: find the old names, then replace them.

```sh
grep -rln 'kalinichenko:' ~/.claude/CLAUDE.md ~/.claude/settings.json ~/.claude/skills ~/.claude/hooks ~/.codex/AGENTS.md ~/.codex/config.toml ~/.codex/skills ~/.agents CLAUDE.md AGENTS.md .claude .codex .agents 2>/dev/null
perl -pi -e 's/kalinichenko:/craft:/g' <each file it lists>
```

Optional: the old URL works through GitHub's redirect. To add the marketplace by the new URL, do it before the install, in place of the update: `claude plugin marketplace remove kalinichenko`, then `claude plugin marketplace add kalinichenko88/craft-skills`; in Codex, `codex plugin marketplace remove kalinichenko`, then `codex plugin marketplace add kalinichenko88/craft-skills`.

Last: start a new session.

- [ ] **Step 2: Check each command against the CLI**

Run the `--help` of each subcommand that the guide uses: `claude plugin marketplace update|add|remove`, `claude plugin uninstall|install`, `codex plugin marketplace upgrade|add|remove`, `codex plugin remove|add`.
Expected: each one exists, and takes the argument in the form that the guide gives (`<name>`, `<plugin>@<marketplace>`, `<owner>/<repo>`). A form that differs: correct the guide.

- [ ] **Step 3: The codemap line**

In `docs/ARCHITECTURE.md`, *Codemap*: `- docs/migrating-from-kalinichenko.md — the steps for those who installed the plugin under its old name.`

- [ ] **Step 4: Check and commit**

Run: `make check`
Expected: PASS.

```bash
git add docs/migrating-from-kalinichenko.md docs/ARCHITECTURE.md
git commit -m "docs: add the steps to move from kalinichenko to craft"
```

### Task 5: The README as a guide for a user

**Files:**
- Modify: `README.md` (rewrite)
- Create: `CONTRIBUTING.md`
- Modify: `docs/ARCHITECTURE.md` (*Codemap*: one line for `CONTRIBUTING.md`)

**Interfaces:**
- Consumes: the guide's path from Task 4.

- [ ] **Step 1: Move *Develop* and *Release***

Move `## Develop` and `## Release` of `README.md` (from line 134 to the end) as they are into `CONTRIBUTING.md`, under `# Contributing`. Rename `kalinichenko:` and `kalinichenko` as the plugin there, as Task 2 did.

- [ ] **Step 2: Write the README**

Heading `# craft-skills`. Under it, first, a note: "The plugin was `kalinichenko`, and this repository was `agent-skills`. If you installed it under the old name, [move to `craft`](docs/migrating-from-kalinichenko.md)." Then the sections, in this order:

1. What `craft` is, and for whom: a solo developer or a small team, in Claude Code and Codex.
2. What it does: `rules.md` in two or three sentences, then one line per skill with a link to its README (#40). The pictures of github and roadmap stay where they are.
3. Use cases: three short scenarios from start to end: take an issue into work (github, review-loop), review a branch before the pull request (review-loop), plan a milestone (roadmap). Each says what you type and what you get.
4. What it works with: GitHub, TypeScript, React, Docker.
5. Integrations: superpowers (the review loop takes the place of its review skills), ponytail (the over-engineering review, the debt map), Codex (a second reviewer and a host of its own).
6. External dependencies, in two lists, required and optional, each item in the shape that #212 asks for: the dependency, the skill or step that needs it, and what happens without it. From the `Needs` lines of the scripts, the old *Install* text, `skills/review-loop/SKILL.md` and `rules.md`: `bash`, `git`, `gh` (with the `project` scope for the roadmap board), `awk`, `npx` or `bunx` for `clones.sh`, Git for Windows on native Windows, the Codex CLI, ponytail, superpowers. The dependency paragraph of the old *Install* moves here. #212 adds its browser tools to this section later.
7. `## Install` and `## Update`, with the text of the old sections and these commands: `claude plugin marketplace add kalinichenko88/craft-skills`, `claude plugin install craft@kalinichenko`, `codex plugin marketplace add kalinichenko88/craft-skills`, `codex plugin add craft@kalinichenko`, `claude plugin update craft@kalinichenko`, `codex plugin marketplace upgrade kalinichenko`.

- [ ] **Step 3: Check**

Run: `make check && grep -n '^## Install$\|^## Update$' README.md && test -f docs/migrating-from-kalinichenko.md && git grep -n 'kalinichenko\|agent-skills' README.md CONTRIBUTING.md | grep -v kalinichenko88/craft-skills`
Expected: PASS; both headings; the only lines left are the note, the marketplace name in the commands, and `craft@kalinichenko`.

- [ ] **Step 4: Commit**

```bash
git add README.md CONTRIBUTING.md docs/ARCHITECTURE.md
git commit -m "docs: write the README for a user, and move develop and release to CONTRIBUTING.md"
```

### Task 6: #218, a prompt to Codex goes through a file, not a heredoc

#218 rides along: a settled bug in three files that Task 2 changes. Its fix is the one its body names.

**Files:**
- Modify: `Makefile` (the `lint` target), `skills/review-loop/SKILL.md:512`, `skills/debt/SKILL.md:159`, `skills/product/SKILL.md:148`

- [ ] **Step 1: The failing check**

In the `lint` target of `Makefile`, add:

```make
	! git grep -n "<<'EOF'" -- 'skills/*.md' rules.md
```

Run: `make check`
Expected: FAIL, with the three lines above.

- [ ] **Step 2: Fix the three places**

In each, the agent writes the prompt to a file with the Write tool, in a folder from `mktemp -d`, and gives Codex the file: `codex exec -s read-only --ephemeral - < "$prompt"` (in debt with `-C <tree>`, in product with `--search` before `exec`). The text that was inside the heredoc, the last line of review-loop's "You are one reviewer…" too, goes into the file.

- [ ] **Step 3: Check and commit**

Run: `make check`
Expected: PASS.

```bash
git commit -am "fix(review-loop): give Codex a prompt through a file, so a line EOF in it runs nothing"
```

### Task 7: ADR 0002, the check of the branch, the review

**Files:**
- Create: `docs/adr/0002-plugin-name-craft.md`
- Modify: `docs/ARCHITECTURE.md` (the *ADRs* list)

- [ ] **Step 1: Write the ADR**

The template of `kalinichenko:architecture`, now `craft:architecture`. Status `accepted`, date of the merge. Context: the author's name as the plugin name, skills outside development to come. Options, one line each: keep `kalinichenko`; `craft`; `crafting` (the -ing form names one step, as `brainstorming`; the plugin name is a namespace before the colon, and `crafting:github` reads as an action on github); `jig`, `atelier`, `whittle`, `guild`; `adept`, `rite`, `stc`. Decision: plugin `craft`, repository `craft-skills`, marketplace `kalinichenko`. The ADR does not write the old repository name: the spec's grep allows it only in the note and the guide. Consequences: good, a short name that says what the plugin does; bad, every install moves by hand. Invariants: none. Confirmation: the lint line of Task 2.

- [ ] **Step 2: The checks of the spec**

Run:

```bash
make check
git grep -n 'kalinichenko[:]' -- . ':!docs/superpowers' ':!CHANGELOG.md' ':!docs/migrating-from-kalinichenko.md'
git grep -n 'agent-skills' -- . ':!docs/superpowers' ':!CHANGELOG.md' ':!docs/migrating-from-kalinichenko.md' ':!tests/github_scripts_test.sh' ':!tests/roadmap_scripts_test.sh' ':!tests/hooks_scripts_test.sh' ':!tests/fixtures/github' ':!tests/fixtures/roadmap' ':!tests/fixtures/product/logs'
```

Expected: PASS; the first grep prints nothing; the second prints only the note in `README.md`.

- [ ] **Step 3: A load from the branch in Claude Code**

`--plugin-dir` loads the branch as an install does, with the owner's marketplace `kalinichenko` left as it is: a marketplace from the branch would take the same name. The real install from GitHub runs in Task 9.

Run: `claude -p --plugin-dir "$PWD" --settings '{"enabledPlugins":{"kalinichenko@kalinichenko":false},"language":"English"}' --output-format stream-json --verbose 'Load the craft:github skill with the Skill tool, then reply done.' | grep -c '"skill":"craft:github"'`
Expected: `1` or more.

- [ ] **Step 4: A load from the branch in Codex**, in a home of its own, so the owner's Codex stays as it is:

```bash
h=$(mktemp -d) && cp ~/.codex/auth.json "$h/"
CODEX_HOME="$h" codex plugin marketplace add "$PWD"
CODEX_HOME="$h" codex plugin add craft@kalinichenko
CODEX_HOME="$h" codex exec -s read-only --ephemeral 'List the names of the skills you can use, one a line.' | grep -c 'craft:github'
rm -rf "$h"
```

Expected: `1` or more.

- [ ] **Step 5: Commit, then the review**

```bash
git add docs/adr/0002-plugin-name-craft.md docs/ARCHITECTURE.md
git commit -m "docs(adr): record the plugin name craft"
```

Then `craft:review-loop` as the installed `kalinichenko:review-loop` sets it, the PR with `Closes #214` and, under **Also closes**, `Closes #218`, and the merge question. The first `git push` stops once at the docs-review hook: push again after it.

### Task 8: The release

After the merge, on `main`.

- [ ] **Step 1:** `/release`, with no level: the `!` of the squash subject makes it pick `major`. Expected: `v2.0.0`, a line `- (plugin) rename the plugin to craft and the repository to craft-skills (#<PR>) (breaking)`.
- [ ] **Step 2:** Add the link to the notes:

```bash
notes=$(gh release view v2.0.0 --json body --jq .body)
gh release edit v2.0.0 --notes "$notes

Installed it as \`kalinichenko\`? [Move to \`craft\`](https://github.com/kalinichenko88/craft-skills/blob/main/docs/migrating-from-kalinichenko.md)."
```

Expected: `gh release view v2.0.0` shows the link.

### Task 9: The owner's move, and the open issues

- [ ] **Step 1: Move the owner's install by the guide**, in Claude Code and in Codex, step by step, by the main path: the owner's marketplaces were added by the old URL, so the first command of each tool is the spec's check that a marketplace added by the old URL updates. Each command that does not do what the guide says is a fix of the guide, in a new PR. Expected: `claude plugin marketplace update kalinichenko` and `codex plugin marketplace upgrade kalinichenko` exit 0; `claude plugin list` lists `craft@kalinichenko` and no `kalinichenko@kalinichenko`; a Codex session lists `craft:github`.
- [ ] **Step 2: Correct the open issues.** For each of #215, #196, #185, #171, #213 and #87:

```bash
f=$(mktemp)
gh issue view <n> --json body --jq .body >"$f"
perl -pe 's/(?<![\w@-])kalinichenko:/craft:/g; s{kalinichenko88/agent-skills}{kalinichenko88/craft-skills}g; s/`agent-skills`/`craft-skills`/g' "$f" >"$f.new"
diff "$f" "$f.new"
```

Read the diff. Then:

```bash
gh issue edit <n> --body-file "$f.new"
```

Read each diff before the edit. #87 is assigned to the owner, and the owner said on 2026-11-02 that no session works on it, so its body changes too. Then its comment, with the same change: `gh api repos/kalinichenko88/craft-skills/issues/comments/6443347351 --jq .body`, the same `perl`, then `gh api -X PATCH repos/kalinichenko88/craft-skills/issues/comments/6443347351 -F body=@"$f.new"`. #212 gets a one-line comment: the README now has the section of external dependencies, and #212 adds its browser tools there. Closed issues and merged PRs stay.
- [ ] **Step 3: Finishing** of the github skill: `collect.sh filing` with the files of `gh pr diff <PR> --name-only`, and a citations scout. Correct each citation that moved.
