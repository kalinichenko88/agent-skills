# Roadmap Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `kalinichenko:roadmap`, a GitHub-backed PM skill that plans milestones and answers "what to take now / in parallel / what closes M1", and close the assignment gaps in `kalinichenko:github` take-in.

**Architecture:** Bash scripts read GitHub with `gh`; each page's `--jq` emits tab-separated records, and `awk` programs compute the graph across pages: free tasks, tracks, ranking, dependency order, cycles. A Haiku subagent (Claude Code) or the main agent (Codex) reads code only for the overlap check. Markdown files carry the skill's instructions.

**Tech Stack:** bash, `gh` ≥ 2.99 (its embedded gojq for `--jq`), POSIX `awk`, shellcheck; the tests use `jq` in a fake `gh`.

**Spec:** `docs/superpowers/specs/2026-10-23-roadmap-skill-design.md`

## Global Constraints

- Scripts need only `bash`, `gh` and POSIX tools (`awk`, `sed`, `sort`). No `jq` binary at run time: every JSON filter is `gh`'s own `--jq`. `gh api --paginate --slurp` refuses `--jq`, so cross-page work happens in `awk` over records.
- `--jq` runs on gojq: regular expressions are RE2 (no lookahead, no lookbehind). The tests run real `jq`, which accepts more; keep to RE2. macOS awk is BWK awk: no `gawk` extensions.
- Each script: `set -euo pipefail`, a header comment in the github scripts' style, a usage line on stderr with exit 2 on bad arguments, honours `GH_REPO` through `{owner}`/`{repo}` placeholders, and every writer honours `DRY_RUN=1` with the github scripts' `run()` helper (`dry run: gh …`, `printf %q` quoting).
- A script error stops the step; the agent never redoes the step by hand with `gh` (as `skills/github/tracker.md`).
- `agent-skills` is public. Every fixture comes from a public source (this repository, `golang/go`), or, for the owner's projects, is cut to the fields the script reads with every text replaced. No doc example names the owner's private repositories.
- Milestone title form `M<n> · <name>`; the current mark is a description line that reads exactly `Current.`; `Later` (any case) is last and never current.
- Prose in skill files: plain technical English (ASD-STE100), as the existing skill files. Code, comments and commit messages in English. Commit subjects `type(scope): sentence`, no `Co-Authored-By`.
- `make check` is the gate: it must pass at the end of every task.

## Review Focus

1. **A repository with no milestones yet** (a new project, before planning). `roadmap.sh` and `next.sh` must not fail: no milestone sections, every free issue in bugs or secondary, `current: none`. Tests in Task 2 and Task 3.
2. **A dependency cycle made by hand in the GitHub UI.** Every recursion must stop: both issues are blocked, `roadmap.sh` prints both, `next.sh` ends. Tests in Task 2 and Task 3.
3. **A blocker or a sub-issue in another repository.** The issue is not free: `blocked by other/repo#3`, or `open sub-issues: 1` from `subIssuesSummary`. Tests in Task 1 and Task 2.
4. **A milestone closed while it still has open issues.** Its issues count as having no milestone; nothing prints an empty title. Test in Task 2.
5. **gojq differs from jq** in a filter: tests are green, the real `gh` fails. Task 8 runs every read-only script against a real repository.

---

### Task 1: Fixtures, the test harness and `read.sh`

**Files:**
- Create: `skills/roadmap/scripts/read.sh`
- Create: `tests/roadmap_scripts_test.sh`
- Create: `tests/fixtures/roadmap/` (`issues-1.json`, `milestones.json`, `prs-1.json`, `pr-files.json`, `compare.json`, `repo.json`)
- Modify: `Makefile` (shellcheck `skills/roadmap/scripts/*.sh`, run `./tests/roadmap_scripts_test.sh`)

**Interfaces:**
- Produces `read.sh <mode>`; output on stdout, one tab-separated record per line:
  - `read.sh issues [bug-label]` (default `bug`):
    - `repo	<owner/name>` and `me	<login>` (once per page; the last wins)
    - `is	<n>	<milestone, 0 = none>	<bug 1|0>	<busy or ->	<open blockers or ->	<parent, 0 = none>	<parent's milestone, 0 = none>	<open sub-issues>	<title>`
    - `br	<n>	<branch>` for each linked branch
    - busy: `assigned to <login>`, `branch <name>`, `PR #<n> by <login>` (open closing PRs only), joined by `, `, the viewer written as `you` — the words of `collect.sh status`.
    - open blockers: `#<n>` for this repository, `<owner/repo>#<n>` for another, joined by `,`.
    - parent: 0 when it is in another repository; its milestone is given whatever its state.
    - open sub-issues: `subIssuesSummary.total - subIssuesSummary.completed`.
  - `read.sh milestones`: open milestones, sorted by order:
    - `ms	<n>	<order>	<current 1|0>	<later 1|0>	<open>	<closed>	<title>`
    - then `md	<n>	<line>` for each description line, `\r` removed, the `Current.` line left out.
    - order: `k` for a title `M<k>` followed by a non-digit or the end; `100000 + number` for other titles; `1000000000` for `Later`.
    - current: 1 for a line equal to `Current.` after trimming, never for `Later`; when no milestone has it, the first non-`Later` milestone.
  - `read.sh milestone <name>`: `<n>	<title>` of the open milestone whose title equals `<name>` (any case), or starts with `<name>` = `M<k>` followed by a non-digit; else `read.sh: no open milestone matches <name>` on stderr, exit 1.
  - `read.sh prs`: `me	<login>` and `pr	<n>	<author or you>	<closed issue numbers of this repository or ->	<file paths or ->	<file count>`, joined by `,`.

- [ ] **Step 1: Write the queries, then record the fixtures**

The issues query, sent with `--paginate -F owner='{owner}' -F name='{repo}'` and `BUG=<label>` in the environment for `$ENV.BUG`:

```graphql
query($owner: String!, $name: String!, $endCursor: String) {
  viewer { login }
  repository(owner: $owner, name: $name) {
    nameWithOwner
    issues(states: OPEN, first: 100, after: $endCursor) {
      pageInfo { hasNextPage endCursor }
      nodes {
        number title
        labels(first: 20) { nodes { name } }
        milestone { number }
        assignees(first: 10) { nodes { login } }
        linkedBranches(first: 10) { nodes { ref { name } } }
        closedByPullRequestsReferences(first: 10) { nodes { number state author { login } } }
        blockedBy(first: 50) { nodes { number state repository { nameWithOwner } } }
        parent { number milestone { number } repository { nameWithOwner } }
        subIssuesSummary { total completed }
      }
    }
  }
}
```

The PRs query: `viewer { login }` and `pullRequests(states: OPEN, first: 50, after: $endCursor) { pageInfo … nodes { number author { login } closingIssuesReferences(first: 20) { nodes { number repository { nameWithOwner } } } files(first: 100) { totalCount nodes { path } } } }`. Milestones: one REST call, `per_page=100` (`# ponytail: 100 open milestones at most; paginate if a project ever has more`).

Record, all public:

