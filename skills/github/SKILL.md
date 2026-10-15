---
name: github
description: Use when touching a repository's GitHub surface — writing a commit message, running `gh pr create` or merging a pull request, filing or updating an issue, picking an issue up to work on (including a bare `#91` or issue URL as the whole message), checking whether a finding is already filed, or creating or editing a GitHub Actions workflow.
---

# Working with GitHub

Everything here needs `gh` authenticated against a GitHub remote. Where it is
not — `gh auth status` fails, or the remote is elsewhere — skip the step and say
so in the final report rather than inventing a substitute.

| Moment | What must happen |
| --- | --- |
| Writing a commit message | `type: one sentence`, at most 5 bullets under it, no `Co-Authored-By:` |
| `gh pr create` | `--assignee @me`; assign every issue it closes too |
| Merging | `gh pr merge --squash --delete-branch --body` with one bullet list for the whole branch |
| Reading the tracker | `collect.sh` writes it to one file. From 20 KB in Claude Code, a Haiku scout reads the file; otherwise you read it with `scout.md`. You decide and write |
| Finding something out of scope | Small, safe, needs no decision: fix it in this PR, list it in the description. Otherwise add it to an open issue on the same code with `add-finding.sh`, or file a new one |
| Filing next to an existing issue | Name the relation, and correct the other side |
| Picking an issue up — `#91` or its URL | `take-in-check.sh`; close its duplicates; unless told otherwise, `worktree.sh` with `fix/91-what-it-does`; read what it is wired to; re-check its `path:line`; check every open bug and debt issue in the same area first; take along settled issues on the same code |
| Editing a workflow | Pin `uses:` to the latest major; runtime ≥ host |

## Commits

A commit message is a typed subject line, and under it, at most, a short list of
what was done:

```
fix(hooks): make the docs hook read commands, not prose

- Add the newline to the separator class
- Replay two recorded pushes through the hook in tests/hooks_test.sh
```

The subject is `type: sentence` or `type(scope): sentence` — imperative, up to
100 characters, so the whole first sentence fits. The types, and the only ones:

| Type | Use for |
| --- | --- |
| `feat` | a capability the user did not have before |
| `fix` | behaviour that was wrong and is now right |
| `refactor` | a change with no visible behaviour change |
| `docs` | documentation only |
| `test` | tests only |
| `ci` | workflows and pipelines |
| `chore` | anything else: dependencies, tooling, housekeeping |

A change touching several kinds takes the type of the part the reader cares
about; `wip` is not a type and never reaches `main`.

The list, when there is one, comes after a blank line: one to five bullets, one
line each, each naming a thing that was done. The reasoning, the measurements
and the alternatives stay in the PR description. Nothing else goes below the
list.

Commit messages are English, in every repository — see *Code speaks English* in
the global prompt.

Never add a `Co-Authored-By:` trailer: no Claude, no model name, no
`noreply@anthropic.com`.

## Pull requests

Every PR opened with `gh pr create` carries an assignee — always pass
`--assignee @me`, so the authenticated account owns it. An unassigned PR has
nobody's name on it in the list view, which is how review requests get lost.

If the PR closes an issue — `Closes #12`, `Fixes #12` — assign that issue the
same way *before* the PR merges and closes it: `gh issue edit 12 --add-assignee
@me`. Once GitHub closes an issue automatically, nothing goes back to record who
did the work. An issue already assigned to someone else stays theirs: say so,
do not reassign.

The title and description follow the language the project already uses — read
the recent merged PRs and issues before writing, and match them. English is the
default only where there is nothing to match.

Merging is always `gh pr merge --squash --delete-branch`, with `--body` set to
one list in the *Commits* shape — at most five bullets — that sums up every
commit on the branch, not just the first: without it GitHub fills the squash
commit from a repository setting, by default every branch commit's full message
in turn. One commit per PR keeps `main` readable, and the branch has nothing
left to say once it is in. Its subject is the PR title — by default a
one-commit branch gives that commit's subject instead — so both take the same
`type: sentence` shape.

