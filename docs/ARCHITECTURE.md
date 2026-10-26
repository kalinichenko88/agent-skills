# Architecture

This file holds what the code cannot tell: the modules, the layers, the
patterns that every file keeps, and the invariants that
`skills/architecture/scripts/invariants.sh` checks. The principles are in
`kalinichenko:architecture`. The ADRs go in `docs/adr/`.

## Bird's-eye view

The repository is one plugin, `kalinichenko`, for Claude Code and Codex. Its
product is text that a model reads: `rules.md`, the base prompt, and one
`SKILL.md` per skill. The bash scripts next to a skill do the steps that
have one correct result: read the tracker, write the plan, measure the code,
run the checks. The model does the rest.

Both hosts read the same files. `hooks/rules.sh` injects `rules.md` at the
start of each session and each subagent. A skill loads when its
`description` matches the moment. The plugin installs as a copy of the whole
repository.

To the checks, Markdown, JSON and everything under `fixtures/` are data
(`skills/debt/scripts/data.ere`). The code they see is the bash and awk
under `skills/`, `hooks/` and `tests/`, and the `Makefile`. The text of a
skill is the product, but no check sees it: an invariant on it is review
only.

## Codemap

- `rules.md` — the base prompt. `hooks/rules.sh` and `hooks/hooks.json`
  inject it.
- `skills/<name>/` — one skill: `SKILL.md`, `README.md`, the `.md` files
  that `SKILL.md` sends the reader to, and `scripts/`.
- `tests/<name>_test.sh` — the tests that `make check` runs.
  `tests/<name>_eval.sh` — the evals; they call the model and run by hand.
  `tests/fixtures/<area>/` — recorded payloads and trees.
- `docs/<skill>/` — the pictures that a README links, and the brief they
  are drawn from. `docs/superpowers/` — the specs and plans of past work.
- `.claude/skills/` — `release` and `infographic`: skills of this
  repository, not of the plugin.
- `.claude/CLAUDE.md`, `AGENTS.md` — the instructions for an agent that
  works in this repository. The plugin does not give them to its users:
  `rules.md` does that.
- `.claude-plugin/`, `.codex-plugin/` — the manifests. `Makefile` — `check:
  lint test`. `.github/workflows/check.yml` — CI.

## Modules

Each skill is a module, by the area of work it serves.

| Module | Folder | Its test, fixtures and pictures |
| --- | --- | --- |
| rules | `rules.md`, `hooks/` | `tests/rules_test.sh` |
| github | `skills/github/` | `tests/github_scripts_test.sh`, `tests/fixtures/github/`, `docs/github/` |
| roadmap | `skills/roadmap/` | `tests/roadmap_scripts_test.sh`, `tests/fixtures/roadmap/`, `docs/roadmap/` |
| review-loop | `skills/review-loop/` | `tests/review_loop_scripts_test.sh`, `tests/review_loop_eval.sh`, `tests/fixtures/review-loop/` |
| debt | `skills/debt/` | `tests/debt_scripts_test.sh`, `tests/fixtures/debt/` |
| architecture | `skills/architecture/` | `tests/architecture_scripts_test.sh` |
| docker, typescript-conventions, react-conventions | `skills/<name>/` | text only; `tests/skill_load_eval.sh`, `tests/skill_load_checks_test.sh` and `tests/fixtures/skill_load/` count the loads of the two conventions |
| release, infographic | `.claude/skills/<name>/` | none |
| plugin | `.claude-plugin/`, `.codex-plugin/`, `Makefile`, `.github/` | `tests/makefile_test.sh` |

**Public API.** A skill's API is its `SKILL.md`, whose `description` is the
trigger, and the usage block at the top of each script in `scripts/`. The
other `.md` files are read when `SKILL.md` sends the reader there. One skill
uses another by its name, `kalinichenko:<name>`, in text, or by a script's
usage block. In code, one link exists: `invariants.sh` reads the debt
skill's `data.ere` (I-5).

**Direction in text.** `rules.md` names github, roadmap, review-loop and the
two conventions. architecture names debt, github and roadmap. debt names
github and roadmap. roadmap names github. github names roadmap and
review-loop, and both name github back: two cycles, in text only.

**Where a module's files are.** A module's test and fixtures are outside its
folder, in `tests/`: the Makefile finds a test by `tests/<name>_test.sh`. So
a change to a script changes two folders.

## Layers

In a skill with scripts:

- the edge is `SKILL.md` and the `.md` files beside it, which the model
  reads to decide which script to run, and the usage block of each script
  with its argument check (`usage`, exit 2);
- the logic is the awk programs (`skills/roadmap/scripts/*.awk`, and the
  awk inside `invariants.sh`, `measure.sh` and `collect.sh`) and the shell
  after the argument check;
- the data is the `gh`, `git`, `codex` and `npx` calls. `read.sh` and
  `collect.sh` are data only: they turn the tracker into records, or into
  one file, for the others.

Where the split does not fit:

- The rules of the product are prose in `SKILL.md`, and the model runs
  them. No code holds them, and no check sees them.
- A script is one file with the roles as sections, not folders. Only
  roadmap splits them into files: `read.sh` (data), `graph.awk` and the
  other `.awk` programs (logic), `roadmap.sh`, `next.sh`, `plan.sh` and
  `board.sh` (edge).

## Patterns

1. A script's header is its contract: what it does, `#   name.sh <args>`
   lines, what it refuses, `DRY_RUN`, and a `Needs` line. `usage` prints
   the usage to stderr and exits 2.