```bash
fx=tests/fixtures/roadmap
GH_REPO=kalinichenko88/agent-skills gh api graphql -F owner='{owner}' -F name='{repo}' -f query="${ISSUES_QUERY/states: OPEN, first: 100/states: CLOSED, last: 3}" >$fx/issues-1.json
GH_REPO=kalinichenko88/agent-skills gh api graphql -F owner='{owner}' -F name='{repo}' -f query="${PRS_QUERY/states: OPEN, first: 50/states: MERGED, last: 3}" \
  | jq '.data.repository.pullRequests.nodes[].closingIssuesReferences.nodes = []' >$fx/prs-1.json
gh api "repos/kalinichenko88/agent-skills/pulls/$(jq -r '.data.repository.pullRequests.nodes[0].number' $fx/prs-1.json)/files" | jq '[.[] | {filename}]' >$fx/pr-files.json
gh api repos/golang/go/milestones'?state=open&per_page=7' | jq '[.[] | {number, title, description, state, open_issues, closed_issues}]
  | to_entries | map(.value.title = (if .key == 6 then "Later" else "M\(.key) · Stage \(.key)" end)
  | .value.description = "Goal of stage \(.key)." | .value)' >$fx/milestones.json
gh api repos/kalinichenko88/agent-skills/compare/f009a93...de7508c | jq '{files: [.files[] | {filename}]}' >$fx/compare.json
gh api repos/kalinichenko88/agent-skills | jq '{full_name, default_branch, owner: {login: .owner.login, type: .owner.type}}' >$fx/repo.json
```

- [ ] **Step 2: Write the harness and the failing tests**

The template issue is a closed one, so the recording does not depend on what is open that day; the PRs lose their closing references, so each test adds the ones it needs.

`tests/roadmap_scripts_test.sh` follows `tests/github_scripts_test.sh`, with `TMPDIR=$tmp`: a fake `gh` in `$tmp/bin` logs each call to `$FAKE/calls`, fails with `gh: HTTP 502` when the call contains `$FAKE_FAIL`, applies `--jq` with `jq -r`, and answers by the call's shape. Each answer comes from `$FAKE/<file>` when there, else from the fixture.

| Call | Answer |
| --- | --- |
| `api graphql` with `issues(states: OPEN` | each `issues-*.json`, in name order, the filter applied per page |
| `api graphql` with `pullRequests(states: OPEN` | each `prs-*.json`, the same way |
| `api graphql` with `a: issue(number` | `{"data":{"repository":{"a":{"id":"I_<a>"},"b":{"id":"I_<b>"}}}}` from the `-F a=` and `-F b=` values |
| `api graphql` with `projectsV2(` / `views(` | `projects-linked.json` / `project-views.json` (Task 5) |
| `api graphql` with `mutation` | nothing (logged) |
| `api repos/{owner}/{repo}/milestones?…` | `milestones.json` |
| `api repos/{owner}/{repo}/milestones/<n>`, no `-X` | that element of `milestones.json` |
| `api -X POST` or `-X PATCH` | nothing (logged) |
| `api repos/{owner}/{repo}/compare/…` | `compare.json` |
| `api repos/{owner}/{repo}/pulls/<n>/files` | `pr-files.json` |
| `api repos/{owner}/{repo}` | `repo.json` |
| `issue view <n> --json body` | `jq -Rs '{body: .}' $FAKE/body-<n>` (empty body when absent), then the filter |
| `issue list --state open` | `[{number, url: "https://github.com/kalinichenko88/agent-skills/issues/<n>"}]` from the issue pages |
| `issue edit` | nothing (logged) |
| `project …` | Task 5 |

Helpers:
- `put '<n>[:<M>] …'` writes `$FAKE/issues-1.json`: the recorded page with one node per entry, made from the recorded node with `number = n`, `title = "Issue n"`, milestone `M` (`M0`…`M5`, `Later`, `-` for none; `M1` when left out), every connection emptied, `parent = null`, `subIssuesSummary = {total: 0, completed: 0}`, `hasNextPage = false`. It removes the other `$FAKE/issues-*.json`.
- `pages <count>` writes issues `1`…`<count>` (milestone `M1`) as pages of 100 nodes: `issues-1.json`, `issues-2.json`, …, every page but the last with `hasNextPage = true`.
- `edit <n> '<jq>'` applies the filter to node `n` wherever it is.
- `blocks <n> <m>…` adds open blockers `#m` of this repository to node `n`.
- `ms '<jq>'` writes `$FAKE/milestones.json`: the current milestones (that file, else the fixture) through the filter; `msno <M>` prints the recorded number of milestone `M`; `mark <M>` appends `\n\nCurrent.` to its description.
- `reset` empties `$FAKE` but `calls`.

Tests for this task:

```bash
reset; pages 150
check 'issues reads every page' 150 "$(bash "$scripts/read.sh" issues | grep -c '^is	')"
reset; put '19 20 21'
edit 19 '.blockedBy.nodes = [{number: 116, state: "CLOSED", repository: {nameWithOwner: "kalinichenko88/agent-skills"}}]'
edit 20 '.assignees.nodes = [{login: "kalinichenko88"}] | .linkedBranches.nodes = [{ref: {name: "fix/20-x"}}]
  | .closedByPullRequestsReferences.nodes = [{number: 9, state: "OPEN", author: {login: "someone"}}, {number: 8, state: "MERGED", author: {login: "someone"}}]'
blocks 21 19
edit 21 '.blockedBy.nodes += [{number: 3, state: "OPEN", repository: {nameWithOwner: "other/repo"}}] | .labels.nodes = [{name: "bug"}]
  | .parent = {number: 19, milestone: {number: 7}, repository: {nameWithOwner: "kalinichenko88/agent-skills"}} | .subIssuesSummary = {total: 3, completed: 1}'
out=$(bash "$scripts/read.sh" issues)
m1=$(msno M1)
check 'a closed blocker is not listed' "$(printf 'is\t19\t%s\t0\t-\t-\t0\t0\t0\tIssue 19' "$m1")" "$(grep '^is	19	' <<<"$out")"
check 'busy in collect.sh words' 'assigned to you, branch fix/20-x, PR #9 by someone' "$(awk -F'\t' '$1=="is" && $2==20 {print $5}' <<<"$out")"
check 'linked branch' "$(printf 'br\t20\tfix/20-x')" "$(grep '^br	' <<<"$out")"
check 'blockers, bug, parent, its milestone, open sub-issues' "$(printf 'is\t21\t%s\t1\t-\t#19,other/repo#3\t19\t7\t2\tIssue 21' "$m1")" "$(grep '^is	21	' <<<"$out")"
check 'the repository' "$(printf 'repo\tkalinichenko88/agent-skills')" "$(grep '^repo	' <<<"$out" | tail -1)"
check 'another bug label' 0 "$(bash "$scripts/read.sh" issues defect | awk -F'\t' '$1=="is" && $2==21 {print $4}')"
# milestones
reset
check 'order, Later last' "$(printf 'M0 · Stage 0\nM1 · Stage 1\nM2 · Stage 2\nM3 · Stage 3\nM4 · Stage 4\nM5 · Stage 5\nLater')" \
  "$(bash "$scripts/read.sh" milestones | awk -F'\t' '$1=="ms" {print $8}')"
check 'the first is current when none is marked' 'M0 · Stage 0' "$(bash "$scripts/read.sh" milestones | awk -F'\t' '$1=="ms" && $4==1 {print $8}')"
mark M0; ms "(.[] | select(.title | startswith(\"M1\")) | .description) += \"\r\n Current. \r\n\""
out=$(bash "$scripts/read.sh" milestones)
check 'marked milestones are current' "$(printf 'M0 · Stage 0\nM1 · Stage 1')" "$(awk -F'\t' '$1=="ms" && $4==1 {print $8}' <<<"$out")"
check 'the mark is no description line' 0 "$(grep -c 'Current\.' <<<"$out")"
check 'no carriage return' 0 "$(grep -c $'\r' <<<"$out")"
mark Later
check 'Later is never current' 0 "$(bash "$scripts/read.sh" milestones | awk -F'\t' '$1=="ms" && $5==1 {print $4}')"
reset
check 'M1 resolves' "$(printf '%s\tM1 · Stage 1' "$(msno M1)")" "$(bash "$scripts/read.sh" milestone M1)"
check 'later resolves in any case' Later "$(bash "$scripts/read.sh" milestone later | cut -f2)"
bash "$scripts/read.sh" milestone M9 2>/dev/null && fail 'an unknown milestone exits 0'
ms 'map(if (.title | startswith("M1 ")) then .title = "M10 · Stage 10" else . end)'
bash "$scripts/read.sh" milestone M1 2>/dev/null && fail 'M1 matches M10'
# prs
reset
first=$(jq -r '.data.repository.pullRequests.nodes[0] | "\(.number)\t\(.files.totalCount)"' "$fixtures/prs-1.json")
check 'pr record: number, you, file count' "$(printf 'pr\t%s\tyou\t%s' "${first%%	*}" "${first##*	}")" \
  "$(bash "$scripts/read.sh" prs | grep '^pr	' | head -1 | cut -f1-3,6)"
check 'usage' 2 "$(bash "$scripts/read.sh" >/dev/null 2>&1; echo $?)"
```