## Scripts

The steps with one correct result are scripts in `scripts/`, next to this
file. Run each one as `bash <dir>/scripts/<name>.sh`, where `<dir>` is this
skill's base directory: a plugin packager can drop the executable bit. They
need only `bash` and `gh`. A script that writes takes `DRY_RUN=1`: it prints
its write commands and runs none.

## Reading the tracker

`collect.sh` reads the tracker into one file, and prints its path and size:

```bash
bash <dir>/scripts/collect.sh take-in 91 bug,debt src/main/lanes.ts spawnLane lane
bash <dir>/scripts/collect.sh filing src/parser.ts verify_target
```

Give it every file and symbol that the issue or the findings name, any you
know the work touches, and the one or two words they use for what the person
sees — `lane`, `error alert`. For take-in, the second argument is the
repository's names for bug and debt in `gh label list`, comma-separated, or
`''`. One run covers every finding you have at that moment.

In Claude Code, a file of 20 KB or more goes to a scout, a small model that
reads it in a context of its own and returns only the candidates. The size
that `collect.sh` prints first decides; the reader adds the bodies it needs
later, and the file often grows to three times that size. Send one `Agent`
call with `model: "haiku"` and this prompt:

```
Read <dir>/scout.md and do what it says.
Job: take-in #91.
File: <the path collect.sh printed>.
Collector: bash <dir>/scripts/collect.sh
```

For findings, the `Job:` line is `Job: filing.`, and under it one line per
finding with its `path:line`.

Read a smaller file yourself, and every file in Codex: it costs less than a
subagent's start and its report. Follow `scout.md` — its *The file*, *Read*,
*Sort* and the entry shape in its *Return* — write its groups and entries as
your notes, and go on with this skill.

The scout only reads. Every close, edit, comment and new issue is yours, and
so is every verdict. Its lists include doubtful candidates on purpose: drop
each one that is wrong, and read in full each issue before you act on it. Its
report replaces your own search of the tracker: for a name it did not get, run
`collect.sh filing <name>` yourself.

An open issue's `status:` is `free`, or it names who works on it: `assigned to
<login>`, `branch <name>`, `PR #<n> by <login>`, with `you` for your own
account. One entry that is not yours makes the issue **someone else's work**.
GitHub does not say whose a linked branch is: it counts as yours when the
issue is assigned to you alone, as `worktree.sh` leaves it.

## Filing an issue

Anything worth fixing that is **not** part of the current task — a bug, a latent
defect, an improvement worth making later — gets filed as an issue instead of
being fixed inline or dropped in the chat. Do not derail the task to fix it; do
not ask first.

**If it is small, safe and needs no decision, it goes into this PR instead** —
the Boy Scout Rule from the global prompt. All three, checked against the diff
you would write, not the feeling: it stays within a few lines, it changes
nothing another caller or user relies on, and there is only one way to do it — a
typo, a stale comment, a dead variable, a wrong `path:line` in a doc, a broken
link. Fix it now, in its own commit if it touches a file the task does not, and
list it in the PR description under **Also fixed** with a line per item, so the
reviewer knows which changes are not the task. An issue for a two-line fix costs
more than the fix. Fails any of the three — a design choice, a behaviour change,
a fix that needs its own test — and it is an issue, however small it looks.

**Search by identifier, not by your title.** A search for the symbol finds
every issue that names it; the prose you were about to write finds only issues
someone happened to phrase your way — and on a tracker written in another
language, nothing at all. Closed counts too: a finding already filed and
rejected does not need filing again. `collect.sh filing` runs these searches;
run it, and read its file, before you file.

**Add to an open issue before you open a new one.** Two issues on one piece of
code become two PRs that edit the same lines, and the tracker grows faster
than it closes. Per finding, the scout's groups decide:

- **Already decided** or **Already filed** — file nothing. If an open issue has
  the same report and the finding adds something — a surface, a reproduction —
  add that as a comment.
