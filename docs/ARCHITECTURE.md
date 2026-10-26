# Architecture

This file holds what the code cannot tell: the modules, the layers, the
patterns of the scripts and the tests, and the invariants that
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
(`skills/debt/scripts/data.ere`). The code they see is every other file
that git tracks: the bash and awk under `skills/`, `hooks/` and `tests/`,
the `Makefile`, and small files as `LICENSE` and `data.ere`. The text of a
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
  works in this repository. No host loads them from the installed plugin:
  its users get `rules.md`.
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

**Direction in text.** `rules.md` names github, review-loop and the two
conventions. architecture names debt, github, roadmap and
react-conventions. debt names github, roadmap and review-loop. roadmap
names github. github and review-loop name each other: one cycle, in text
only.

**Where a module's files are.** A module's test and fixtures are outside its
folder, in `tests/`: the Makefile finds a test by `tests/<name>_test.sh`. So
a change to a script changes two folders.

## Layers

In a skill with scripts:

- the edge is `SKILL.md` and the `.md` files beside it, which the model
  reads to decide which script to run, and the argument check at the top of
  each script;
- the logic is the awk programs and the shell after the argument check;
- the data is the `gh`, `git`, `codex` and `npx` calls.

Where the split does not fit:

- The rules of the product are prose in `SKILL.md`, and the model runs
  them. No code holds them, and no check sees them.
- A script is one file with the roles as sections, not folders. Only
  roadmap moves some of them into files of their own: `read.sh` reads the
  tracker for `roadmap.sh`, `next.sh` and `plan.sh`, and the `.awk` files
  hold the logic that they share.

## Patterns

The first five hold for each script in `skills/*/scripts/`.

1. The header is the contract: what the script does, its
   `#   name.sh <args>` lines, what it refuses, and `DRY_RUN` when it
   writes. A wrong call prints the usage to stderr and exits 2.
2. `set -euo pipefail`. A script that sets an EXIT trap empties `finished`
   before it and sets `finished=1` at each good end; the trap turns an exit
   of 0 without it into 1, because bash 3.2 runs the trap with `$?` at 0
   when `set -u` stops the script. `clean` in
   `skills/github/scripts/collect.sh` is the shape.
3. A script is one file: `run`, `clean` and `usage` are copied, not sourced.
   It finds its siblings by `$(dirname "$0")`.
4. A `SKILL.md` runs a script as `bash <dir>/scripts/<name>.sh`, because
   packaging can drop the executable bit. `<dir>` is the skill's base
   directory, and `<skills>` is the directory above it.
5. A regex goes to awk through `ENVIRON`, not `-v`: `-v` reads a backslash
   as an escape.
6. A test prints `<name>_test: ok` as its last line. `make test` passes a
   test only when it exits 0 and that line is last: under bash 3.2, a
   script that `set -u` stops exits 0 when it has an EXIT trap.
   `tests/makefile_test.sh` checks the harness.
7. ShellCheck reads the paths that the `lint` target of the Makefile lists:
   a new `scripts/` folder joins that line.

## Invariants

A `grep` check finds the usual forms of a breach, not every form: the review
reads for the rest.

- **I-1.** `hooks/rules.sh` MUST escape `rules.md` in bash: it calls no text
  tool, as `jq`, `awk` or `sed`.
  Check: grep `(^|[[:space:]|(;])(jq|awk|sed|grep|tr|cut|perl|python3?)([[:space:]]|$)` in `hooks`.
- **I-2.** A script in `skills/` or `hooks/` MUST NOT call `jq`: a filter is
  `gh`'s own `--jq`, and the hook escapes by hand.
  Check: grep `(^|[[:space:]|(;])jq([[:space:]]|$)` in `skills` `hooks`.
- **I-3.** Bash code MUST run on bash 3.2: no associative array or nameref,
  no `mapfile`, `readarray`, `coproc`, `;&`, `;;&`, `|&` or `[[ -v`, and no
  case change as `${x,,}`.
  Check: grep `(declare|local|typeset)[[:space:]]+-[a-zA-Z]*[An]|mapfile|readarray|coproc|;;?&[[:space:]]*$|\|&[[:space:]]|\[\[[[:space:]]+-v[[:space:]]|\$\{[A-Za-z_0-9]+(\[[^]]*\])?[,^]` in `skills` `hooks` `tests`.
- **I-4.** awk code MUST run on BWK awk, mawk and gawk: no gawk extension.
  Check: grep `gensub|asorti?[[:space:]]*\(|strftime|systime|mktime|strtonum|PROCINFO|IGNORECASE|FPAT|BEGINFILE|ENDFILE|patsplit|@include` in `skills` `hooks` `tests`.
- **I-5.** A script MUST NOT read a file of another skill. The one
  exception is `invariants.sh`, which reads the debt skill's `data.ere`: one
  data rule for `measure.sh`, `clones.sh` and the checks.
  Check: grep `\.\./\.\.|skills/[a-z-]+/` in `skills` `hooks` except `skills/architecture/scripts/invariants.sh`.
- **I-6.** A script that writes to GitHub MUST take `DRY_RUN=1`: then it
  prints each write and runs none. Review only.
- **I-7.** `make test` MUST reach no network and call no model: a fake
  first on `PATH` takes the place of each tool that would. A test that calls
  the model is a `tests/<name>_eval.sh`, which `make test` does not run.
  Review only.

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
- **Safety.** No step of the debt and architecture skills runs the code of
  the project it reads. Nothing from a private source goes into a public
  repository (`kalinichenko:github`).
- **Release.** `/release` alone moves `version` in
  `.codex-plugin/plugin.json` and writes `CHANGELOG.md`.
  `.claude-plugin/plugin.json` carries no `version`.
- **CI.** `make check` on Ubuntu 26.04 with mawk and ShellCheck 0.11.0, and
  a gitleaks scan.

## ADRs

None yet. An accepted ADR goes in `docs/adr/NNNN-title.md` and on this list.
