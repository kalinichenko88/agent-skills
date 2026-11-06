# Contributing

How to work on the `craft` plugin itself. For how to use it, see the [README](README.md).

## Develop

`make check` validates the manifests, runs shellcheck, checks the invariants of
`docs/ARCHITECTURE.md` with the architecture skill's `invariants.sh`, and
replays `rules.md` through the hook, part by part, to prove that the two parts
and the marker line between them rebuild the file byte for byte, and that each
part stays within Claude Code's 10,000-character cap on one hook context,
starts with its own heading, and runs under each event from
`hooks/hooks.json`. It checks that a checkout with `core.autocrlf=true`, the
Git for Windows default, keeps every text file in LF, that the hook still
gives the rules from a CRLF `rules.md`, that every script starts with
`#!/usr/bin/env bash`, and that every `- ` line of `CHANGELOG.md` starts with
its scope in parentheses. It fails on a skill name with the plugin's old
prefix outside the history and the migration guide, and on a heredoc in the
text of a skill or of `rules.md`: a prompt to Codex goes through a file.
Outside the history and the Makefile, it fails on a line that holds
`gh auth refresh` and no `-h github.com` or `--hostname github.com`: with no
terminal, as under `!` in Claude Code, `gh` needs the host. It
also runs the github and roadmap skills' scripts
against a fake `gh` that answers from payloads recorded
in `tests/fixtures/github/` and `tests/fixtures/roadmap/`, all from public
repositories, the debt skill's `measure.sh` on a repository the test builds,
and its `clones.sh` against a fake `npx` that answers with a report recorded
from `jscpd` for the tree in `tests/fixtures/debt/`, and with a fake `bunx`
when `bun` is installed. Without `node`, the test skips `clones.sh` and says
so. One case runs `clones.sh` with no `TMPDIR`, so it makes and removes a
directory in your `~/.cache`. The review-loop skill's `codex-review.sh` runs
against a fake `codex` that answers with findings recorded from `codex exec`
on this repository, in `tests/fixtures/review_loop/`. The session-title
hook runs on prompts recorded from Claude Code and Codex, in
`tests/fixtures/hooks/`, against a fake `gh`. The architecture skill's
`invariants.sh` runs on repositories the tests build: each kind of check, the
`debt` lists, `--new-since` over renamed files, changed checks and a base
file that it cannot read, and the calls that must exit 2.

`make check` runs every `tests/<name>_test.sh`. A test passes only when it
exits 0 and its last non-empty line on stdout is `<name>_test: ok`: under bash
3.2, a script that `set -u` stops exits 0 when it has an EXIT trap.
`tests/makefile_test.sh` checks this rule. A new test script ends with its `ok`
line.

GitHub Actions runs `make check` on each pull request and each push to `main`
(`.github/workflows/check.yml`). It runs on Ubuntu 26.04, with its ShellCheck
0.11.0 and with `mawk` as `awk`; `make check` on macOS runs BWK awk. A second
job runs gitleaks on the new commits. The eval scripts below call the model, so
they do not run there.

A skill script that sets an EXIT trap under `set -u` empties `finished` before
the trap and sets `finished=1` at each end that succeeds. Its trap turns an exit
status of 0 without that flag into 1: bash 3.2 runs the trap with `$?` at 0 when
`set -u` stops the script. `clean` in `skills/github/scripts/collect.sh` shows
the shape.

To try a script that writes on a real tracker without writing to it, set
`DRY_RUN=1`. `GH_REPO=<owner/repo>` points `collect.sh`, `take-in-check.sh`,
`add-finding.sh` and the roadmap scripts at another repository than the
checkout's.

To try an edit in Claude Code without installing: `claude --plugin-dir .`.