2. Exit codes: 0, done; 1, a refusal or a finding, so the step is not done
   and the reader decides; 2, a wrong call or a check that cannot run. An
   error goes to stderr as `name.sh: <why>`.
3. `set -euo pipefail`. A script that sets an EXIT trap empties `finished`
   before it and sets `finished=1` at each good end; the trap turns an exit
   of 0 without it into 1, because bash 3.2 runs the trap with `$?` at 0
   when `set -u` stops the script. `clean` in
   `skills/github/scripts/collect.sh` is the shape.
4. A script is one file: `run`, `clean` and `usage` are copied, not sourced.
   It finds its siblings by `$(dirname "$0")`. A `SKILL.md` runs it as
   `bash <dir>/scripts/<name>.sh`, where `<dir>` is the skill's base
   directory and `<skills>` the directory above: packaging can drop the
   executable bit.
5. A regex or a path goes to awk through `ENVIRON`, not `-v`: `-v` reads a
   backslash as an escape.
6. A test: `set -eu`, `tmp=$(mktemp -d)`, `trap 'rm -rf "$tmp"' EXIT`,
   `fail`, `check`, and the last line `echo '<name>_test: ok'`. `make test`
   passes a test only when it exits 0 and that line is last.
   `tests/makefile_test.sh` checks the harness. A fake `gh`, `codex`, `npx`
   or `claude` in `$tmp/bin`, first on `PATH`, answers from
   `tests/fixtures/<area>/` and logs its calls.
7. ShellCheck reads the paths that the `lint` target of the Makefile lists:
   a new `scripts/` folder joins that line.

## Invariants

- **I-1.** `hooks/rules.sh` MUST need only bash: it calls no other program.
  Check: grep `(^|[ |(])(jq|awk|sed|grep|tr|cut|perl|python3?)( |$)` in `hooks`.
- **I-2.** A script in `skills/` or `hooks/` MUST NOT call `jq`: a filter is
  `gh`'s own `--jq`, and the hook escapes by hand.
  Check: grep `(^|[ |(;])jq( |$)` in `skills` `hooks`.
- **I-3.** Bash code MUST run on bash 3.2: no associative array, `mapfile`,
  `readarray`, `coproc`, `;;&` or case change as `${x,,}`.
  Check: grep `declare -A|mapfile|readarray|coproc|;;&|\$\{[A-Za-z_]+(,,|\^\^)` in `skills` `hooks` `tests`.
- **I-4.** awk code MUST run on BWK awk, mawk and gawk: no gawk extension.
  Check: grep `gensub|asorti?\(|strftime|systime|mktime|PROCINFO|IGNORECASE|FPAT|BEGINFILE|ENDFILE|patsplit` in `skills` `hooks` `tests`.
- **I-5.** A script MUST read only the files of its own skill. The one
  exception is `invariants.sh`, which reads the debt skill's `data.ere`: one
  data rule for `measure.sh`, `clones.sh` and the checks.
  Check: grep `\.\./\.\./|skills/[a-z-]+/` in `skills` `hooks` except `skills/architecture/scripts/invariants.sh`.
- **I-6.** A script that writes to GitHub MUST take `DRY_RUN=1`: then it
  prints each write and runs none. Review only.
- **I-7.** `make check` MUST reach no network and call no model: a test
  replaces the tool with a fake on `PATH`. A script that calls the model is
  a `tests/<name>_eval.sh`. Review only.

## Limits of decomposition

From the sizes on 2026-10-26: 34 code files, and the 31st smallest (90%)
has 330 lines; 8 folders hold code files of their own, and the largest two
hold 10. A new number needs an ADR.

- **I-8.** A code file MUST have at most 330 lines.
  Check: lines 330 in `.` debt `skills/architecture/scripts/invariants.sh` `tests/github_scripts_test.sh` `tests/roadmap_scripts_test.sh`.
- **I-9.** A folder MUST hold at most 10 code files of its own. `tests/` is
  out of the check: it stays flat, because the Makefile finds a test only as
  `tests/<name>_test.sh`.
  Check: files 10 in `.` except `tests`.

## Cross-cutting concerns

- **Two hosts.** A step that one host cannot do names the other way: Codex
  has no subagent with a model, so it does each such step itself. A change
  to `hooks/hooks.json` is a major release: Codex users must trust the
  hooks again.
- **Portability.** bash 3.2 on macOS, three kinds of awk, Git Bash on
  Windows, NixOS with no `/bin/bash`: every script starts with
  `#!/usr/bin/env bash`, and every file is LF (`.gitattributes`).
  `tests/rules_test.sh` checks both.
- **Size.** `rules.md` stays under 10,000 characters, Claude Code's cap on
  hook context; `tests/rules_test.sh` checks it. Pictures are WebP, since
  the plugin installs as a copy of the repository.
- **Safety.** No script runs the code of the project it works in. A write
  reads its target again just before it. Nothing from a private source goes
  into a public repository (`kalinichenko:github`).
- **Release.** `/release` alone moves `version` in
  `.codex-plugin/plugin.json` and writes `CHANGELOG.md`.
  `.claude-plugin/plugin.json` carries no `version`.
- **CI.** `make check` on Ubuntu 26.04 with mawk and ShellCheck 0.11.0, and
  a gitleaks scan.

## ADRs

None yet. An accepted ADR goes in `docs/adr/NNNN-title.md` and on this list.