- **Fixed before** — a pull request fixed this before, and the finding shows it
  again. File a new issue that starts `Regression of #12`, name the pull
  request that fixed it, and name the commit or the run that shows it again.
  The scout checks **Already decided** first, so a behaviour kept on purpose
  never comes here.
- **Open work** — an open pull request already changes this code. Read it
  before you file: it may fix the finding. If it does not, name it in what you
  file, so its author sees the overlap.
- **A host** — an open issue whose fix changes the same code, or that decides
  something about the same function. It takes the finding only if it is not
  someone else's work (*Reading the tracker*) and holds fewer than two added
  findings, its `also:`. One PR must still close every problem in it. Write the section to a file outside the checkout. It
  starts `## Also: <the problem>`, then says where it is (`path:line`), how it
  shows up, and why it was out of scope here. Then:

  ```bash
  bash <dir>/scripts/add-finding.sh 12 "$section_file" "<a title that names every problem in it>" [label]
  ```

  `[label]` is the finding's label from `gh label list`, if one fits and the
  host does not have it. The script reads `status:` and `also:` again just
  before it writes, so the findings you added in this run count too. It adds
  the section to the end of the body, sets the title, adds the label, and
  leaves a one-line comment, because a body edit notifies nobody. A busy host
  or a full one it refuses, and writes nothing. Run it for one host at a time,
  never two at once: it reads the body and writes it back whole.
- **No free host** — file a new issue:
  - One issue per finding. Title states the problem, body says where it is
    (`path:line`), how it shows up, and why it was out of scope here.
  - Label it from the labels the repository already has — `gh label list`
    first, then `--label` with the ones that fit. Never invent a new label; if
    nothing fits, file it unlabelled.
  - A host that someone works on, or that holds two added findings: write
    `Related to #12` in the new body, and leave a one-line comment on the host
    that names the new issue. Do not edit its body.

List every issue you filed or added to, with its number, in the final report.

## An issue is a document too

*Docs move with the change* applies to the tracker. An issue goes stale the
moment the code moves under it, and GitHub does not notice: it backlinks a
reference automatically, but nothing corrects the text on either side.

**Filing one next to an existing issue.** Name the relation in the body —
`Related to #12`, `Blocks #12`, `Supersedes #12` — and fix the other side in the
same breath: edit its body so the next agent reads something true, and leave a
one-line comment saying what moved and why. GitHub keeps the edit history, so
nothing is lost by correcting the text in place. A duplicate is closed against
the survivor, never left standing as a second opinion. When the other side is
a host that someone works on, or that holds two added findings, it gets the
one-line comment only (*Filing an issue*): its body stays as it is.

**Taking one into work.** An issue named on its own — `#91`, "take #91", its
URL — as the session's first message, or after a talk about which task is next,
is the request to take it into work; a mention inside other work is not. Check
it first: `bash <dir>/scripts/take-in-check.sh 91`, or with its URL. It prints
`take #91`, or each reason why not. Closed, assigned to someone else, or closed
by an open pull request someone else wrote — say so and wait. An issue of
another repository than this checkout's — say so and stop.

**The tracker is read next.** Run `collect.sh take-in` (*Reading the tracker*
above) with the issue's number and the names it gives. While a subagent reads
the file, you can set up the worktree below: the worktree is not the work, so
the duplicates can still close before the work starts. The scout's groups hold
the duplicates, the bugs and debt in the same area, the neighbours, and the
linked issues, open work and history; the rest of this section works from
them. An issue with `## Also:` sections is one task: its own problem and every
added one.

**Its duplicates close first.** A duplicate — the same report, in different
words or not, about the same place — closes against the issue in hand before
the work starts, once anything it adds (a repro, an error message, a surface)
is carried into a comment on the survivor. One that is someone else's work
stays open: say so. A report that gives only what someone saw — no
cause, no code — matches by symptom alone: it waits for the reproduction, run
in the task's worktree, and closes the same way once that shows the same cause;
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
branch" — and then they win.

