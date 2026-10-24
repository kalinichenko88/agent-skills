---
name: roadmap
description: Use when planning a product's roadmap or milestones, asking which task to take next or what can run in parallel, asking what is left to close a milestone, putting a task off to Later, re-planning after a milestone closes, or when an agent needs the project's roadmap as context.
---

# Planning on GitHub

The plan lives in GitHub: milestones, "blocked by" links and sub-issues.
Scripts read it at the moment of the question, so the answer cannot be out of
date. Nothing is kept in the repository. Everything here needs `gh`
authenticated against a GitHub remote; `board.sh` also needs the `project`
scope on the token: `gh auth refresh -s project`. Where `gh` does not work,
say so and stop.

| Moment | What must happen | Read first |
| --- | --- | --- |
| "What can I take now", "what is next on the roadmap" | `next.sh`; give one task, its track and milestone, and why it is first | *One task* below |
| "What can I take in parallel with the main work" | `next.sh`, then the overlap check; one bug and one secondary task that overlap with nothing | *Parallel work* below |
| "What on the roadmap can run in parallel" | `next.sh`, then the overlap check; every free main-path task that overlaps with nothing | *Parallel work* below |
| "What is needed to close M1" | `roadmap.sh M1`; its open tasks in dependency order, what is in progress, what is blocked and by what | *The roadmap* below |
| "What can I take from Later" | `roadmap.sh Later`; offer its free tasks | *The roadmap* below |
| The person decides, in the conversation, to put a task off | `plan.sh later <n>`; a refusal names the issues that wait on it | *Putting a task off* below |
| An agent needs the roadmap as context | `roadmap.sh` | *The roadmap* below |
| Start a roadmap | read `docs/`, propose, one approval, then write | `planning.md` |
| A milestone has no open issues left, or the person asks to re-plan | the same, from that milestone | `planning.md`, *Re-planning* |
| The person wants the board | `board.sh`; pass on the two settings it prints | *The board* below |

A file in the last column sits next to this one, in this skill's base
directory. Read all of it before the first step of that moment.

## How the plan lives in GitHub

- **A stage is a milestone**, titled `M<n> · <name>`. Its description is a
  short goal and a `Done when` sentence: an outcome someone can see in a demo.
  The order comes from the number after `M`; other titles come after; `Later`
  is last and holds what is wanted but not planned.
- **The current milestones** have the line `Current.` in their description.
  `plan.sh current` and `plan.sh not-current` set and remove it. When no
  milestone has it, the first open one is current. `Later` is never current.
- **A dependency** is GitHub's "blocked by" link. A task too large for one PR
  is a parent issue with sub-issues. A sub-issue without a milestone takes its
  parent's, and it waits on its parent's blockers too. A parent with open
  sub-issues is never offered: its sub-issues are.
- **Busy** means an assignee, a linked branch, or an open PR that closes the
  issue. **Free** means open, not busy, with no open blocker of its own or of
  its parent, no open sub-issue, and not in `Later` — unless an open issue
  outside `Later` waits on it, through any chain: then it is needed.
- **The tracks.** The main path is the free issues without the bug label in
  the current milestones, and every free issue they wait on, wherever it is.
  Bugs are the other free issues with the bug label. Secondary is every other
  free issue. A track ranks by milestone order — a blocker of an `M1` task
  ranks with `M1` — then by how many issues wait on it, then oldest first.
- An issue goes into a milestone with `gh issue edit <n> --milestone '<title>'`,
  out of it with `--remove-milestone`, and into `Later` with `plan.sh later`.

The developers are equal: a free task goes to whoever takes it first. The
answer is for the account that `gh` is logged in as. Its own work in progress
shows as context; other people's busy tasks are never offered.

## Scripts

The scripts are in `scripts/`, next to this file. Run each one as
`bash <dir>/scripts/<name>.sh`, where `<dir>` is this skill's base directory.
They need only `bash`, `gh` and `awk`. `GH_REPO=<owner/repo>` points them at
another repository than the checkout's. `plan.sh` and `board.sh` write; with
`DRY_RUN=1` they print their write commands and run none.