`tests/skill_load_eval.sh` counts the Haiku subagents that load the conventions
skills, the files they write with an implicit return in a method callback, as
`.map((x) => (`, the runs with a file that opens with a helper or a constant
instead of its primary export, the runs that put the order, its line, the
customer or the discount outside `models/` or two of them in one file, and the
runs whose discount file opens with its variants instead of the union. It
counts the runs that keep a 30-line table of decline messages out of
`constants.ts`, or put their short fallback message in it. In every task, it
counts the runs that name a module-level `const` with a literal value in
camelCase, or any other `const` in CONSTANT_CASE. In a
React feature, it counts the runs that put a sub-component's own hook at the
feature root or in `shared`, and the runs with a zod schema outside
`schemas/`. In the three React tasks, it counts the runs with a component or a
hook that holds two requests or more: a comments section loads and sends
comments, and the other two tasks have one request each. With
`--check <logs folder>` it runs only these checks, on the logs that an earlier
run printed. `tests/skill_load_checks_test.sh` runs them so in `make check`,
on `tests/fixtures/skill_load`: four recorded runs and a case that fails each
check. A change to a check updates the output that the test expects.
`tests/review_loop_eval.sh` counts the review rounds and what each one reads.
It checks that no count of rounds goes past three, that the review of the
tests runs once next to the last pass and never without one, that the
review of the architecture runs once before round 2, and that a security
review follows the last pass, in a subagent and not in the session. Its
fixture has a local `origin` and an architecture file, and its task says
that no one can answer questions. With `stop` after the count of runs, as
`tests/review_loop_eval.sh 3 stop`, a run starts at the stop after round 3
of an `xhigh` review: the eval checks one Codex read, no fourth round, the
defects of round 3 and of Codex left unfixed, and a security review in a
subagent. A fake `codex` first on `PATH` returns the defect of Codex, and an
empty Codex home keeps a real `codex` from a read, so no run spends the
Codex limit. Run it after a change to
`skills/review-loop` or to its section in `rules.md`.
`tests/review_loop_lens_eval.sh` sends the review of the architecture to six
branches of one fixture: a second HTTP client, a `fetch` call that breaks an
invariant, the same call with an ADR that amends it, a base that breaks it
already, a folder with no code file added to the `Check:` line of an
invariant, and that folder taken out again on a base where a second
invariant names one too. With `--codex`, Codex reads the six branches with
the same prompt. Run it after a change to
`skills/review-loop/architecture-lens.md` or to the parts of
`skills/architecture/SKILL.md` that it reads.
`tests/debt_lens_eval.sh` sends the review of the instruction files to a
monorepo whose `CLAUDE.md` files repeat and contradict its architecture file
and each other. It checks each repeat, contradiction, redundancy and
citation of the fixture, that the Environment section, which has no copy,
gets no finding, and that a symlink and a pair of `CLAUDE.md` and
`AGENTS.md` of one folder are no repeat. With `--codex`, Codex reads it with
the same prompt. Run it after a change to `skills/debt/instructions-lens.md`.
`tests/architecture_eval.sh` gives three tasks to Opus in a shop whose one
module wraps every HTTP call, in four arms: no architecture file and no
skill; the file and a link from `CLAUDE.md`; the same and the skill; the same
and the `CLAUDE.md` line. It counts the runs that use the wrapper, write the
block of *The start of a feature*, write one ADR for a new data store, split
a file past its limit in a commit before the feature, and load the skill
before the first write. It also counts how often `haiku` and `sonnet` find
the code that a task can use. Run it after a change to the description of
`craft:architecture`. `tests/architecture_checks_test.sh` runs its
checks in `make check`, on `tests/fixtures/architecture`: one recorded run,
and a case for each verdict that the run does not show. It also runs the eval
once with a stub `claude` in the place of the model.
`tests/product_eval.sh` runs Opus on a site of 1000 brands, where a branch
redirects 7 of them to an icon that the page's CSP blocks. It counts the
runs that check the worth before a review, a feature, a fork in brainstorming
and a teammate's branch, and the runs that check it again after a review
finds that the feature shows nothing; it prints those texts, to count by hand
the runs that rebuild the feature. Three more shapes count the runs that do
not check it: a bug fix, a branch with a report, and a question that asks the
person to describe. One counts the answers that record a decision in a
project's own decisions file. The feature's shape needs a Codex login. Run it
after a change to `skills/product`, to the start of a feature in
`craft:architecture` or to *Worth first* of review-loop.
`tests/product_checks_test.sh` runs its checks in `make check`, on recorded
logs in `tests/fixtures/product/logs`.
`tests/review_loop_lens_checks_test.sh` checks that the lens eval refuses a
wrong call before it starts a paid run.
`tests/github_scout_eval.sh` sends the citations job of the github skill's
scout to Haiku, with the decisions of #217, as *Finishing* sends it. The
tree is the merge commit of #217, and the issues are #117, #205 and #179 with
the title, the body and the comments they had then, recorded in
`tests/fixtures/github/`. #117 still says that `rules.md` has 337 characters
left, and cites no line of it; the title of #205 says it too; #179 has a
citation that moved, and no sentence that a decision made false. The eval
checks that the scout gives a sentence of #117 and the title of #205 as false,
no sentence of #179, and the moved citation of #179.
It needs the history of the checkout down to #217. Run it after a change to
the citations job of `skills/github/scout.md` or to *Finishing*.
`tests/scenarios_eval.sh` runs craft on three scenarios of
`scenarios/github/take-in.md`: a free task, a task that another person is
assigned to, and a tracker that does not answer. Each case is one Opus run of
`claude -p` with this checkout as the only plugin, a fake `gh` first on
`PATH` that reads and writes a JSON tracker, and a workspace with a local
`origin`. It checks each Then and Never item of the three scenarios against
the tracker, the branches, the workspace, and the session's messages and
tool calls, and prints PASS, FAIL or SKIP for each: SKIP where the log holds
a message only as thinking (#206). Run it after a change to
`skills/github/take-in.md` or to the scripts of the github skill.
`tests/scenarios_checks_test.sh` runs its checks in `make check`, on one
recorded run of each case in `tests/fixtures/scenarios/`, and on copies that
change the verdict of one item.
The `_eval.sh` scripts call the model, so their runs are not part of
`make check`.

The pictures in `docs/` are drawn by Codex from the brief next to them, as
`docs/github/brief.md`. To change a picture, change its brief and run
`/infographic` in Claude Code from this repository. Like `/release`, it lives
in `.claude/skills/` and does not ship with the plugin.

## Release

Pull requests leave `version` alone. Once the work is on `main`, run `/release`
in Claude Code from this repository, or `/release minor` to pick the level. It
bumps `.codex-plugin/plugin.json`, writes the `CHANGELOG.md` section, tags
`vX.Y.Z`, pushes both and publishes a GitHub release with that section as its
notes. The skill lives in `.claude/skills/`, not `skills/`, so it does not ship
with the plugin.
