# The roadmap skill — design

Date: 2026-10-23. Status: design, approved for planning when the person says so.

A new skill in the `kalinichenko` plugin, `kalinichenko:roadmap`: a project
manager on top of GitHub. It works in Claude Code and in Codex, and it builds on
`kalinichenko:github`.

## Why

The person wants to set the direction of a product, its priorities and what can
run in parallel, and to ask at any moment:

- "What can I take now?"
- "What can I take in parallel with the main work?" — bugs and small tasks next
  to the main branch of work.
- "What is the next task on the roadmap? What on the roadmap can run in
  parallel?"
- "What is needed to close this stage (milestone)?"

At the start of a project, the same skill helps build the roadmap.

What exists now, and why it is not enough:

- Hand-written roadmap files go stale. In three of the owner's projects, the
  file stopped matching the work within months, and one project dropped it for
  another tracker.
- A read-only PM command over another tracker cannot carry dependencies or
  priority into GitHub milestones.
- The closest flow is a project that keeps milestones `M0 · …` to `M5 · …`
  plus `Later` in GitHub, each with a `Done when` sentence, and works in up to
  three parallel lanes. A command there checks by hand that lanes do not change
  the same code. That project wants the graph kept from GitHub itself, with
  tracks (main path, secondary, bugs), and wants the next task and the parallel
  sets proposed. It almost never uses GitHub's native "blocked by" link.

## Goals

1. Answer "what can I take now": one free task, the best one, with the reason.
2. Answer "what can I take in parallel", next to the main work or on the
   roadmap itself: a set of free tasks whose code does not overlap with each
   other or with work in progress by anyone.
3. Answer "what is left to close milestone X": its open tasks in dependency
   order, what is in progress, what is blocked and by what.
4. Print the roadmap as text, read from GitHub at that moment, so an agent can
   take it as context.
5. Build a roadmap at the start of a project, from the project's `docs/`, in a
   dialog. Then create the milestones, the issues and the "blocked by" links.
6. Re-plan: when a milestone closes, or when the person asks. Move issues,
   change links, and plan the next milestone again.
7. Show the plan visually through a GitHub Project with saved views, which the
   skill creates.
8. Work for several equal developers on one project.
9. Work in Claude Code and in Codex.

## Non-goals

- No graph of our own: no HTML page, no Mermaid, no image. The person decided
  this: GitHub shows blocked issues on boards and lists, and a Project gives the
  views.
- No `docs/roadmap.md`, committed or local. The person first chose a local,
  git-ignored file, then dropped it once GitHub covered the visual side. The
  roadmap is printed to stdout on demand, so nothing can go stale.
