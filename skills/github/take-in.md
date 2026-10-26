# Taking an issue into work

Read `tracker.md`, next to this file, before the first step: it runs the
scripts and reads the tracker. `<dir>` is this skill's base directory.

An issue named on its own — `#91`, "take #91", its URL — as the session's first
message, or after a talk about which task is next, is the request to take it
into work; a mention inside other work is not. Check it first: `bash
<dir>/scripts/take-in-check.sh 91`, or with its URL. It prints `take #91`, or
each reason why not. Closed, assigned to someone else, or closed by an open
pull request someone else wrote — say so and wait. An issue of another
repository than this checkout's — say so and stop.

**The tracker is read next.** Run `collect.sh take-in` (`tracker.md`) with the
issue's number and the names it gives. While a subagent reads the file, you can
set up the worktree below: the worktree is not the work, so the duplicates can
still close before the work starts. The scout's groups hold the duplicates, the
bugs and debt in the same area, the neighbours, and the linked issues, open
work and history; the rest of this file works from them. An issue with `##
Also:` sections is one task: its own problem and every added one.

**Its duplicates close first.** A duplicate — the same report, in different
words or not, about the same place — closes against the issue in hand before
the work starts, once anything it adds (a repro, an error message, a surface)
is carried into a comment on the survivor. One that is someone else's work
stays open: say so. A report that gives only what someone saw — no cause, no
code — matches by symptom alone: it waits for the reproduction, run in the
task's worktree, and closes the same way once that shows the same cause;
otherwise it stays open, with a comment naming what else could explain it.
Name every one closed in the final report.

```bash
gh issue close 96 --duplicate-of 91 --comment "Same report as #91; what it adds is copied there."
```

The same defect on another surface is not a duplicate: it is the task, and
*Taking neighbours along* below takes it in, with every other hit.

**The work then starts in a worktree**, by default — this line is the explicit
instruction a harness's worktree tool waits for. The user's message or the
project's instructions can say otherwise — "a branch only", "stay on this
branch" — and then they win. Each path assigns the issue to you, because an
unassigned issue looks free to everyone else: "a branch only" runs
`worktree.sh` with `--here`, which makes no worktree and works in the current
checkout, and "stay on this branch" runs `gh issue edit 91 --add-assignee @me`
and touches no branch. `worktree.sh` does not assign the issue in two cases,
below: it warns in one and stops in the other. "Stay on this branch" checks
the case of the warning first, with `gh issue develop --list 91` and the
issue's assignees. In that check, a branch linked in any repository counts.

The branch, and the worktree when one is made, carry one name that says what
the work is: `<type>/<number>-<two to four words>`, the type from *Commits* in
`SKILL.md`, in English — `fix/91-electron-binary-in-lanes`, never `issue-91` or
the whole title.

```bash
bash <dir>/scripts/worktree.sh 91 fix/91-electron-binary-in-lanes
```

It assigns the issue to you, branches from the remote's default branch, links
the branch to the issue, and prints the path to work in as its last line. A
branch linked to the issue in this repository wins over the name you gave. A
branch already checked out is worked on where it is. A session already in a
worktree, as one started with `claude --worktree` or `codex --worktree`,
checks the branch out where it is, and so does `--here`.

A linked branch in another repository does not win: without `--branch-repo`,
`gh` would make a new branch with the same name here. When every linked branch
is in another repository, as a fork's, the script stops before it assigns or
makes anything, and prints their URLs. Give the person those URLs and wait:
the person decides. A rerun with another name stops the same way. A rerun goes
on only when the issue has a linked branch in this repository, or no linked
branch at all.

A linked branch in this repository, on an issue that nobody is assigned to,
can be someone else's: the script warns, and does not assign the issue to you.
Find out whose the branch is before you push to it. Someone else's: say so and
wait. Yours: run the command the warning gives, which assigns the issue to you.

Then move into the worktree, when the script made one or found the branch in
one. Claude Code: `EnterWorktree` with the path it printed. Codex cannot move a running session: every command takes the worktree
as `workdir`, and every file path, read or patched, is written under it.

Then read what points at it: the scout's **Linked, open work and history**
group. It holds the timeline's cross-references, including the ones the
issue's own body never mentions — the newest 100, and the file says when there
are more — the open PRs that change the same code, and the closed issues and
merged PRs that changed it. An open PR there is work under way: say so before
you start on the same code. Read in full the open issues, the PRs that touched
the same code, and any closed issue whose outcome the task leans on; the
scout's line is enough for the rest.