(The recorded merged PRs are the owner's own, so their author prints as `you`.)

- [ ] **Step 3: Run the tests to see them fail**

Run: `./tests/roadmap_scripts_test.sh`
Expected: FAIL at the first check (`read.sh` does not exist).

- [ ] **Step 4: Write `read.sh`**

Emit the records with `@tsv`; the filters per mode as the interface says. Remove `\r` with `gsub("\r"; "")` before the description is split.

- [ ] **Step 5: Run the tests to see them pass**

Run: `make check`
Expected: it passes, and the new test ends with `roadmap_scripts_test: ok`.

- [ ] **Step 6: Commit**

```bash
git add skills/roadmap/scripts/read.sh tests/roadmap_scripts_test.sh tests/fixtures/roadmap Makefile
git commit -m "feat(roadmap): read issues, milestones and pull requests as records"
```

### Task 2: `graph.awk` and `roadmap.sh`

**Files:**
- Create: `skills/roadmap/scripts/graph.awk`, `skills/roadmap/scripts/roadmap.awk`, `skills/roadmap/scripts/roadmap.sh`
- Modify: `tests/roadmap_scripts_test.sh`

**Interfaces:**
- Consumes: `read.sh issues|milestones|milestone` (Task 1).
- Produces `graph.awk` (run as `awk -F'\t' -f graph.awk -f <program>.awk`). It loads the records and defines:
  - `ems(n)`: the effective milestone: the first open one of the issue's own, its parent's milestone from the record, and `ems(parent)` when the parent is loaded (at most 8 steps). 0 when none. A closed milestone is not open: it is not in `msorder`.
  - `waits(n, out)`: fills `out` with the open blockers of `n` and of each loaded ancestor, as written in the records. Returns the count.
  - `kids(n, out)`: the loaded open issues whose parent is `n`. Returns the count.
  - `isfree(n)`: busy is `-`, `waits` is 0, open sub-issues is 0, `ems(n)` is not `Later`.
  - The "waits on" edges: `j → i` for each `i` in `waits(j)` that is loaded, and parent `p → c` for each `c` in `kids(p)`. `reaches(from, to, seen)` is 1 when a chain of edges leads from `from` to `to`; it marks `seen`, so a cycle ends.
  - `order_of(n)`: `msorder[ems(n)]`, or `500000000` when `ems(n)` is 0.
  - Arrays: `msorder`, `mscur`, `mslater`, `mstitle`, `msopen`, `msclosed`, `mslist`/`msn` (in order), `mdlines`, `isms`, `isbug`, `isbusy`, `isblk`, `ispar`, `isparms`, `issubs`, `istitle`, `islist`/`isn`, `isbr`, and `me`, `repo`.
- Produces `roadmap.sh [milestone]` on stdout:

```
# Roadmap of kalinichenko88/agent-skills

## M1 · Stage 1
current, 22 of 54 closed

<description lines>

- #21 Issue 21: free
- #20 Issue 20: blocked by #21
- #22 Issue 22: assigned to you

## Later
2 of 48 closed

- #42 Issue 42

## No milestone
3 open: #240, #242, #251
```

  - The progress line: `current, ` first for a current milestone; total is open + closed.
  - An issue's state: its busy text, `blocked by <waits joined by ", ">`, `open sub-issues: <k>`, joined by `; `; `free` when none.
  - Dependency order inside a section: repeat — print the lowest-numbered issue whose in-section "waits on" targets are all printed; when none qualifies (a cycle), print the lowest-numbered one left.
  - `Later` lists `- #<n> <title>` only. `No milestone` is left out when empty. With no open milestone, `No open milestones.` follows the title line and a blank line.
  - `roadmap.sh <milestone>`: the title line, then that section only; the open issues it waits on in other places (any chain) join the list in dependency order with ` (<milestone title>)` or ` (no milestone)` after the title. `roadmap.sh Later` uses the same form as any milestone, states included.

- [ ] **Step 1: Write the failing tests**

```bash
reset; mark M1; put '19 20 21 22 23 42:Later 50:M2'
blocks 20 21
edit 22 '.assignees.nodes = [{login: "kalinichenko88"}]'
edit 23 '.blockedBy.nodes = [{number: 3, state: "OPEN", repository: {nameWithOwner: "other/repo"}}]'
out=$(bash "$scripts/roadmap.sh")
check 'dependency order and states' "$(printf -- '- #19 Issue 19: free\n- #21 Issue 21: free\n- #20 Issue 20: blocked by #21\n- #22 Issue 22: assigned to you\n- #23 Issue 23: blocked by other/repo#3')" \
  "$(sed -n '/^## M1 /,/^## /p' <<<"$out" | grep '^- ')"
progress() { jq -r --arg p "$1 " '.[] | select(.title | startswith($p)) | "\(.closed_issues) of \(.open_issues + .closed_issues) closed"' "$fixtures/milestones.json"; }
check 'a current milestone' "current, $(progress M1)" "$(sed -n '/^## M1 /{n;p;}' <<<"$out")"
check 'a milestone that is not current' "$(progress M2)" "$(sed -n '/^## M2 /{n;p;}' <<<"$out")"
check 'Later shows titles only' '- #42 Issue 42' "$(sed -n '/^## Later/,/^## /p' <<<"$out" | grep '^- ')"
check 'Later by name shows states' '- #42 Issue 42: free' "$(bash "$scripts/roadmap.sh" Later | grep '^- ')"
# a cycle made by hand ends, and both issues show
blocks 21 20
check 'a cycle prints each issue once' 2 "$(bash "$scripts/roadmap.sh" | grep -cE '^- #2[01] ')"
# sub-issues: the milestone and the blockers of the parent; a sub-issue elsewhere
reset; put '19 30:- 31:M2'
edit 30 '.parent = {number: 19, milestone: {number: '"$(msno M1)"'}, repository: {nameWithOwner: "kalinichenko88/agent-skills"}}'
blocks 19 31
edit 19 '.subIssuesSummary = {total: 2, completed: 0}'
out=$(bash "$scripts/roadmap.sh")
check 'a sub-issue under its parent milestone, blocked through it' '- #30 Issue 30: blocked by #31' "$(sed -n '/^## M1 /,/^## /p' <<<"$out" | grep '^- #30 ')"
check 'a parent waits on all its open sub-issues' '- #19 Issue 19: blocked by #31; open sub-issues: 2' "$(grep '^- #19 ' <<<"$out")"
check 'one milestone with a blocker elsewhere' '- #31 Issue 31 (M2 · Stage 2): free' "$(bash "$scripts/roadmap.sh" M1 | grep '^- #31 ')"
check 'one milestone has one section' 1 "$(bash "$scripts/roadmap.sh" M1 | grep -c '^## ')"
# a closed milestone counts as none
reset; put '19 24'
edit 24 '.milestone = {number: 999999}'
check 'an issue in a closed milestone' '1 open: #24' "$(bash "$scripts/roadmap.sh" | sed -n '/^## No milestone/{n;p;}')"
# no milestones at all
reset; ms '[]'; put '19:-'
check 'no milestones' "$(printf '# Roadmap of kalinichenko88/agent-skills\n\nNo open milestones.')" "$(bash "$scripts/roadmap.sh" | sed -n '1,3p')"
```

- [ ] **Step 2: Run them to see them fail**

Run: `./tests/roadmap_scripts_test.sh`
Expected: FAIL at `dependency order and states`.

- [ ] **Step 3: Write `graph.awk`, `roadmap.awk` and `roadmap.sh`**

`roadmap.sh` runs `read.sh milestones` and `read.sh issues`, and `read.sh milestone <name>` for the argument; it pipes the records to `awk -F'\t' -f graph.awk -f roadmap.awk -v only=<number or empty>`. Find the other files with `$(dirname "$0")`.

- [ ] **Step 4: Run the tests to see them pass**

Run: `make check`
Expected: `roadmap_scripts_test: ok`.

- [ ] **Step 5: Commit**

```bash
git add skills/roadmap/scripts/graph.awk skills/roadmap/scripts/roadmap.awk skills/roadmap/scripts/roadmap.sh tests/roadmap_scripts_test.sh
git commit -m "feat(roadmap): print the roadmap from GitHub in dependency order"
```

### Task 3: `next.sh`

**Files:**
- Create: `skills/roadmap/scripts/next.awk`, `skills/roadmap/scripts/next.sh`
- Modify: `tests/roadmap_scripts_test.sh`

**Interfaces:**
- Consumes: `read.sh issues|milestones|prs` (Task 1), `graph.awk` (Task 2).
- Produces `next.sh [bug-label]` on stdout:

```
current: M0 · Stage 0; M1 · Stage 1
== main path
#21 Issue 21 (M1 · Stage 1), unblocks 2
== bugs
none
== secondary
#40 Issue 40 (M2 · Stage 2), unblocks 0
and 12 more
== in progress
#22 Issue 22: assigned to you, PR #9 by you
PR #30 by someone: closes no issue
overlap: /tmp/next.AbC123 (6 KB)
```

  and the overlap file, whose form `lanes.md` (Task 7) describes:

```
== Candidates
==> #21 Issue 21 [main path, M1 · Stage 1]
cites: src/a.ts, docs/b.md
<body>
== Work in progress
==> #22 Issue 22 [assigned to you, PR #9 by you]
files: src/x.ts, src/y.ts
==> #23 Issue 23 [assigned to someone]
no diff yet
<body>
==> PR #30 by someone
files: package.json
== end
```

Rules, in `next.awk`:
- Current milestones: `mscur`; `current: none` when there are none.
- Main set: the open non-bug issues whose `ems` is current, and every loaded open issue they reach through the "waits on" edges (blockers and sub-issues, any milestone, bugs included). Main path: its free issues.
- When the main path is empty and a non-`Later` milestone follows the last current one, take that milestone as current and print `note: nothing free in <current titles>; the main path is from <title>` after the `current:` line.
- Bugs: free bug issues outside the main set. Secondary: the other free issues outside it. `Later` issues are never offered.
- Rank: the effective order (the lowest `order_of` among the issue and every open issue that reaches it), then the unblock count (open issues that reach it) descending, then the number.
- Stdout: each track's top 5, then `and <k> more`, or `none` when empty. The overlap file: every main-path issue, and the top 5 of bugs and of secondary.
- In progress: every open issue whose busy is not `-`, by number; then every open PR that closes no issue of this repository.
- `next.awk` also prints, mixed in the stream, the lines the overlap file needs; `next.sh` takes them out:
  - `want	cand	<n>	<title>	<track>	<milestone title or "no milestone">`
  - `want	wip	<n>	<title>	<busy>	<files of its open PRs, or ->	<its linked branches, or ->`
  - `want	pr	<number>	<author>	<files or ->`
- `next.sh`: before `awk`, a PR record whose file count is over 100 gets its whole list from `gh api "repos/{owner}/{repo}/pulls/<n>/files" --paginate --jq '.[].filename'`. After `awk`: for a `wip` line with no files, `gh api "repos/{owner}/{repo}/compare/<default>...<branch>" --jq '.files[].filename'` per branch (the default branch from `gh api repos/{owner}/{repo} --jq .default_branch`); still none: `no diff yet` and the body. Bodies: `gh issue view <n> --json body --jq .body`, only for the file's entries. The file: `mktemp "${TMPDIR:-/tmp}/next.XXXXXX"`; the last stdout line is `overlap: <path> (<size rounded up> KB)`.
- `cites:` the paths in the body: drop URLs (`https?://` up to whitespace or `)`), then each token of path characters that holds a `/` and ends in `.<extension>`, with an optional `:<line>` or `:<line>-<line>`, which is dropped; unique, in order. Left out when none. `# ponytail: a path without a directory is not seen; the reader finds those from the symbols.`

- [ ] **Step 1: Write the failing tests**

```bash
section() { sed -n "/^== $1/,/^== /p" | grep -E '^(#|and |none)'; }
reset; mark M1; put '19 20 21 22 40:M2 41:-'
blocks 20 21; blocks 19 20
edit 22 '.labels.nodes = [{name: "bug"}]'
out=$(bash "$scripts/next.sh")
check 'current line' 'current: M1 · Stage 1' "$(head -1 <<<"$out")"
check 'main path: a chain counts every step' '#21 Issue 21 (M1 · Stage 1), unblocks 2' "$(section 'main path' <<<"$out")"
check 'bugs' '#22 Issue 22 (M1 · Stage 1), unblocks 0' "$(section bugs <<<"$out")"
check 'secondary: next milestone, then none' "$(printf '#40 Issue 40 (M2 · Stage 2), unblocks 0\n#41 Issue 41 (no milestone), unblocks 0')" "$(section secondary <<<"$out")"
# a blocker in M3 of an M1 task is on the main path and ranks with M1
reset; mark M1; put '19 20 21 40:M3'
blocks 19 40; blocks 20 40 21
check 'an M3 blocker ranks with M1 by its unblock count' "$(printf '#40 Issue 40 (M3 · Stage 3), unblocks 2\n#21 Issue 21 (M1 · Stage 1), unblocks 1')" \
  "$(bash "$scripts/next.sh" | section 'main path')"
# a sub-issue in a later milestone of an M1 parent is on the main path
reset; mark M1; put '19 30:M3'
edit 30 '.parent = {number: 19, milestone: {number: '"$(msno M1)"'}, repository: {nameWithOwner: "kalinichenko88/agent-skills"}}'
edit 19 '.subIssuesSummary = {total: 1, completed: 0}'
check 'a sub-issue of an M1 parent' '#30 Issue 30 (M3 · Stage 3), unblocks 1' "$(bash "$scripts/next.sh" | section 'main path')"
# a cycle made by hand: neither is free, and the script ends
reset; mark M1; put '20 21'; blocks 20 21; blocks 21 20
check 'a cycle ends, nothing offered' 'none' "$(bash "$scripts/next.sh" | section 'main path')"
# fallback: nothing free in M1
reset; mark M1; put '19 40:M2'
edit 19 '.assignees.nodes = [{login: "someone"}]'
out=$(bash "$scripts/next.sh")
check 'fallback note' 'note: nothing free in M1 · Stage 1; the main path is from M2 · Stage 2' "$(sed -n 2p <<<"$out")"
check 'busy issue in progress' '#19 Issue 19: assigned to someone' "$(section 'in progress' <<<"$out")"
# top 5, the rest counted; Later never offered
reset; put '1:- 2:- 3:- 4:- 5:- 6:- 7:- 8:Later'
check 'and k more' 'and 2 more' "$(bash "$scripts/next.sh" | section secondary | tail -1)"
check 'Later is not offered' 0 "$(bash "$scripts/next.sh" | grep -c '^#8 ')"
# the overlap file
overlap() { bash "$scripts/next.sh" | sed -n 's/^overlap: \([^ ]*\) .*/\1/p'; }
reset; put '19 21'
edit 21 '.assignees.nodes = [{login: "someone"}] | .linkedBranches.nodes = [{ref: {name: "fix/21-x"}}]'
printf 'Fix `src/server/log.ts:12-14` and src/app/main.ts, see https://github.com/x/y/blob/main/z.ts and e.g. this.\n' >"$FAKE/body-19"
f=$(overlap)
check 'cites' 'cites: src/server/log.ts, src/app/main.ts' "$(grep '^cites: ' "$f")"
check 'branch files from compare' "files: $(jq -r '[.files[].filename] | join(", ")' "$fixtures/compare.json")" "$(sed -n '/^==> #21 /,/^==> /p' "$f" | grep '^files: ')"
check 'PRs closing no issue' "$(jq '.data.repository.pullRequests.nodes | length' "$fixtures/prs-1.json")" "$(bash "$scripts/next.sh" | grep -c '^PR #.*: closes no issue$')"
echo '{"files": []}' >"$FAKE/compare.json"
check 'no diff yet' 'no diff yet' "$(sed -n '/^==> #21 /{n;p;}' "$(overlap)")"
# the files of an open PR that closes the issue win over the branch, and past 100 come from REST
jq '.data.repository.pullRequests.nodes[0].closingIssuesReferences.nodes = [{number: 21, repository: {nameWithOwner: "kalinichenko88/agent-skills"}}]
  | .data.repository.pullRequests.nodes[0].files.totalCount = 150' "$fixtures/prs-1.json" >"$FAKE/prs-1.json"
check 'all the files of a large PR' "files: $(jq -r '[.[].filename] | join(", ")' "$fixtures/pr-files.json")" "$(sed -n '/^==> #21 /,/^==> /p' "$(overlap)" | grep '^files: ')"
# no milestones
reset; ms '[]'; put '19:-'
check 'no milestones' 'current: none' "$(bash "$scripts/next.sh" | head -1)"
# a failed read stops the script
FAKE_FAIL='pullRequests(' bash "$scripts/next.sh" >/dev/null 2>&1 && fail 'next.sh exits 0 when a read fails'
```

- [ ] **Step 2: Run them to see them fail**

Run: `./tests/roadmap_scripts_test.sh`
Expected: FAIL at `current line`.

- [ ] **Step 3: Write `next.awk` and `next.sh`**

All graph rules in `next.awk`; all `gh` calls in `next.sh`. The overlap file holds the candidates, then `wip`, then `pr`, in the order `awk` printed them.

- [ ] **Step 4: Run the tests to see them pass**

Run: `make check`
Expected: `roadmap_scripts_test: ok`.

- [ ] **Step 5: Commit**

```bash
git add skills/roadmap/scripts/next.awk skills/roadmap/scripts/next.sh tests/roadmap_scripts_test.sh
git commit -m "feat(roadmap): rank the free tasks per track and collect work in progress"
```

### Task 4: `plan.sh`

**Files:**
- Create: `skills/roadmap/scripts/cycle.awk`, `skills/roadmap/scripts/plan.sh`
- Modify: `tests/roadmap_scripts_test.sh`

**Interfaces:**
- Consumes: `read.sh issues|milestone` (Task 1), `graph.awk` (Task 2).
- Produces `plan.sh`:

```
usage: plan.sh create <title> <description-file>
       plan.sh describe <milestone> <description-file>
       plan.sh close <milestone>
       plan.sh current <milestone>
       plan.sh not-current <milestone>
       plan.sh block <issue> <blocker>
       plan.sh unblock <issue> <blocker>
       plan.sh sub <parent> <child>
```

| Subcommand | Write | Prints | Refuses (exit 1, writes nothing) |
| --- | --- | --- | --- |
| `create` | `gh api -X POST repos/{owner}/{repo}/milestones -f title=<t> -F description=@<file>` | `created <title>` | an open milestone of that title: `refused: <title> exists` |
| `describe` | `-X PATCH …/milestones/<n> -F description=@<tmp>`; keeps `Current.` when the milestone had it | `described <title>` | — |
| `close` | `-X PATCH …/milestones/<n> -f state=closed` | `closed <title>` | open issues in it, from `read.sh issues`: `refused: <title> has 3 open issues: #a, #b, #c` |
| `current` | PATCH the description with `Current.` as its last line, after a blank line when it is not empty | `marked <title> current` | `Later`: `refused: Later is never current`; marked already: `<title> is current already`, exit 0 |
| `not-current` | PATCH the description without its `Current.` lines and trailing blank lines | `unmarked <title>` | not marked: `<title> is not marked current`, exit 0 |
| `block A B` | ids by one query (`a: issue(number: $a) { id } b: issue(number: $b) { id }`), then `addBlockedBy(input: {issueId: A, blockingIssueId: B})` | `#A is blocked by #B` | `A == B`: `refused: an issue cannot wait on itself`; a cycle: `refused: it makes a cycle: <chain>` |
| `unblock A B` | `removeBlockedBy`, the same ids | `#A is no longer blocked by #B` | — |
| `sub P C` | `addSubIssue(input: {issueId: P, subIssueId: C})` | `#C is a sub-issue of #P` | as `block` |

- `cycle.awk` (with `graph.awk`) takes `-v act=block|sub -v a=<n> -v b=<n>`. It adds the edges the change makes: for `block A B`, `A → B` and `D → B` for each loaded descendant `D` of `A`; for `sub P C`, `P → C`, and `D → X` for `C` and each loaded descendant `D` of `C` and each `X` in `waits(P)`. Then, for each added edge `u → v` in that order, when `v` reaches `u` it prints the chain `#u → #v → … → #u` and stops. Nothing printed: no cycle.
- A milestone's description: `gh api repos/{owner}/{repo}/milestones/<n> --jq .description`, edited in a `mktemp` file that a dry run keeps, as `add-finding.sh` keeps its body.
- Putting issues into a milestone is `gh issue edit <n> --milestone '<title>'` (or `--remove-milestone`), named in `planning.md`; no subcommand.

- [ ] **Step 1: Write the failing tests**

```bash
reset; put '19 20 21'; blocks 20 21
: >"$FAKE/calls"
check 'block refuses a cycle' 'refused: it makes a cycle: #21 → #20 → #21' "$(bash "$scripts/plan.sh" block 21 20 2>&1; true)"
check 'a refused block sends no mutation' 0 "$(grep -c mutation "$FAKE/calls" || true)"
out=$(DRY_RUN=1 bash "$scripts/plan.sh" block 19 21)
case $out in *'dry run: gh api graphql'*addBlockedBy*) ;; *) fail 'block prints its mutation in a dry run' "$out" ;; esac
check 'a dry run sends no mutation' 0 "$(grep -c mutation "$FAKE/calls" || true)"
check 'block to itself' 'refused: an issue cannot wait on itself' "$(bash "$scripts/plan.sh" block 19 19 2>&1; true)"
# a cycle through an inherited blocker: #11 is a sub-issue of #10, and #12 waits on #11
reset; put '10 11 12'
edit 11 '.parent = {number: 10, milestone: null, repository: {nameWithOwner: "kalinichenko88/agent-skills"}}'
blocks 12 11
check 'block refuses an inherited cycle' 'refused: it makes a cycle: #11 → #12 → #11' "$(bash "$scripts/plan.sh" block 10 12 2>&1; true)"
# sub: the child would inherit #20, which waits on the child
reset; put '19 20 21'; blocks 20 21; blocks 19 20
check 'sub refuses a cycle through the parent blockers' 'refused: it makes a cycle: #21 → #20 → #21' "$(bash "$scripts/plan.sh" sub 19 21 2>&1; true)"
# milestones
reset; put '19 20 21'
ms '(.[] | select(.title | startswith("M1 ")) | .description) = "Goal."'
out=$(DRY_RUN=1 bash "$scripts/plan.sh" current M1)
check 'current adds the mark after a blank line' "$(printf 'Goal.\n\nCurrent.')" "$(cat "$(sed -n 's/.*description=@\([^ ]*\).*/\1/p' <<<"$out")")"
check 'Later is never current' 'refused: Later is never current' "$(bash "$scripts/plan.sh" current later 2>&1; true)"
check 'close refuses open issues' 'refused: M1 · Stage 1 has 3 open issues: #19, #20, #21' "$(bash "$scripts/plan.sh" close M1 2>&1; true)"
check 'create refuses an existing title' 'refused: M1 · Stage 1 exists' "$(bash "$scripts/plan.sh" create 'M1 · Stage 1' /dev/null 2>&1; true)"
check 'usage names every subcommand' 8 "$(bash "$scripts/plan.sh" 2>&1 | grep -c 'plan.sh ')"
```

- [ ] **Step 2: Run them to see them fail**

Run: `./tests/roadmap_scripts_test.sh`
Expected: FAIL at `block refuses a cycle`.

- [ ] **Step 3: Write `cycle.awk` and `plan.sh`**

One `case` on the subcommand; every write goes through `run()`.

- [ ] **Step 4: Run the tests to see them pass**

Run: `make check`
Expected: `roadmap_scripts_test: ok`.

- [ ] **Step 5: Commit**

```bash
git add skills/roadmap/scripts/cycle.awk skills/roadmap/scripts/plan.sh tests/roadmap_scripts_test.sh
git commit -m "feat(roadmap): write milestones, the current mark and blocked-by links, refusing cycles"
```

### Task 5: `board.sh`

**Files:**
- Create: `skills/roadmap/scripts/board.sh`
- Create: `tests/fixtures/roadmap/` (`project-list.json`, `project-view.json`, `project-items.json`, `project-views.json`, `projects-linked.json`)
- Modify: `tests/roadmap_scripts_test.sh`

**Interfaces:**
- Produces `board.sh` (no arguments). Steps; each prints its plain line, in a dry run too:
  1. The owner from `gh api repos/{owner}/{repo} --jq .owner.login`; the name `<repo> roadmap`.
  2. Find it among `repository { projectsV2(first: 100) { nodes { number title url closed } } }`, open ones, by title. Else among `gh project list --owner <owner> --limit 1000 --format json`, and link it: `gh project link <number> --owner <owner> --repo <owner/name>`, line `linked <owner/name>`. Else `gh project create --owner <owner> --title '<name>' --format json`, then the link. A failed create: `cannot create a project under <owner>: <gh's error>`, exit 1. Line: `project: <url>`.
  3. Items from `gh project item-list <number> --owner <owner> --limit 1000 --format json` (`.items[].content` with `number` and `repository`); open issues from `gh issue list --state open --limit 1000 --json number,url`; `gh project item-add <number> --owner <owner> --url <url>` for each missing one. Line: `issues to add: <k>`.
  4. Views from `node(id: <project id>) { ... on ProjectV2 { views(first: 20) { nodes { name } } } }`, the id from `gh project view <number> --owner <owner> --format json --jq .id`. For each missing view: line `view <name>: missing`, then `createProjectV2View(input: {projectId, name, layout})` and `updateProjectV2View(input: {viewId, filter})`; a present one: `view <name>: there`.
     - `Unassigned`, `BOARD_LAYOUT`, `is:issue is:open no:assignee -milestone:Later`
     - `By milestone`, `TABLE_LAYOUT`, `is:issue is:open`
     - The update needs the id the create returns; a dry run writes `VIEW_ID` in its place.
  5. The two settings the API cannot make:

```
Two settings the API cannot make. Open <url>:
1. In the view "By milestone", group by Milestone.
2. Under Workflows, turn on "Auto-add to project" for <owner/name> with the filter is:issue is:open.
```

  - A dry run prints each write and runs none. When the project does not exist yet, it prints the create and the link, then `dry run: no project yet, so no items and no views` and goes on to step 5.

- [ ] **Step 1: Record the project fixtures**

Read-only from the owner's project `kalinichenko88` #6, each cut to the fields `board.sh` reads, every text replaced:

```bash
fx=tests/fixtures/roadmap
gh project list --owner kalinichenko88 --format json --limit 3 | jq '{projects: [.projects[] | {number, title: "Project \(.number)", url, closed, id}]}' >$fx/project-list.json
gh project view 6 --owner kalinichenko88 --format json | jq '{number, title: "Project 6", url, closed, id}' >$fx/project-view.json
gh project item-list 6 --owner kalinichenko88 --format json --limit 3 | jq '{items: [.items[] | {content: {number: .content.number, repository: "other/repo", type: .content.type}}]}' >$fx/project-items.json
gh api graphql -f id="$(jq -r .id $fx/project-view.json)" -f query='query($id: ID!) { node(id: $id) { ... on ProjectV2 { views(first: 20) { nodes { name } } } } }' \
  | jq '.data.node.views.nodes |= [range(length) as $i | {name: "View \($i)"}]' >$fx/project-views.json
GH_REPO=kalinichenko88/agent-skills gh api graphql -F owner='{owner}' -F name='{repo}' -f query='query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { projectsV2(first: 100) { nodes { number title url closed } } } }' \
  | jq '.data.repository.projectsV2.nodes |= map(.title = "Project \(.number)")' >$fx/projects-linked.json
grep -h '"title"' $fx/project*.json   # read each: every title must be a replaced one
```

- [ ] **Step 2: Write the failing tests**

Fake rows: `project list|view|item-list` answer from their files; `project create` answers `project-view.json`; `project link|item-add` and mutations are logged.

```bash
reset; pages 3
# found by title among the owner's projects, not linked yet: link, no create
jq '.projects[0].title = "agent-skills roadmap"' "$fixtures/project-list.json" >"$FAKE/project-list.json"
jq '.items[0].content = {number: 1, repository: "kalinichenko88/agent-skills", type: "Issue"}' "$fixtures/project-items.json" >"$FAKE/project-items.json"
out=$(DRY_RUN=1 bash "$scripts/board.sh")
check 'no create' 0 "$(grep -c 'project create' <<<"$out")"
check 'links a project found by title' 'linked kalinichenko88/agent-skills' "$(grep '^linked ' <<<"$out")"
check 'adds only the missing issues' 'issues to add: 2' "$(grep '^issues to add: ' <<<"$out")"
check 'both views missing' "$(printf 'view Unassigned: missing\nview By milestone: missing')" "$(grep '^view ' <<<"$out")"
check 'the filter of Unassigned' 1 "$(grep -c 'is:issue\\ is:open\\ no:assignee\\ -milestone:Later' <<<"$out")"
check 'the manual steps' 1 "$(grep -c '^Two settings the API cannot make. Open ' <<<"$out")"
# a linked project of that title: no link; views there are not made again
jq '.data.repository.projectsV2.nodes = [{number: 6, title: "agent-skills roadmap", url: "https://github.com/users/kalinichenko88/projects/6", closed: false}]' \
  "$fixtures/projects-linked.json" >"$FAKE/projects-linked.json"
jq '.data.node.views.nodes = [{name: "Unassigned"}, {name: "By milestone"}]' "$fixtures/project-views.json" >"$FAKE/project-views.json"
out=$(DRY_RUN=1 bash "$scripts/board.sh")
check 'a linked project is not linked again' 0 "$(grep -c '^linked ' <<<"$out")"
check 'views there' "$(printf 'view Unassigned: there\nview By milestone: there')" "$(grep '^view ' <<<"$out")"
# none: create and link, in a dry run
reset
out=$(DRY_RUN=1 bash "$scripts/board.sh")
case $out in *'dry run: gh project create --owner kalinichenko88 --title agent-skills\ roadmap'*'dry run: gh project link'*'no project yet'*) ;;
  *) fail 'creates and links the project' "$out" ;; esac
# a failed create stops with the reason
reset; FAKE_FAIL='project create' bash "$scripts/board.sh" >"$tmp/out" 2>&1 && fail 'board.sh exits 0 when create fails'
grep -q '^cannot create a project under kalinichenko88: ' "$tmp/out" || fail 'board.sh names the failed create'
```

- [ ] **Step 3: Run them to see them fail**

Run: `./tests/roadmap_scripts_test.sh`
Expected: FAIL at `no create`.

- [ ] **Step 4: Write `board.sh`**

- [ ] **Step 5: Run the tests to see them pass**

Run: `make check`
Expected: `roadmap_scripts_test: ok`.

- [ ] **Step 6: Commit**

```bash
git add skills/roadmap/scripts/board.sh tests/roadmap_scripts_test.sh tests/fixtures/roadmap
git commit -m "feat(roadmap): set up the project board with its saved views"
```

### Task 6: Assign at take-in in every path (github skill)

**Files:**
- Modify: `skills/github/scripts/worktree.sh` (header, usage, a third argument)
- Modify: `skills/github/take-in.md` (*The work then starts in a worktree*, *Taking neighbours along*)
- Modify: `skills/github/SKILL.md` (the take-in row)
- Modify: `tests/github_scripts_test.sh`

**Interfaces:**
- Produces `worktree.sh <n> <branch> [--here]`. With `--here`, after the same assignment step, it runs `gh issue develop <n> --name <branch> --checkout` in the current checkout and prints `git rev-parse --show-toplevel`; no worktree, no `info/exclude` edit. Usage: `usage: worktree.sh <n> <branch> [--here]`; any other third argument is a usage error.

- [ ] **Step 1: Write the failing test**

```bash
answer .
rm -f "$tmp/linked"
: >"$tmp/calls"
out=$(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 feat/5-scout-citations --here)
check 'worktree.sh --here assigns and checks the branch out where it is' \
  "$(printf 'dry run: gh issue edit 5 --add-assignee @me\ndry run: gh issue develop 5 --name feat/5-scout-citations --checkout\n%s' "$top")" "$out"
bash "$scripts/worktree.sh" 5 b --there >/dev/null 2>&1 && fail 'worktree.sh takes an unknown third argument'
```

- [ ] **Step 2: Run it to see it fail**

Run: `./tests/github_scripts_test.sh`
Expected: FAIL at `worktree.sh --here assigns …`.

- [ ] **Step 3: Change `worktree.sh`, then the docs**

`worktree.sh`: accept `--here` as an exact third argument, and take the path of the in-a-worktree case. `take-in.md`, *The work then starts in a worktree*: "a branch only" runs `worktree.sh <n> <branch> --here`, which assigns the issue too; "stay on this branch" runs `gh issue edit <n> --add-assignee @me` and nothing else. *Taking neighbours along*: when an issue gets the verdict **Rides along** or **The change removes it**, assign it at once with `gh issue edit <n> --add-assignee @me`, so nobody else takes it while the work runs; the last paragraph's "it is assigned like the task" names that moment. `SKILL.md` take-in row: add "assign each ride-along when it joins". The `gh pr create` rule stays.

- [ ] **Step 4: Run the tests to see them pass**

Run: `make check`
Expected: `github_scripts_test: ok` and `roadmap_scripts_test: ok`.

- [ ] **Step 5: Commit**

```bash
git add skills/github tests/github_scripts_test.sh
git commit -m "fix(github): assign the issue and its ride-alongs when they are taken in"
```

### Task 7: The skill's instructions and the docs

**Files:**
- Create: `skills/roadmap/SKILL.md`, `skills/roadmap/planning.md`, `skills/roadmap/lanes.md`
- Modify: `rules.md:146` (the reader exemption)
- Modify: `README.md` (a skill bullet, the `project` scope under *Install*, *Develop*: the new test)
- Modify: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json` (descriptions: "plus the github, roadmap, docker and typescript-conventions skills.")

**Interfaces:**
- Consumes: the script interfaces of Tasks 1–5, verbatim.
- `SKILL.md` frontmatter:

```yaml
name: roadmap
description: Use when planning a product's roadmap or milestones, asking which task to take next or what can run in parallel, asking what is left to close a milestone, re-planning after a milestone closes, or when an agent needs the project's roadmap as context.
```

- [ ] **Step 1: Write `SKILL.md`**

In the github skill's shape: one paragraph on what the skill is and that `board.sh` needs the `project` scope (`gh auth refresh -s project`); the moments table (`Moment | What must happen | Read first`) with the rows of the spec's *The moments*, `Later` by name included; a section per moment giving the script call and the answer's shape from the spec; *How the plan lives in GitHub* in short (milestone form, `Current.`, `Later`, blocked-by, sub-issues, busy, free, tracks, and that the board's *Unassigned* view is not "free": `next.sh` is); the overlap check: in Claude Code one `Agent` call with `model: "haiku"` and the prompt

```
Read <dir>/lanes.md and do what it says.
File: <the path next.sh printed>.
Tree: <the repository's top directory>.
```

and in Codex the agent follows `lanes.md` itself; a chosen task starts with the github skill's take-in, by its bare number; the script error rule. Every script call is `bash <dir>/scripts/<name>.sh`, as the github skill writes them.

- [ ] **Step 2: Write `planning.md`**

The spec's `planning.md` section as instructions. *Start*: read `docs/` by content, the README, the instruction file, the open issues and milestones; propose milestones with goal and `Done when`, tasks of one PR each, parents with sub-issues, links, `Later`; one approval; then `plan.sh create`, the issues through the github skill's `filing.md`, `gh issue edit <n> --milestone '<title>'` (the title from `read.sh milestone M1`), `plan.sh block`, `plan.sh sub`, `plan.sh current`, `board.sh`. *Re-planning*: `roadmap.sh <milestone>`; propose the close, the moves (`--remove-milestone` for none), the next milestone's plan, a milestone for the issues without one; the same approval and writes. A description example in the `M<n> · <name>` form with neutral text.

- [ ] **Step 3: Write `lanes.md`**

In `scout.md`'s shape: who reads it, and that it writes nothing and files nothing; the file's parts (`== Candidates`, `== Work in progress`, `==> …`, `cites:`, `files:`, `no diff yet`, `== end`); what to read: each candidate's cited files and the files that define the symbols its body names, found with `git -C <tree> ls-files` and `git -C <tree> grep -n` — the only two commands it runs — and each `no diff yet` entry the same way; the overlap rules: the same function, or a likely fix that moves into the other's file; a task that waits on a decision outside itself is not ready; additions that the project's instruction file exempts do not count. The return:

```
#21 Issue title [main path]
  files: src/runner/lease.ts (renewLease), src/runner/lease.test.ts
  why: the body names renewLease; git grep finds it only in lease.ts
  ready: yes
#22 Issue title [in progress, assigned to you]
  files: src/runner/lease.ts (claimStep)
Overlaps
#21 × #22: src/runner/lease.ts — renewLease calls claimStep, which #22 changes
```

and one last line: the entries read and the files opened.

- [ ] **Step 4: Update `rules.md`, the README and the manifests**

`rules.md:146`: "A read-only subagent sent with the skill's `scout.md`, or with the roadmap skill's `lanes.md`, follows that file instead: it does not load the skill and files nothing." Keep the file under 10,000 characters (`wc -c rules.md`).

README: a `kalinichenko:roadmap` bullet after the github one (what it answers; the plan lives in milestones and blocked-by links; scripts read GitHub, a Haiku subagent reads code for the overlap check; a GitHub Project gives the views). Under *Install*, after the Codex block: "The roadmap skill's board needs the `project` scope on the `gh` token. Run once on each machine: `gh auth refresh -s project`." Under *Develop*: the sentence on the github scripts' test also names `tests/roadmap_scripts_test.sh` and its fixtures, recorded from public sources.

- [ ] **Step 5: Check**

Run: `make check`
Expected: `claude plugin validate .` passes; the rules test passes; both script tests end with `ok`.

- [ ] **Step 6: Commit**

```bash
git add skills/roadmap/SKILL.md skills/roadmap/planning.md skills/roadmap/lanes.md rules.md README.md .claude-plugin .codex-plugin
git commit -m "feat(roadmap): add the skill's instructions, planning and the overlap reader"
```

### Task 8: Run it against a real repository

**Files:** none changed unless a check fails.

- [ ] **Step 1: Read-only runs**

Ask the owner which repository to use: one with milestones, more than 100 open issues and at least one blocked-by link. Then:

```bash
GH_REPO=<owner/repo> bash skills/roadmap/scripts/roadmap.sh | grep '^## '
GH_REPO=<owner/repo> bash skills/roadmap/scripts/roadmap.sh M1 | head -20
GH_REPO=<owner/repo> bash skills/roadmap/scripts/next.sh
GH_REPO=<owner/repo> DRY_RUN=1 bash skills/roadmap/scripts/plan.sh current M1
GH_REPO=<owner/repo> DRY_RUN=1 bash skills/roadmap/scripts/board.sh
```

Expected: exit 0 for each; the `##` lines are the open milestones in their order with `Later` last, then `No milestone` only when an issue has none; an issue whose only blocker is closed shows no blocker; `next.sh` prints the four `==` sections and an `overlap:` line; each dry run prints its writes and changes nothing on GitHub. A failure here is a gojq difference or a shape the fixtures miss: fix the script, add the case to the test, run `make check`.

- [ ] **Step 2: Keep the output out of the repository**

Check: `git status --short` shows no new file. Name the repository nowhere in the commit.

- [ ] **Step 3: Commit any fix**

```bash
git commit -am "fix(roadmap): <what the real run showed>"
```