- No split of work between people. The developers are equal: a free, unblocked
  task goes to whoever takes it first (the person's words). Assigning work to
  people is later work.
- No change to the ride-along logic of `kalinichenko:github` take-in. The
  person asked to keep it. Tasks on the same code ride along in the same PR, as
  now; tasks on other code run in parallel, each in its own worktree and PR.
- No dates or estimates on milestones (my call: the owner's projects do not
  use them).
- No priority labels and no priority field in Projects (my call, which the
  person confirmed in the playback). The order comes from the milestone order
  and from how many tasks a task unblocks.
- No migration of other projects from their trackers, and no change to their
  own PM commands. Those projects can adopt the skill later, in their own repos.
- No pictures in `docs/` for this skill in this change (my call). The
  `infographic` skill can add them later.

## Anti-goals

These would make the skill a failure even if it works:

- A roadmap that can be out of date. Everything the skill shows is read from
  GitHub when it is asked.
- An LLM doing what an API call can do. The person said: use the GitHub API
  instead of AI where possible.
- Merge conflicts caused by the skill. No file that every PR touches.
- Offering a task that someone else holds.

## How the plan lives in GitHub

These are decided.

- **A stage is a milestone.** Its title is `M<n> · <name>`. Its
  description is a short goal, then one sentence that starts with `Done when`:
  an outcome someone can see in a demo. The last milestone is `Later`: what is
  wanted but not planned. The skill writes milestones in this form and reads any
  other form as it is.
- **The order of milestones** comes from the number after `M` at the start of
  the title. Titles without that number come after the numbered ones, in their
  milestone-number order. `Later` (title match, any case) is always last (my
  call).
- **A dependency is GitHub's native "blocked by" link.** GraphQL has
  `addBlockedBy(issueId, blockingIssueId)`, `removeBlockedBy`, the issue fields
  `blockedBy` and `blocking`, and `issueDependenciesSummary { blockedBy
  totalBlockedBy blocking totalBlocking }`, where `blockedBy` counts only open
  blockers. REST has `repos/{o}/{r}/issues/{n}/dependencies/blocked_by`. All of
  this was checked against the live API on 2026-10-23.
- **A task too large for one PR** is a parent issue with sub-issues
  (`addSubIssue`). A parent with open
  sub-issues is never offered: its sub-issues are. The count of open
  sub-issues comes from `subIssuesSummary { total completed }`, so it counts
  sub-issues in other repositories too. A sub-issue without a milestone takes
  its parent's, as GitHub reports it on the `parent` field, so a closed parent
  still gives its milestone. A sub-issue also waits on its parent's open
  blockers, and the cycle check in `plan.sh` counts the parent link as an edge
  (my calls).
- **A milestone that is closed** while it still has open issues (GitHub allows
  it) counts as no milestone for those issues.
- **Busy** means: an assignee, a linked branch (`linkedBranches`), or an open
  PR that closes the issue (`closedByPullRequestsReferences`). These are the
  github skill's `take-in-check.sh` refusals plus the linked branch, so the
  skill never offers what take-in would refuse. An open PR that only mentions
  an issue does not make it busy (my call: a mention is not work on it, and
  reading every issue's timeline costs a query per page). That PR's files
  still count as work in progress in the overlap check.
- **Free** means: open, not busy, no open blockers (its own or its parent's),
  not a parent with open sub-issues, and not in `Later`, unless an open issue
  outside `Later` waits on it through any chain: then it is needed, however
  it got there (a link, `gh issue edit` or GitHub's own pages). Any other
  task in `Later` is offered only when the person asks for `Later` by name:
  then `roadmap.sh Later` shows each one's state.

### Tracks

- **Main path:** free issues without the bug label in the current milestones
  (see *Current milestones* below), `Later` excluded. Every open issue they
  wait on belongs to the main path too, through any chain and wherever it sits:
  their open blockers and their open sub-issues. It is what holds the milestone
  up (my call). When no main-path task is
  free, the answer says so and offers the free tasks of the next milestone
  in order: the first after the first current one that is not current and
  not `Later` (my call).
- **Bugs:** free issues with the repository's bug label, in any milestone or
  none. The label name comes from `gh label list`, as the github skill's
  `collect.sh take-in` takes it. A bug in `Later` follows the `Later` rule above
  (my call).
- **Secondary:** every other free issue: in later milestones, without a
  milestone, and debt.

### Current milestones

The person marks the current milestones. A current milestone has the line
`Current.` on its own in its description. `plan.sh` sets and removes it; the
person does not edit descriptions by hand for it. When no open milestone has
the line, the current one is the first open milestone in order. `Later` is
never current.

The person chose this because one rule cannot see it: a project can run `M0` in
parallel with `M1` by its own decision, while `M2` to `M5` are open and not
started. There, the person marks `M0` and `M1` once.

`roadmap.sh` shows which milestones are current.

### Ranking

Inside a track, by these keys in turn: the effective order, then the number of
open issues that wait on it directly or through a chain (more first), then the
issue number (older first). The effective order is the lowest milestone order
among the issue and every open issue that waits on it, so a blocker in `M3`
of an `M1` task ranks with `M1`. `awk` computes all of it from one read of the
tracker.

Across tracks, for "what can I take now": the main path first, then bugs, then
secondary. The answer also names the top bug as the alternative. This follows
the person's words: the roadmap is the main work, and bugs and small tasks are
what runs next to it.

## How it is built

The pattern is the github skill's: scripts do every step that has one correct
result, a small model reads big inputs in Claude Code, and the main model
decides and talks to the person.

### Scripts

In `skills/roadmap/scripts/`. Each one needs only `bash`, `gh` and POSIX tools,
filters JSON with `gh`'s own `--jq`, prints a usage line on bad arguments and
exits 2, and honours `GH_REPO`. `--jq` runs once per page, and
`gh api --paginate --slurp` refuses `--jq` (checked on `gh` 2.103.0), so each
page becomes tab-separated records and `awk` computes the graph across pages. Each script that writes honours `DRY_RUN=1`: it prints its write
commands and runs none. As in the github skill's `tracker.md`: a script error
stops that step, and the agent does not do the step by hand with `gh` instead.
GraphQL reads paginate: a project can have more than 100 open issues.

- **`roadmap.sh [milestone]`** — reads. With no argument, it prints the roadmap
  as Markdown: each milestone in order with its goal, its `Done when`, its
  progress (closed of total), and its open issues with their state: in
  progress (by whom, with the PR or branch), free, or blocked (by which
  numbers). `Later` shows as titles only. Issues with no milestone show as a
  count with their numbers, so the person can sort them. With a milestone, it
  prints only that milestone and its open issues in dependency order,
  including blockers that sit in other milestones. This covers goals 3 and 4.
- **`next.sh`** — reads. It prints the free tasks per track, ranked, and the
  work in progress: each busy issue, who holds it, and the files it changes.
  The files come from the API: an open PR's `files` (past 100 files, the REST
  list of the PR's files, so none is missed), or for a linked branch
  without a PR, the compare of the default branch with that branch. Every open
  PR counts as work in progress, also one that closes no issue (a Dependabot
  bump, a quick fix). A busy issue with no diff yet — the usual state right
  after take-in — has no files from the API: it goes into the overlap file with
  its body, like a candidate (my call). The script also writes that file for
  the overlap check (below) and prints its path and size. The file holds the
  body and the cited paths of every free main-path task (the roadmap question
  has no cap) and of the top 5 of bugs and of secondary, and the work in
  progress as above.
- **`plan.sh`** — writes. Subcommands: create, edit and close a milestone;
  mark a milestone current and remove the mark; add and remove a "blocked by"
  link; add a sub-issue; put a task off into `Later`. It refuses a change that
  would make a cycle, and says
  which chain it found. The check covers every edge the change adds, the
  inherited ones too: a block on a parent also blocks its sub-issues. Putting
  issues into a milestone needs no script: `gh issue edit --milestone`, with
  nothing to check.
- **`board.sh`** — writes. It finds the GitHub Project titled
  `<repository> roadmap` among the repository's linked projects
  (`repository.projectsV2`), then among the owner's projects, and links it when
  it is not linked yet. It takes no linked project of another title: views
  would land on a board someone else owns. If there is none, it creates one
  under the repository's owner — the organization for an organization's
  repository, the user for a personal one — private, as `gh project create`
  makes it, and links the repository to it (my calls). When the account cannot create a project
  there, the script says so and stops: one shared board, never one per
  developer. It adds the open issues that are not in it yet (idempotent:
  running it again only adds what is missing), and creates the saved views.
  `createProjectV2View` and `updateProjectV2View` take a name, a layout
  (`BOARD_LAYOUT`, `TABLE_LAYOUT`, `ROADMAP_LAYOUT`) and a `filter`. The API
  cannot set grouping or turn on a Project workflow, so the script prints the
  two settings to make by hand once: group *By milestone* by milestone, and
  turn on the Project's built-in auto-add workflow for this repository's open
  issues, so issues filed later reach the board. The views: *Unassigned*
  (board: `is:issue is:open no:assignee -milestone:Later`) and *By milestone*
  (table: `is:issue is:open`). GitHub's page on project filters (read on
  2026-10-23) documents no qualifier for blocked issues, so the board cannot
  show "free" as the skill means it; a blocked card carries GitHub's own
  *Blocked* mark, and `next.sh` stays the one answer to "what is free". No
  roadmap-layout view: it places items by dates, and milestones have none (my
  call).

Projects need the `project` token scope: `gh auth refresh -s project`. The
person ran it on this machine; the README says so for the next one.

### Where a model is needed

Only in two places.

- **The overlap check.** Which files and functions will a candidate task
  change? The script gives the cited paths and the files of the work in
  progress. A reader fills the gaps from the code: the files that define the
  symbols an issue names, and the tests and docs that change with them. The
  rules: two tasks overlap when they change the
  same function, or when one's likely fix moves into the other's file. A task
  that waits on a decision outside itself is not ready. A project's own
  instruction file can name additions that do not count, for example new
  entries in a shared registry. In Claude Code, a
  Haiku subagent does this reading every time, whatever the file's size, as the
  github skill's citations job does: the reading it saves is in the code. Its
  instructions are in `lanes.md`, next to `SKILL.md`, in the shape of the github
  skill's `scout.md`. It returns, per candidate, the files and functions with
  the evidence, and the overlaps it found. The main model picks the set. In
  Codex, the main agent follows `lanes.md` itself.
- **Planning.** The dialog over `docs/` and the cut into milestones and issues.
  This is the main model's work, in the conversation, in both harnesses.

### The moments

`SKILL.md` opens with a table of moments, as the github skill's does, each with
what must happen and which file to read first.

- **"What can I take now", "what is next on the roadmap".** Run `next.sh`. Give
  one task: its number, title, track and milestone, and why it is first (for
  example, "it is in M1 and 2 issues wait on it"). When the person takes it, the github
  skill's take-in starts with the bare number, as now.
- **"What can I take in parallel with the main work".** Run `next.sh`, then
  the overlap check. Give one task from bugs and one from secondary that do not
  overlap with each other or with any work in progress, the person's own
  main-path task included.
- **"What on the roadmap can run in parallel".** The same, from the main path:
  every free main-path task that overlaps with no other in the set and with no
  work in progress, ranked. No fixed cap: a project that caps its lanes, for
  example at three, says so in its own instructions (my call).
- For both: then a short table with each task's files, and each overlap in one
  line with the file and the function. Each chosen task starts through
  take-in, in its own worktree.
- **"What is needed to close M1".** Run `roadmap.sh M1` and answer from it.
- **"What can I take from Later".** Run `roadmap.sh Later` and offer its free
  tasks.
- **The person decides to put a task off.** After the person agrees in the
  conversation, `plan.sh later <n>` moves it into `Later`, opens that
  milestone again when it is closed, and makes it when there is none. A task
  in `Later` that an issue outside `Later` waits on is still offered, so the
  move would not put it off: the script refuses when an open issue outside
  `Later` waits on it through any chain, or on a sub-issue of it with no milestone of its own,
  which goes into `Later` with it, and names those issues. `plan.sh sub` refuses the same for a child that
  goes under a parent in `Later`.
- **An agent needs the roadmap as context** (brainstorming, a plan, a review).
  Run `roadmap.sh`.
- **Start a roadmap.** Follow `planning.md` (below).
- **A milestone has no open issues left, or the person asks to re-plan.** Follow
  `planning.md`, *Re-planning*.

The skill answers the account that `gh` is logged in as. Its own work in
progress shows as context. Other people's busy tasks are never offered.

### `planning.md`

**Start.** Read the project's `docs/`. Its format and its file names are not
fixed: list the folder, then read what describes the product, its users, its
goals, its competitors and its limits, by content and not by name. Read the
README and the project's instruction file too. Read the open issues and the
existing milestones as well, so nothing is filed twice. Then talk it through
with the person. Propose in the chat, before any write:

- the milestones in order, each with its goal and its `Done when`, plus
  `Later`;
- per milestone, its tasks: a title, and a body that says what and why and
  cites the doc it came from. Each task fits one PR; a larger one is a parent
  with sub-issues;
- the "blocked by" links.

After the person approves the list, create it: the milestones and links with
`plan.sh`, the issues through the github skill's `filing.md` (a search first,
existing labels only), then `board.sh`. One approval covers the whole list.

**Re-planning.** Show `roadmap.sh` for the milestone. Propose: close it, which
is the person's call; move what is left; plan the next milestone's issues again;
give a milestone to the issues
that have none. Then write the same way as at the start.

## Changes to the github skill

Busy is read from the assignee, so the assignee must be set when the work
starts. Two gaps exist now:

1. **The issue in hand.** `worktree.sh` assigns it, but take-in also allows "a
   branch only" and "stay on this branch", and then nothing assigns it.
   Take-in must assign it in every path: `worktree.sh --here` makes the branch
   in the current checkout and assigns, and "stay on this branch" assigns with
   `gh issue edit <n> --add-assignee @me` and touches no branch.
2. **Ride-alongs.** They are assigned only at `gh pr create` (*Pull requests*
   in `SKILL.md`). Until then they look free, and someone else can take them.
   Take-in must assign each one when it decides that the issue rides along, or
   that the change removes it. The `gh pr create` rule stays as a check.

Nothing else in the github skill changes. The ride-along rules stay as they
are.

## Tests

The same harness as `tests/github_scripts_test.sh`: a fake `gh` that answers
from recorded payloads and logs every call. A new `tests/roadmap_scripts_test.sh`,
with its payloads in `tests/fixtures/roadmap/`. `make check` runs it and
shellchecks `skills/roadmap/scripts/*.sh`.

The payloads must have the real shape, recorded from GitHub, not typed by hand
(the base prompt's rule). `agent-skills` is a public repository, and the
owner's product repositories are private: no title, body, login or path from
them may land in a fixture. So every payload is recorded from a public source —
this repository's own issues and pull requests, a public repository's
milestones — or, for the owner's projects, cut down to the fields the script
reads, with the text replaced. A test case changes a recorded payload with
`jq`, as the github tests do. Cases that must be covered: pagination past 100
issues, a closed blocker (it does not block), a chain of blockers across
milestones, a parent with open sub-issues, each of the three busy signals,
`Later`, an issue with no milestone, a closed milestone, and a cycle that
`plan.sh` refuses, also one made through an inherited blocker.

## Documents that change with it

- `README.md`: a section for `kalinichenko:roadmap`, and under *Install* the
  line `gh auth refresh -s project` with the reason.
- The descriptions in `.claude-plugin/plugin.json`,
  `.claude-plugin/marketplace.json` and `.codex-plugin/plugin.json` list the
  skills: add roadmap.
- `Makefile`: the new shellcheck path and test.
- `skills/github/take-in.md`, `skills/github/scripts/worktree.sh` and the
  take-in row in `skills/github/SKILL.md`, for the two assignment changes.
- `rules.md`: the base prompt tells every subagent to file what it finds, and
  exempts only a reader sent with `scout.md`. The `lanes.md` reader writes
  nothing either, so the same sentence names it.
- `CHANGELOG.md` is written by `/release`, not by this change.

## Left to the builder

- The exact output layout of each script, within what is said above.
- Whether `roadmap.sh` and `next.sh` share one reader script or one GraphQL
  query file.
- The wording of the skill's description. It is in English, as the other
  skills' are; it triggers on the questions in *Why* in any language.
