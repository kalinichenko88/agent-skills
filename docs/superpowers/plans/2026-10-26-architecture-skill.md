# The architecture skill (#96) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `kalinichenko:architecture`: its `SKILL.md`, and
`invariants.sh`, which runs the `Check:` lines of a project's
`docs/ARCHITECTURE.md`, with its test in `make check`.

**Architecture:** One bash script, `skills/architecture/scripts/invariants.sh`.
An awk parser turns the architecture file into one record per invariant. A
`hits` step lists what each check finds in one tree, through `git grep`. An awk
`report` step sorts the hits into FAIL hits, known debt and no longer debt,
and with `--new-since` marks the hits that the base does not have. The skill's
text is a `SKILL.md` and one file beside it.

**Tech Stack:** bash 3.2 or newer, git, awk. The test builds git repositories
in a temporary directory, as `tests/debt_scripts_test.sh` does.

**Spec:** `docs/superpowers/specs/2026-10-25-architecture-skill-design.md`.
The sections that this plan builds: *The project's files*, *The start of a
feature*, *The moment of a decision*, *Modules and layers*, *Decomposition*,
*ADRs*, *A first `docs/ARCHITECTURE.md`*, *`invariants.sh`*, *Models*. The
sections on #97, #98, #99 and #100 are later pull requests.

## Global Constraints

- Bash 3.2, the bash of macOS: no associative arrays, no `mapfile`, no
  `${x,,}`. Maps live in awk.
- Tools: bash, git and awk only. No `jq`, no `npx`.
- The first line of a script is `#!/usr/bin/env bash`, then `set -euo pipefail`
  and `unset CDPATH`. shellcheck is clean.
- No `eval`, no `sh -c`, no text of the architecture file as a command. Each
  `git grep` call gets the pattern as its own argument after `-e`, the paths
  after `--`, and `git --literal-pathspecs`, so a path is never pathspec magic.
- Every git call that prints paths runs with `-c core.quotePath=false`.
- Code and data are told apart by `skills/debt/scripts/data.ere`, read as
  `measure.sh` reads it, and passed to awk through `ENVIRON`, because `awk -v`
  turns `\.` into any character.
- Prose in Simplified Technical English. Code, comments and commit messages in
  English, commit subjects in the `type(scope): sentence` shape of
  `kalinichenko:github`.
- No change to `rules.md`, `CHANGELOG.md`, or the github, roadmap and debt
  skills.
- The test ends with the line `architecture_scripts_test: ok`.

## The `Check:` line

The spec leaves the exact syntax to the builder. This plan fixes it, and every
task uses it.

An invariant starts at a line `- **I-<n>.** <statement>`. The indented lines
under it, up to the next line that does not start with a space, belong to it.
Lines inside a fenced code block (between two lines that start with three
backticks) are skipped. A trailing `\r` is removed from each line.

```
  Check: grep `<ERE>` in `<path>`... [except `<path>`...] [debt `<path>`...]
  Check: lines <N> in `<path>`... [except `<path>`...] [debt `<path>`...]
  Check: files <N> in `<path>`... [except `<path>`...] [debt `<path>`...]
  debt `<path>`...
```

- Each pattern and path is in backticks, so it can hold spaces but not a
  backtick. Items are separated by spaces, and a comma may follow an item.
  A `.` may end the line.
- A line `debt` and paths, indented and right after the `Check:` line, adds to
  its `debt` list.
- A path is literal, from the root of the repository: a file or a folder, with
  or without a trailing `/`. A path P is under an entry E when P is E, or P
  starts with E and `/` (E without its trailing `/`).
- `except` paths leave the check before it runs: their files are not read.
  `debt` paths sort its hits: a hit under a `debt` path is known debt.
- An invariant with no `Check:` line is review only.
- Any other text after `Check:` is a line that the script cannot read.

## The output

```
I-1 FAIL
  src/feature/list.ts:2:const r = fetch('/list');
  new src/feature/b.ts:1:fetch(v);
  debt src/legacy/summary.ts:12:fetch(x);
I-2 PASS
  new debt src/legacy/grow.ts 14
  no longer debt src/legacy/old.ts
I-4 review only
```

- One line per invariant, in the file's order: `I-<n> PASS`, `I-<n> FAIL` or
  `I-<n> review only`. FAIL when one hit is not under a `debt` path.