The branch, and the worktree when one is made, carry one name that says what
the work is: `<type>/<number>-<two to four words>`, the type from *Commits*, in
English — `fix/91-electron-binary-in-lanes`, never `issue-91` or the whole
title.

```bash
bash <dir>/scripts/worktree.sh 91 fix/91-electron-binary-in-lanes
```

It assigns the issue to you, branches from the remote's default branch, links
the branch to the issue, and prints the path to work in as its last line. A branch already linked to
the issue wins over the name you gave. A branch already checked out is worked
on where it is. A session already in a worktree, as one started with `claude
--worktree` or `codex --worktree`, checks the branch out where it is.

Then move into the worktree. Claude Code: `EnterWorktree` with the path it
printed. Codex cannot move a running session: every command takes the worktree
as `workdir`, and every file path, read or patched, is written under it.

Then read what points at it: the scout's **Linked, open work and history**
group. It holds the timeline's cross-references, including the ones the
issue's own body never mentions — the newest 100, and the file says when
there are more — the open PRs that change the same code,
and the closed issues and merged PRs that changed it. An open PR there is work
under way: say so before you start on the same code. Read in full the open
issues, the PRs that touched the same code, and any closed issue whose outcome
the task leans on; the scout's line is enough for the rest.

Then check the issue's own `path:line` citations against the current tree before
believing them — a line number is the first thing to rot — and correct them in
the issue as the first act of the work.

**Taking neighbours along.** Before the first edit, sort the open issues on the
code the task will change. The issue in hand stays the task throughout. A hit
that is someone else's work (*Reading the tracker*) gets no verdict below and
stays as it is. Say so.

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
   - **Rides along** — it passes the four tests in step 4, with *Same file*
     widened to the same area: its fix changes a file of the screen, window or
     command the task changes.
   - **Stays open** — none of these. If the change moves the code it cites,
     *Finishing* corrects its text.
4. **Check every other hit.** It rides along only if it passes all four,
   measured against the fix for the issue in hand alone:
   - **Same file** — it changes a file the task already changes, in any
     function. The same topic in another file is another PR.
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
its own test, it is assigned like the task, and the PR description closes it
under **Also closes**, one line per issue with its own keyword — `Closes #15` —
because GitHub closes only the numbers a keyword precedes.

An issue with `## Also:` sections closes only when every problem in it is
fixed: its own problem and each added one. Give a verdict to each problem in
it, not one to the issue. When the change fixes some of them, their tests join
the diff, the issue stays open, and the PR description says `Part of #15`
instead of `Closes #15`.

**Finishing.** The PR closes it, every ride-along and every issue the change
removes; under each problem it fixed in an issue that stays open, it adds the
line `Done in #<PR>.`; a duplicate still held for the reproduction is closed or
commented on; and the same pass updates every sibling issue whose text the
change just falsified.

Measured on a live tracker: of the 100 newest issues, 4 bodies had ever been
edited; 5 open issues still cited a file the schema migration had deleted; one
pointed 23 lines away from the code it described, at a closing brace. Every one
of them was correctly cross-linked — the graph was never the problem.

## GitHub Actions

When creating or editing CI workflows, in any project:

1. **Pin every `uses:` to the latest available major.** Don't trust memory —
   verify against the GitHub API:
   `gh api repos/<owner>/<repo>/releases/latest --jq .tag_name`, and confirm the
   floating major tag exists:
   `gh api repos/<owner>/<repo>/git/matching-refs/tags/v --jq '[.[].ref|sub("refs/tags/";"")]|map(select(test("^v[0-9]+$")))'`.
   Pin to the floating major (e.g. `actions/checkout@v7`), not an exact patch.

2. **Never pin a CI language runtime below the host dev machine.** The CI
   version must be **>= the version installed on the current machine** (e.g.
   `node --version`, `bun --version`). Match the host major by default; never go
   lower. Re-check whenever touching workflow runtime versions.

Apply both whenever adding or reviewing CI, even if not explicitly asked.