Then check the issue's own `path:line` citations against the current tree before
believing them — a line number is the first thing to rot — and correct them in
the issue as the first act of the work. In Claude Code a scout checks them:
`Job: citations #91.` with the worktree as `Tree:` (`tracker.md`). A citation
that holds needs no look of yours; check each one that moved or is gone before
you edit.

## Taking neighbours along

Before the first edit, sort the open issues on the code the task will change.
The issue in hand stays the task throughout. A hit that is someone else's work
(`tracker.md`) gets no verdict below and stays as it is. Say so.

1. **Search.** The scout's groups hold the hits, found by identifier and by
   title, so a report that names no file still shows up. When the work reaches
   a file or symbol that `collect.sh` did not get, run
   `collect.sh filing verify_target` and read its file.
2. **Pull in the task's own defect.** A hit reporting the same wrong behaviour,
   fixed the same way, in another function or file is not a ride-along: it is
   the task, because a bug fix guards every surface the bug shows on (the
   global prompt). Its fix joins the diff, it closes next to the task's issue,
   and the PR title names the defect rather than the one place reported.
3. **Check every open bug and every debt issue in the same area first**,
   whatever the task is — a feature too. Bug and debt are the labels `bug` and
   `debt`, or the repository's own names for them in `gh label list`. An
   unlabelled issue that the scout marked `bug` or `debt` on its `why:` line
   counts too. They cost least to close while their code is being rewritten.
   So one PR can deliver the task, fix a bug in the same code and remove the
   debt there. Check each one against the code, and run a bug's reproduction
   when it gives one. Each ends in one of four ways:
   - **Already gone** — a commit on the default branch removed its cause: the
     debt's code is gone, or the bug's cause is fixed and its reproduction now
     passes. Close it with a comment that names that commit, and for a bug
     that run. A bug that gives no reproduction, or that shows only sometimes,
     is not already gone because one run passes: it stays open, with a comment
     that says what the code now does.
   - **The change removes it** — the task's own diff takes out its cause, with
     no code added for it but a bug's test. It closes with the PR.
   - **Rides along** — it passes the four tests in step 4, with *Same module*
     widened to the same area: its fix changes a file in the same module, or a
     file of the screen, window or command the task changes.
   - **Stays open** — none of these. If the change moves the code it cites,
     *Finishing* in `SKILL.md` corrects its text.
4. **Check every other hit.** It rides along only if it passes all four,
   measured against the fix for the issue in hand alone:
   - **Same module** — it changes a file the task already changes, in any
     function, or a file next to them in the same module, as `filing.md`
     draws the module. The same topic in another module is another PR.
   - **Settled** — its body already says what to do; nothing in it waits on a
     decision.
   - **Smaller** — its share of the diff is smaller than that fix.
   - **Separable** — dropping it leaves the task whole, so a reviewer can ask
     for it to be split out and lose nothing but a line in the description.
5. **Total the ones that passed.** While the total is not smaller than that
   fix, drop the largest, one at a time. Past that line the ride-alongs
   outweigh the issue the PR is named for. An issue the change removes does
   not count toward the total: the task's own code fixes it, so it cannot be
   dropped, and a bug's test is required by the global prompt.

Nothing passes: ship the task alone — that is the usual case, not a failure to
look. Every issue the PR closes beside the task — a ride-along, or a bug or
debt the change removes — is a whole issue, not a Boy Scout fix: a bug brings
its own test, and the PR closes it under **Also closes** (*Pull requests* in
`SKILL.md`). Assign it to you as soon as it gets that verdict, as the task is
at take-in, so nobody else takes it while the work runs:

```bash
gh issue edit 15 --add-assignee @me
```

An issue with `## Also:` sections closes only when every problem in it is
fixed: its own problem and each added one. Give a verdict to each problem in
it, not one to the issue. When the change fixes some of them, their tests join
the diff and the issue stays open: the PR says `Part of #15`, and
`keep-open.sh` removes its link to #15 (*Pull requests* in `SKILL.md`).

## After the work

Taking an issue in is the request for the whole flow: the work, the review
and, off the default branch, the pull request and the question whether to
merge. When the work is done, run the repository's own check, such as
`make check`, then invoke the `kalinichenko:review-loop` skill. That skill
runs the check on the final branch and writes a summary. Then, when the check
passes and the branch is not the default branch, it opens the pull request
and asks whether to merge, in the same turn. After the summary, only the
merge and the open questions on business logic wait for the person.