- Under it, two spaces, then its lines, in this order: the hits that are not
  debt; the hits under a `debt` path, after the word `debt`; then each `debt`
  entry with no hit, as `no longer debt <entry without its trailing />`.
  Inside each group, the hits sort by path (bytes, `LC_ALL=C`), then by line
  number.
- A `grep` hit is `<path>:<line>:<text>`, as git prints it. A `lines` hit is
  `<file> <lines>`. A `files` hit is `<folder> <files>`, the folder with no
  trailing `/`.
- With `--new-since`, the word `new` comes first on each hit that the base
  does not have.
- With no architecture file: one line, `No architecture file in the working
  tree.` or `No architecture file at <ref as given>.`, and exit 0.
- Exit 0 when no invariant fails, 1 when one fails, 2 for a wrong call or a
  check that the script cannot run. A status 2 prints one line on stderr that
  starts with `invariants.sh: `.

## Review Focus

1. A path with non-ASCII letters, as `src/feature/заказ.ts`: printed as it is,
   not as `"\320..."`. Test in Task 1.
2. A typo in a path, as `srcx/`: an invariant that reads no file would pass
   forever. A path of `in` with no code file at the tree that the script reads
   is exit 2: `invariants.sh: I-<n>: no code file under <path>`. The base of
   `--new-since` is not checked for it. Test in Task 1.
3. An example invariant in a fenced code block of the file: skipped. Test in
   Task 1.
4. An architecture file with CRLF line ends, as a Windows checkout with
   `core.autocrlf=true` gives: the same output. Test in Task 1.
5. A run from a subdirectory: the script goes to the root of the repository
   first, as `measure.sh` does. Test in Task 1.

---

### Task 1: `invariants.sh`: the parser and the `grep` check

**Files:**
- Create: `skills/architecture/scripts/invariants.sh`
- Create: `tests/architecture_scripts_test.sh`
- Modify: `Makefile` (the `shellcheck` line of `lint`: add
  `skills/architecture/scripts/*.sh`)

**Interfaces:**
- Produces, inside `invariants.sh`:
  - the call `invariants.sh [--new-since <base>] [ref]`. With no ref, it reads
    the working tree, with untracked files that git does not ignore
    (`git grep --untracked`). With a ref, it reads that commit; the script
    resolves it once to a SHA. A ref that is not a commit is exit 2:
    `invariants.sh: not a commit: <ref>`. A wrong count of arguments is exit 2
    with `usage: invariants.sh [--new-since <base>] [ref]`.
  - `parse` (awk, reads the architecture file on stdin): one record per
    invariant on stdout, fields separated by `\036`, list items by `\037`:
    `id kind arg in except debt`, with `kind` one of `grep`, `lines`,
    `files`, `review`. On a line it cannot read, it prints
    `invariants.sh: I-<n>: cannot read: <the line, trimmed>` on stderr and the
    script exits 2.
  - `hits <tree> <kind> <arg> <in> <except>` (bash, `<tree>` a SHA or empty for
    the working tree): stdout lines `path<TAB>n<TAB>text`; for `grep`, `n` is
    the line number and `text` the line; for `lines`, `n` is the count of
    lines and `text` is empty; for `files`, `path` is a folder and `n` its
    count of code files. Data files and `except` paths are dropped. This task
    builds `grep`; Task 2 adds `lines` and `files`.
  - `report` (awk): reads the hits and the `debt` list of one invariant, prints
    its block as *The output* says, and sets the exit status. Task 2 adds the
    debt groups; Task 3 adds `new`.

- [ ] **Step 1: Write the failing test**

`tests/architecture_scripts_test.sh`, with the harness of
`tests/debt_scripts_test.sh`: `set -eu`, `root`, a `tmp` with an EXIT trap,
`fail`, `check`, the `color.ui=always` guard, and a `commit` function. It
builds `$repo` with `git init -q -b main` and these files:

| File | Content |
| --- | --- |
| `src/api/client.ts` | `export const get = (u) => fetch(u);` |
| `src/feature/list.ts` | `import { get } from '../api/client';` then `const r = fetch('/list');` |
| `src/feature/заказ.ts` | `fetch('/order');` |
| `src/notes.md` | `fetch( in a document` |
| `src/styles/a.css` | `.x { -webkit-box: 1; }` |