A script can stop with an error, from `gh` or from its own usage check. Then
its step is not done: report the error and stop at that step. Do not do the
step by hand with `gh`: that skips the checks the script makes. A line that
starts with `refused:` is not an error: it says why `plan.sh` wrote nothing.
Tell the person, and change the plan, not the check.

## One task

```bash
bash <dir>/scripts/next.sh bug
```

The argument is the repository's name for the bug label in `gh label list`.
The script prints the current milestones, then the sections `== main path`,
`== bugs` and `== secondary` — each one's top 5, ranked, as `#21 <title>
(<milestone>), unblocks 2` — then `== in progress`, and last the path of the
overlap file. When nothing on the main path of the current milestones is
free, a `note:` line says so, and the main path comes from the next
milestone: the first after the first current one that is not current and not
`Later`.

Give one task: the first of the main path, else of bugs, else of secondary.
Give its number, title, track and milestone, and why it is first, as "it is
in M1 and 2 issues wait on it". Name the top bug as the alternative. When the person
takes a task, the `kalinichenko:github` skill's take-in starts with its bare
number, as `#21`: it checks the task and assigns it.

## Parallel work

Run `next.sh`, then the overlap check on the file it printed. In Claude Code,
send one `Agent` call with `model: "haiku"` and this prompt, whatever the
file's size — the reading it saves is in the code:

```
Read <dir>/lanes.md and do what it says.
File: <the path next.sh printed>.
Tree: <the repository's top directory>.
```

In Codex, follow `lanes.md` yourself and write its return as your notes.

Then pick a set. No task in it overlaps with another task in it, or with any
work in progress, your own included:

- **Next to the main work:** one task from bugs and one from secondary.
- **On the roadmap:** every free main-path task, ranked. There is no cap,
  unless the project's own instructions set one.
- A task whose return says `ready: no` waits on a decision outside it: leave
  it out and say what it waits on.

Answer with a short table of the set: each task and its files. Then each
overlap in one line, with the file and the function. Each task in the set
starts through take-in, in its own worktree. The file holds every main-path
task, but only the top 5 of bugs and of secondary: when all five overlap, say
so.

## The roadmap

```bash
bash <dir>/scripts/roadmap.sh
bash <dir>/scripts/roadmap.sh M1
```

With no argument, it prints each open milestone in order: its progress
(`current, 22 of 54 closed`, then `, due 2026-12-01` when it has a due date),
its description, and its open issues in dependency order, each with its state
— `free`, `blocked by #21`, `open sub-issues: 2`, or who has it. The progress
counts the milestone's issues, not its pull requests; a milestone closed while
the script runs shows `not counted`. `Later` shows titles only. Issues with no
milestone come last, as a count with their numbers. With a milestone — `M1`,
`Later` or a whole title — it prints that milestone alone, with its states,
and with the open issues it waits on in other milestones, each marked with
where it is.

## Putting a task off

When the person and the agent agree, in the conversation, that a task can
wait, it goes into `Later`. Move it only after the person says so.

```bash
bash <dir>/scripts/plan.sh later 21
```

It opens the `Later` milestone again when it is closed, and makes it when
there is none. A task in `Later` that an issue outside `Later` waits on is
still offered, so the move would not put it off: the script refuses when an
open issue outside `Later` waits on the task, through any chain — a blocked
issue, or a parent that waits on its sub-issue — and names them. A sub-issue with no milestone of its own goes into `Later` with its
parent, so an issue that waits on it counts too, and `plan.sh sub` refuses
the same for a child that goes under a parent in `Later`. Then ask the person: put those off too, or remove the link with
`plan.sh unblock`. A task comes back from `Later` with
`gh issue edit <n> --milestone '<title>'`.

## The board

```bash
bash <dir>/scripts/board.sh
```

It finds the GitHub Project titled `<repository> roadmap`, or creates it
under the repository's owner, and links it to the repository. It adds the
open issues it does not hold yet, and creates two views: *Unassigned*, a board
of the open issues that nobody has, and *By milestone*, a table. It ends with
two settings the API cannot make; pass them to the person. Run it again at
any time: it only adds what is missing. The *Unassigned* view does not know
blockers or sub-issues, so it is not the list of free tasks: `next.sh` is.