and `docs/ARCHITECTURE.md`:

````markdown
# Architecture

```markdown
- **I-9.** An example in a fence.
  Check: grep `nothing` in `src/`.
```

## Invariants

- **I-1.** Only `src/api/client.ts` calls `fetch`.
  Check: grep `fetch\(` in `src/` except `src/api/client.ts`.
  ADR: 0001.
- **I-2.** No vendor prefix in styles.
  Check: grep `-webkit-` in `src/styles/`.
- **I-3.** A pattern is never a command.
  Check: grep `$(touch pwned)` in `src/`.
- **I-4.** Modules talk through their index files.
````

It commits them, then checks, each with `check '<name>' <want> <got>`. A
check that changes the tree puts it back after it (`git checkout -- .` and
removing what it added):

```bash
want=$(printf '%s\n' 'I-1 FAIL' \
  "  src/feature/list.ts:2:const r = fetch('/list');" \
  "  src/feature/заказ.ts:1:fetch('/order');" \
  'I-2 FAIL' '  src/styles/a.css:1:.x { -webkit-box: 1; }' \
  'I-3 PASS' 'I-4 review only')
# 'the working tree': out=$(cd "$repo" && bash "$inv") with exit 1, out = want
# 'a pattern runs no command': no file named pwned in $repo or $repo/src
# 'a subdirectory': the same run from $repo/src gives want
# 'CRLF': the file rewritten with \r\n line ends gives want
# 'the root file': the file moved to ARCHITECTURE.md at the root gives want
# 'a ref': after commit, an untracked src/feature/new.ts with `fetch(n);` is in
#   the run with no ref ("  src/feature/new.ts:1:fetch(n);" after list.ts),
#   and not in `bash "$inv" HEAD`
# 'no file': a repository with none prints
#   'No architecture file in the working tree.', and with HEAD
#   'No architecture file at HEAD.', both exit 0
# 'a line it cannot read': `Check: grep fetch in src/` exits 2, and stderr is
#   'invariants.sh: I-1: cannot read: Check: grep fetch in src/'
# 'a typo in a path': `Check: grep `fetch\(` in `srcx/`.` exits 2, and stderr
#   is 'invariants.sh: I-1: no code file under srcx/'
# 'not a commit': `bash "$inv" nosuchref` exits 2,
#   stderr 'invariants.sh: not a commit: nosuchref'
# 'usage': `bash "$inv" a b` exits 2
```

The last line of the test is `echo 'architecture_scripts_test: ok'`.

- [ ] **Step 2: Run the test to see it fail**

Run: `bash tests/architecture_scripts_test.sh`
Expected: FAIL on the first check, because `invariants.sh` does not exist.

- [ ] **Step 3: Write `invariants.sh` with `parse`, `hits` for `grep`, and `report` for PASS, FAIL and review only**

The header comment says what the script does, how to call it, and what it
needs, in the shape of the header of `measure.sh`. It goes to
`git rev-parse --show-toplevel` first. It reads the architecture file at the
ref with `git show <sha>:docs/ARCHITECTURE.md`, then `ARCHITECTURE.md`; with no
ref, from the working tree. The `grep` hits come from
`git -c core.quotePath=false --literal-pathspecs grep --null -n -I -E -e <ERE> [--untracked | <sha>] -- <in>...`:
each line is `[<sha>:]<path>\0<n>\0<text>`. Exit 1 of `git grep` is no hit;
any other non-zero status is exit 2 with `invariants.sh: I-<n>: git grep failed`.

- [ ] **Step 4: Run the test to see it pass, and shellcheck**

Run: `bash tests/architecture_scripts_test.sh && shellcheck skills/architecture/scripts/*.sh tests/architecture_scripts_test.sh`
Expected: the last line `architecture_scripts_test: ok`, and no shellcheck
output.

- [ ] **Step 5: Commit**

```bash
git add skills/architecture/scripts/invariants.sh tests/architecture_scripts_test.sh Makefile
git commit -m "feat(architecture): add invariants.sh with the grep check"
```

### Task 2: the `lines` and `files` checks, and the `debt` list

**Files:**
- Modify: `skills/architecture/scripts/invariants.sh`
- Modify: `tests/architecture_scripts_test.sh`

**Interfaces:**
- Consumes: `parse`, `hits` and `report` of Task 1.
- Produces: `hits` for `lines` and `files`, from
  `git -c core.quotePath=false --literal-pathspecs grep -I -c '' [--untracked | <sha>] -- <in>...`
  less data files and `except` paths. A `files` hit counts the code files of a
  folder of its own, not those of its subfolders; the root folder is `.`.
  `report` prints the `debt` and `no longer debt` lines.

- [ ] **Step 1: Write the failing test**

A second repository, `$repo2`, built in the test:

| File | Content |
| --- | --- |
| `src/feature/big.ts` | `seq 11` |
| `src/feature/small.ts` | `seq 3` |
| `src/legacy/report.ts` | `seq 11`, then `fetch(x);` (12 lines) |
| `src/notes.md` | `seq 50` (data: not counted) |
| `src/many/m1.ts` to `m4.ts` | `echo 1` each |
| `src/many/sub/s1.ts`, `s2.ts` | `echo 1` each |

`docs/ARCHITECTURE.md`:

```markdown
- **I-1.** No code file in `src/` has more than 10 lines.
  Check: lines 10 in `src/` debt `src/legacy/report.ts`
  debt `src/legacy/old.ts`.
- **I-2.** No folder in `src/` holds more than 3 code files of its own.
  Check: files 3 in `src/`.
- **I-3.** The same, with the folder as debt.
  Check: files 3 in `src/many/` debt `src/many/`.
- **I-4.** No `fetch` outside the API client.
  Check: grep `fetch\(` in `src/` debt `src/legacy/report.ts`.
```

```bash
want=$(printf '%s\n' 'I-1 FAIL' '  src/feature/big.ts 11' \
  '  debt src/legacy/report.ts 12' '  no longer debt src/legacy/old.ts' \
  'I-2 FAIL' '  src/many 4' \
  'I-3 PASS' '  debt src/many 4' \
  'I-4 PASS' '  debt src/legacy/report.ts:12:fetch(x);')
# 'lines, files and debt': out=$(cd "$repo2" && bash "$inv"), exit 1
```

- [ ] **Step 2: Run the test to see it fail**

Run: `bash tests/architecture_scripts_test.sh`
Expected: FAIL at `lines, files and debt`: `lines` is a line that the Task 1
parser cannot read.

- [ ] **Step 3: Add `lines` and `files` to `hits`, and the debt groups to `report`**

- [ ] **Step 4: Run the test to see it pass, and shellcheck**

Run: `bash tests/architecture_scripts_test.sh && shellcheck skills/architecture/scripts/*.sh tests/architecture_scripts_test.sh`
Expected: `architecture_scripts_test: ok`, no shellcheck output.

- [ ] **Step 5: Commit**

```bash
git add skills/architecture/scripts/invariants.sh tests/architecture_scripts_test.sh
git commit -m "feat(architecture): add the lines and files checks and the debt list"
```

### Task 3: `--new-since <base>`

**Files:**
- Modify: `skills/architecture/scripts/invariants.sh`
- Modify: `tests/architecture_scripts_test.sh`

**Interfaces:**
- Consumes: `parse`, `hits`, `report`.
- Produces: `--new-since <base> [ref]`. It parses the checks at the ref (or
  the working tree) and runs `hits` with them on the ref and on the base. The
  renames come from
  `git -c core.quotePath=false diff -M --name-status <base> [<sha>]`: each
  `R<n>` line maps the new path to the old one. `report` then marks `new`:
  - a `grep` hit: the key is its old path (the new path when not renamed) and
    its text. When the ref has more hits with one key than the base has, the
    extra ones, the last by line number, are new.
  - a `lines` hit: new when the base has no hit at its old path, or a smaller
    one there.
  - a `files` hit: the same, by the folder's own path, with no rename.
  A base that is not a commit is exit 2: `invariants.sh: not a commit: <base>`.
  The base needs no architecture file.

- [ ] **Step 1: Write the failing test**

A third repository, `$repo3`, with two commits.

The base commit, with no architecture file:

| File | Content |
| --- | --- |
| `src/api/client.ts` | `export const get = (u) => fetch(u);` |
| `src/feature/a.ts` | `const x = 1;` then `fetch(u);` |
| `src/legacy/report.ts` | `seq 11`, then `fetch(x);` (12 lines) |
| `src/legacy/grow.ts` | `seq 11` |
| `src/many/m1.ts` to `m4.ts` | `echo 1` each |
| `tools/migrate.ts` | `seq 15` |

The head commit:

- `git mv src/legacy/report.ts src/legacy/summary.ts`, with no edit;
- `src/legacy/grow.ts` becomes `seq 14`;
- `src/feature/a.ts` gets a third line, `fetch(u);`;
- a new `src/feature/b.ts`: `fetch(v);`;
- `git mv tools/migrate.ts src/cli/migrate.ts`;
- a new `src/many/m5.ts`: `echo 1`;
- a new `docs/ARCHITECTURE.md`:

```markdown
- **I-1.** Only `src/api/client.ts` calls `fetch`.
  Check: grep `fetch\(` in `src/` except `src/api/client.ts` debt `src/legacy/summary.ts`.
- **I-2.** No code file in `src/` has more than 10 lines.
  Check: lines 10 in `src/` debt `src/legacy/summary.ts`
  debt `src/legacy/grow.ts`.
- **I-3.** No folder in `src/` holds more than 3 code files of its own.
  Check: files 3 in `src/` debt `src/many/`.
```

```bash
want=$(printf '%s\n' 'I-1 FAIL' \
  '  src/feature/a.ts:2:fetch(u);' \
  '  new src/feature/a.ts:3:fetch(u);' \
  '  new src/feature/b.ts:1:fetch(v);' \
  '  debt src/legacy/summary.ts:12:fetch(x);' \
  'I-2 FAIL' '  new src/cli/migrate.ts 15' \
  '  new debt src/legacy/grow.ts 14' '  debt src/legacy/summary.ts 12' \
  'I-3 PASS' '  new debt src/many 5')
# 'new since the base': bash "$inv" --new-since "$base" HEAD, exit 1, out = want
# 'new since the base, working tree': bash "$inv" --new-since "$base" on the
#   clean tree gives want too
# 'no file at the ref': --new-since "$base" "$base" prints
#   'No architecture file at <the SHA as given>.' and exits 0
# 'a base that is not a commit': --new-since nosuchref exits 2
```

`a.ts:2` is old: the base has one `fetch(u);` in `a.ts`. `summary.ts` is old
by its rename, in both checks. `migrate.ts` is new: it came into `src/`, and
the base run of I-2 did not read `tools/`.

- [ ] **Step 2: Run the test to see it fail**

Run: `bash tests/architecture_scripts_test.sh`
Expected: FAIL at `new since the base`: `--new-since` is a wrong call.

- [ ] **Step 3: Add `--new-since` to the call, the base run and the renames, and `new` to `report`**

- [ ] **Step 4: Run the test to see it pass, and shellcheck**

Run: `bash tests/architecture_scripts_test.sh && shellcheck skills/architecture/scripts/*.sh tests/architecture_scripts_test.sh`
Expected: `architecture_scripts_test: ok`, no shellcheck output.

- [ ] **Step 5: Commit**

```bash
git add skills/architecture/scripts/invariants.sh tests/architecture_scripts_test.sh
git commit -m "feat(architecture): mark the hits that a branch adds with --new-since"
```

### Task 4: the skill's text

**Files:**
- Create: `skills/architecture/SKILL.md`
- Create: `skills/architecture/first-file.md`
- Create: `skills/architecture/README.md`

**Interfaces:**
- Consumes: the call and the output of `invariants.sh` (Tasks 1 to 3), and
  the syntax in *The `Check:` line* above.
- Produces: the skill `kalinichenko:architecture`, which #97 and #98 name.

- [ ] **Step 1: Invoke `superpowers:writing-skills` and follow it**

It runs the baseline first: a subagent with no skill, on the scenarios below,
and records what it does. The scenarios, each in a small fixture repository
with an `src/api/client.ts` that wraps every `fetch`:

1. "Add a page that lists the orders": does the agent name the problem and
   the simplest way before code, and find the wrapper?
2. "Add a second HTTP call for the prices": does it extend the wrapper or
   write a new client?
3. A file at 420 lines with a `lines 400` invariant: does it name a split
   before it adds to the file?

- [ ] **Step 2: Write `SKILL.md`**

Frontmatter `name: architecture`, and a description that names the two
moments. A draft for writing-skills to test and change: "Use when starting a
new feature (a screen, endpoint, module or integration), or at an
architecture decision: where new code goes; a new module, layer, dependency,
pattern or data store; a choice between options in a spec or a plan; or a
change to a file or module past its size limit. Also when writing or checking
docs/ARCHITECTURE.md, its invariants, or an ADR."

The body, from the spec, with the spec's rules and numbers as they are:

- *The start of a feature*: when it starts, the four questions, the ladder,
  the block, and the order inside `superpowers:brainstorming`.
- *The moment of a decision*: the four moments, the eight steps, the gate and
  its three endings, *Consistency first* and its limit to this skill's
  principles, when the ADR is written.
- *Modules and layers* and *Decomposition*, as principles; the three
  conditions for shared code.
- *ADRs*: the four reasons, the template.
- *Models*: the table, and the line for Codex: "Codex has no subagent with a
  model; the agent does each step that the table gives to a subagent."
- How to run `invariants.sh`: `bash <dir>/scripts/invariants.sh` from the
  project's checkout, with `<dir>` the skill's base directory, and what its
  exit statuses mean.
- Where the files are: `docs/ARCHITECTURE.md` or a root `ARCHITECTURE.md`;
  `docs/adr/`, or `doc/adr/` or `docs/decisions/` when the project has one.
- The skills it uses, and changes none of: `kalinichenko:github` for issues,
  `kalinichenko:roadmap` for the roadmap, `measure.sh` and `clones.sh` of the
  debt skill.

- [ ] **Step 3: Write `first-file.md`**

*A first `docs/ARCHITECTURE.md`*: the offer, the line after a no, the commit
in the middle of a feature, the five steps; the parts of the file, the example
invariants of the spec, the syntax of *The `Check:` line* above; the line for
`CLAUDE.md` and `AGENTS.md`, with the project's own path. `SKILL.md` sends the
agent here at step 1 of the decision when the project has no file.

- [ ] **Step 4: Run the scenarios again with the skill, and close the gaps that writing-skills finds**

Expected: in each scenario the agent loads the skill and does what the
scenario asks.

- [ ] **Step 5: Write `README.md`, in the shape of `skills/debt/README.md`**

`## When it starts` (the two moments), `## What you get` (one bullet per part,
`invariants.sh` and what it needs: bash, git and awk), and what it never does:
no package manager, no script of the project, no text of the file as a command.

- [ ] **Step 6: Run `make check`**

Run: `make check`
Expected: `claude plugin validate .` passes, and every test prints its ok line.

- [ ] **Step 7: Commit**

```bash
git add skills/architecture/SKILL.md skills/architecture/first-file.md skills/architecture/README.md
git commit -m "feat(architecture): add the architecture skill"
```

### Task 5: the plugin's files

**Files:**
- Modify: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`,
  `.codex-plugin/plugin.json`: the `description` lists `architecture` after
  `debt`.
- Modify: `README.md`: a bullet for
  `[kalinichenko:architecture](skills/architecture/README.md)` after the debt
  bullet; in the dependencies paragraph, that `invariants.sh` needs only bash,
  git and awk; in *Develop*, that `make check` runs `invariants.sh` on
  repositories the test builds.

**Interfaces:**
- Consumes: the skill of Task 4.

- [ ] **Step 1: Edit the three manifests and the README**

- [ ] **Step 2: Run `make check`**

Run: `make check`
Expected: every test prints its ok line, and `jq empty` and
`claude plugin validate .` pass.

- [ ] **Step 3: Find the documents that the change makes false**

A subagent, as *Docs move with the change* in the rules says, gets the new
skill, its script and the changed files. It returns each false passage as
`file:line`, or "none". Fix each one.

- [ ] **Step 4: Commit**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json .codex-plugin/plugin.json README.md
git commit -m "docs(architecture): list the architecture skill in the plugin"
```

After Task 5: the review through `kalinichenko:review-loop`, then the pull
request through `kalinichenko:github`, with `Closes #96` and `Part of #87`,
and `keep-open.sh` for #87.
