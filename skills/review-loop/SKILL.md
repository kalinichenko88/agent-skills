---
name: review-loop
description: Use when a change is reviewed, before or after its pull request opens — running /code-review or /security-review in Claude Code or /review in Codex, sending a review subagent, choosing a review level, deciding whether another round is needed, or handling the findings a review or a person's review comments return. Also at the builder check of superpowers:brainstorming and after the self-review of superpowers:writing-plans.
---

# Review loop

A review runs in rounds. An over-engineering review comes first, when its
skill is installed. The first round reads the whole branch. Each later round
reads only the fixes of the round before. The loop stops at the first round
that confirms no defect, and at the latest after round 3. A defect is a wrong
result that real use reaches, or data loss or a security hole on any input,
also in a fix of the loop; a test, a comment or wording is a nit, fixed with
no round. A finding that needs a particular input is counted against real
data first, and a count of zero declines it, except for data loss or a
security hole. When the loop had more than one round, one last pass
reads the whole branch again, once. At `xhigh` in Claude Code, Codex reads the
whole branch once too. At `high` and `xhigh`, and for a change to tests only,
one review reads the tests of the whole branch once. In a project with an
architecture file or ADRs, one review reads the branch against them once,
beside round 1, at `high` and `xhigh` and for a change to that file or an
ADR. A security review comes
last. A change to documents only gets one round and no security review. In
Claude Code, Codex reads it once when it changes the text of a skill, a
prompt or a spec. The agent fixes and decides by itself, except for a change
to business logic, and writes a
summary. When the task is an issue taken into work, or the person asked for a
pull request, the push and the pull request follow in the same turn, on the
conditions in *The pull request*.

Why the rounds stop: on one project, nine rounds of `/code-review high`, each
over the whole branch, gave 68 findings and 25 fixes. No fix went into the
product code. One declined alternative came back in eight of the nine rounds.
On 42 merged pull requests of this plugin, the rounds after round 1 confirmed
24 defects that normal use reaches and 44 in the fixes of their own loop,
against 237 edge cases that real use does not produce, tests and wording. In
the six of them where the person said to go on after round 3, no later run
found a defect that normal use reaches.

## The level

Pick the level of `/code-review` by the weight of the change, and give the
reason in one sentence: "Why high: it changes the token refresh, which every
request goes through."

| Level | The change |
| --- | --- |
| `low` | Wording in code, or a fix in one file that adds no logic, when no test file changes. |
| `medium` | A change to tests only, or a fix in one file that adds no logic, with its tests; UI over static data with no new state rules; a move that a script or a test proves unchanged. |
| `high` | New state rules or reducer logic, a new page, route or endpoint, and any change the other rows do not name. |
| `xhigh` | Security, data loss, concurrency, or architecture across modules or apps. |

`medium` is not a default: each level needs its own reason. `max` and `ultra`
run only when the person asks; `ultra` is billed. A change to a test file is
never `low`: `/code-review low` skips test files.

A change to documents only takes no `/code-review`: one review subagent reads
the text the range changes against the code it describes, the rest of its
document, and the other documents that describe the same thing. It gets one
round, as *A change to documents only* says. The text of a skill or a prompt,
as a `SKILL.md` or `rules.md`, counts as a document, though it is the product.
Why: on a skill's own branch, eight runs of `/code-review high` found 9 or 10
findings each. From the second run on, most were in the sentences the run
before had written. The rounds stopped only when the person stopped them.

When that text comes with code, each range of the rounds and the last pass
goes to one review or to both, by what it changes. The code review,
`/code-review` at the level of the code alone or `/review` in Codex, reads
each range that changes anything but that text. The agent does not act on
its findings in that text, and does not count them. The subagent reads each
range that changes that text, or code that the text names, as a script or a
flag. It reviews the text the range changes and the text that names the code
it changes, as for a change to documents only. A round confirms no defect
when neither review does. Other documents next to code stay with the code
review, with no subagent.

A review subagent and Codex's `/review` have no levels.

## Over-engineering first

When the ponytail plugin's `ponytail-review` skill is in your skill list,
commit the work and run it once on the whole branch, before the first round.
It lists what to delete, replace with the standard library or shorten, and
changes nothing. Its findings go through *The findings*, and its cuts are one
commit, so the first round reads the shorter code. Its list does not end the
turn: go on to the first round. Skip it for documents only, and for a move
that a script or a test proves unchanged. When the skill is not
installed, skip it and say so in the summary.

## The rounds

1. **Commit the work.** The first round reads the whole branch:
   `/code-review <level> <base>..HEAD`, where `<base>` is
   `git merge-base origin/<default branch> HEAD`, or
   `git merge-base <default branch> HEAD` where there is no `origin`. Name the
   range: with no target, `/code-review` reads only the commits ahead of the
   upstream, and after a push that is not the whole branch. In Codex:
   `/review`, *Review against a base branch*. A review subagent gets
   `git diff <base>..HEAD`.
2. **The fixes of a round are one commit.** The next round reads only that
   commit: `/code-review <level> <sha>^..<sha>`. In Codex: `/review`, *Review a
   commit*. A review subagent gets `git show <sha>`. Inside the loop, never
   send the whole branch again.
3. **Stop at the first round that confirms no defect**, whatever that round
   declines, for the first time or again. A round whose report says it read
   no file of its range confirms nothing and does not count. When its level
   skipped the files, run that range again one level up, in its place.
   Otherwise correct the range, and run it again. A defect is a confirmed
   finding of one of two kinds:
   - a wrong result, a crash or a broken contract, on an input or a state
     that the project's real use reaches;
   - data loss or a security hole, on any input.

   Both kinds hold in the code that a fix of this loop wrote too: most of
   the defects that later rounds find are there.
   In the text of a skill or a prompt, a defect is a rule that, followed as
   written, gives a wrong result in a case that real use reaches. Every other
   confirmed finding is a nit: a missing or redundant test, a comment, a
   name, wording, line wrapping. A nit starts no round. The nits of a round
   with a defect join its fix commit. The nits of a round with no defect are
   one commit, and no round reads it.
4. **The third round still confirms a defect:** stop the rounds, and skip
   what is left of step 5. Then go to the security review, or to the summary
   when the security review has already run. The summary names the findings
   of round 3. When the person asks for more rounds, up to three more run,
   and this step stops them at the third.
5. **The last pass reads the whole branch once**, as in step 1, at the same
   level, when the loop had more than one round. A round on one commit cannot
   see how a fix fits the rest of the branch; this pass can. It waits for the
   answers to open questions, unless nobody can answer. There is never a
   second whole-branch pass: the rounds that reread the whole branch are the
   ones that did not stop.

### A review of the architecture

This step needs an architecture file or an ADR folder on the branch, where
`kalinichenko:architecture` finds them: `docs/ARCHITECTURE.md` or
`ARCHITECTURE.md` at the root, and `docs/adr/`, `doc/adr/` or
`docs/decisions/`. Then one review subagent reads the range of round 1 once,
beside round 1: at `high` or `xhigh`, and for any change whose range touches
the architecture file or an ADR, also a change to documents only. When the
text of a skill or a prompt comes with code, use the level of the code alone.
Skip it for a move that a script or a test proves unchanged, unless the range
touches the architecture file or an ADR. Start it in the background when
round 1 starts, and change no file while it runs. Its findings go through
*The findings* as findings of round 1: round 1 confirms no defect when
neither review does, and their fixes are one commit. A fix of its finding
that changes code is the fix of a defect: a round reads it, as step 2 says.
On a change to documents only, that round is `/code-review` at the level of
that code.

The subagent is an `Agent` call of its own, not a job in the prompt of round
1, with `model: "opus"`, and `effort` at the level of round 1, or `high` when
that level is lower or there is none. `<dir>` is this skill's base
directory, `<base>` is the base of step 1, and `<head>` is the SHA of `HEAD`
that round 1 reads. It gets this prompt, with no other job:

```
Read <dir>/architecture-lens.md and do what it says.
Range: <base>..<head>
Tree: <the working tree of the branch>
```

In Codex: `/review` with the same three lines as its custom instructions.

With no architecture file and no ADR folder, the step does not run. Then the
summary says once per pull request that `kalinichenko:architecture` can
write the first file, unless the project's `CLAUDE.md` says "This project
keeps no `docs/ARCHITECTURE.md`."

Why: `/code-review` reads the diff and the `CLAUDE.md` files, and none of its
angles reads the architecture file or the ADRs. Why `opus`: the step runs at
each `high` review there, and `fable` costs 2.5 times as much.

### A second model for `xhigh` changes

At `xhigh` in Claude Code, Codex reads the whole branch once. Start
it in the background when the last pass starts. When the loop had one round,
start it when that round confirms no defect and its nits are committed. When
step 4 skips the last pass, skip this step too. Change no file while Codex
runs.

```bash
bash <dir>/scripts/codex-review.sh <base>
```

`<dir>` is this skill's base directory, and `<base>` is the base of step 1.
Run it from the working tree of the branch under review. The script prints
Codex's findings as JSON. Each one goes through *The findings*, also one in
the text of a skill or a prompt.

- Exit 2: the script did not run Codex. When the call is wrong, as a wrong
  base, working directory or argument, correct it and run the script again.
  Otherwise, go on without Codex.
- `skipped:`: the Codex CLI is not installed or not logged in. Go on without
  Codex.
- Any other error: the run failed, as when Codex fails or writes no findings
  file. Go on without Codex.

When you go on without Codex, give the reason in the summary.

Why: on three branches of this plugin that a `/code-review` loop had
finished, Codex found three defects that no round had reported, in 45 to 74
seconds each.

### A review of the tests

This step depends on the level of the change in the table of *The level*.
When the text of a skill or a prompt comes with code, use the level of the
code alone. At `high` or `xhigh`, and for a change to tests only, one review
subagent, or `/review` in Codex, reads the tests of the whole branch once. A
change to documents only gets no review of the tests. Start it when the last
pass starts. When the loop had one round, start it when that round confirms
no defect and its nits are committed. When step 4 skips the last pass, skip
this step too. Change no file while it runs.
`<dir>` is this skill's base directory, `<base>` is the base of step 1, and
`<head>` is the SHA of `HEAD`. Its findings go through *The findings*. The
subagent gets this prompt:

```
Read <dir>/tests-lens.md and do what it says.
Range: <base>..<head>
Tree: <the working tree of the branch>
```

In Codex: `/review` with the same three lines as its custom instructions.

Why: on nine merged pull requests of three projects, each with a finished
`/code-review` loop, this review found 11 defects in tests that the loop had
not reported, in seven of the nine. Of the 11, six were redundant or heavy
tests. Of the same 11, five came from a fix after round 1: that fix added a
test or changed the code, and an older test stayed, redundant or stale. So
the review reads the branch at the end of the loop, not beside round 1.
Another review, of the change against its issue, found nothing new on the
same nine, so the skill does not run it.

### Fixes from other places

Each of these starts a new count of rounds: the last pass, the Codex review,
the review of the tests, the security review, and each set of a person's
review comments, before or after the pull request opens. When more than one
of the last pass, the Codex review and the review of the tests find defects,
their fixes are one commit. A count of rounds here does not start the Codex
review or the review of the tests again. For each of them:

- Its fixes are one commit. When they fix a defect, as step 3 says, that
  commit goes through steps 2 to 4. A commit of nits only gets no round.
- Its rounds run at the level that the loop's round 1 used. In a new session,
  take that level from the pull request's `## Review`. A fix to security code
  runs at `xhigh`, whatever found it.

The fix for an answer to a question joins the next fix commit. When no rounds
are running, it starts a new count, as above. A person's review comments go
through *The findings* below, and the reply names the fix commit.

A change to documents only has no such rounds, unless the person asks for
more: see the next section.

## A change to documents only

A change to documents only, as *The level* says, gets one round:

1. **One round.** The review subagent reads the whole branch, as step 1 of
   *The rounds* says. When the range touches the architecture file or an
   ADR, the review of the architecture runs beside it. The fixes of their
   confirmed findings and their nits are one commit. No round reads that
   commit, except as *A review of the architecture* says, and no last pass
   follows.
2. **One read by Codex**, when the branch changes the text of a skill or a
   prompt, or a spec: the design document that `superpowers:brainstorming`
   writes, as `docs/superpowers/specs/*.md`. In Claude Code, run it once,
   when the rounds end, so Codex reads their fixes in place: after round 1
   and its fix commit, when there is one. When the person asked for more
   rounds before then, run it after the last of them. A Codex read that has
   run does not run again:

   ```bash
   bash <dir>/scripts/codex-review.sh --docs <base>
   ```

   `<dir>`, `<base>`, where it runs and its exits are as in *A second model
   for `xhigh` changes*. Change no file while it runs. Its findings go
   through *The findings*. Its fixes are one commit, and no round reads it.
   Other documents, as a README or a note in `docs/`, get no Codex read. In
   Codex, there is no Codex read.
3. **No security review.** The prompt of `/security-review` says: "Do not
   report any findings in documentation files such as markdown files."
4. **A person's review comments** go through *The findings*. Their fixes are
   one commit, and no round reads it.

When the person asks for more, as more rounds, a last pass or a security
review, that step and the rounds on its fixes run as the other sections say.

Why: on eight branches of this plugin that changed only Markdown, the rounds
ran 60 reviews, seven a branch at the median. From the second round on, most
findings were in the sentences that the round before had written.
`/security-review` found nothing on all eight. A second read of the whole
branch, after the fixes, found 1 to 5 defects on each of the five branches
where it ran. Codex with `--docs`, run after round 1 on three of them, found
a real defect on two, in 53 to 204 seconds.

## The findings

1. **Verify each finding before acting on it.** Reproduce it against the real
   code or in a browser. Reviewers report findings that are wrong, stale, or
   right for the wrong reason, and a confident wrong fix is worse than the
   defect. A finding that does not survive is declined, with the reason.

   A finding that fails only on a particular input or state needs a count
   too: how many of a sample of the real source carry that shape, as *The
   input comes from the source, not from your head* in the global prompt
   says. A count of zero declines the finding in the same round. Give the
   count as its reason on the summary's **Declined** line, so that
   `## Review` carries it to later reviews and sessions. A zero
   count does not decline a finding of data loss or a security hole: an
   attacker can make the input, and the test of its fix uses the input of
   the finding. With no real source to sample, the count declines nothing.
2. **Fix every obvious one now, without asking:** real bugs, dead code,
   accessibility and contrast failures, code that contradicts its own
   documentation, wrong numbers in documents.
3. **Decide every other one yourself:** a trade-off, a name, a structure, the
   look of a screen. Take the choice that fits the code around it, and write
   down the reason for the summary.
4. **Ask only about a change to business logic:** what the product does for
   its users — a rule, a calculation, a state, a permission, the data it keeps
   or deletes. Give the options and a recommendation, and keep the rest of the
   round going while the person answers. When nobody can answer, as in a run
   with no person, the question stays open in the summary.
5. **Fix at the root.** When the same defect is in sibling call sites or in a
   shared token, fix it there, and count the places.
6. **A finding outside the task is an issue**, through the
   `kalinichenko:github` skill, unless the Boy Scout Rule takes it into this
   change.

## The security review

After the last pass, the Codex review, the review of the tests and their
rounds, `/security-review` runs once, on the final branch. It reads the branch
against origin's default branch and takes no target, so it never runs inside
the loop. A change to documents only gets none, unless the person asks for
it. Its findings go through *The findings*, and its fixes through
*Fixes from other places*. In Codex: `/review` with the custom instructions
"Find security defects on this branch against origin/<default branch>:
injection, authentication, authorization, secrets and data exposure." Where
there is no `origin` remote, say so in the summary.

In Claude Code, send one `general-purpose` subagent with no `model`, with
this prompt, and do not run `/security-review` in the session:

```
Run /security-review with the Skill tool, and return its report. Change no file.
```

After its report and the rounds on its findings, go on to *The summary*, then
to *The pull request* when the conditions of that section hold.

Why a subagent: the prompt of `/security-review` ends "Your final reply must
contain the markdown report and nothing else." Run in the session, the agent
ended its turn on the report, with no push and no pull request: on #61, and
twice on #167, after a sentence against it was added here. In a subagent, that
line holds for the subagent's reply.

## The summary

When the review ends, run the repository's own check on the final branch.
Then report in this order. Each item is one line, except **Change:**, which
is a list:

- **Change:** what the branch changed as a whole, for a person who did not
  follow the session: one to five bullets, the list that the merge takes as
  `--body` in *Pull requests* of the `kalinichenko:github` skill.
- **Rounds:** `ponytail-review`'s lines saved, or why it did not run. Each
  round, its level and range, and the count of findings it confirmed. The
  last pass, the same way. At `xhigh`, the Codex review: its range and the
  count of findings it confirmed, or why it did not run. At `high` and
  `xhigh`, and for a change to tests only, the review of the tests, the same
  way. The review of the architecture, the same way. With no architecture
  file and no ADR folder, once per pull request, the line that
  `kalinichenko:architecture` can write the first file, unless the project
  keeps none. The security review's
  result. The check's result. For a change to documents only: round 1; the
  review of the architecture, when it ran; the Codex read and the count of
  findings it confirmed, or why it did not run;
  and `documents only` for each of the last pass and the security review that
  did not run.
- **Decisions:** each choice you made: the finding, the choice, the reason.
  Each question on business logic, with the person's answer, or `open`.
- **Fixed:** what changed and in which file, the commit, and any side effect
  a fix had elsewhere.
- **Declined:** each finding that did not survive, with the reason.
- **Filed:** the issues opened or added to, with their numbers.
- **Docs:** the docs the branch changed, or `docs impact: none` and why, as
  *Docs move with the change* in the global prompt asks.

The pull request description carries the same summary under `## Review`, and
each later fix commit adds its lines there. A later review then recognises a
declined finding instead of arguing it again.

In a public repository, the `## Review` section and each reply to a review
comment are public. An example from a private source goes in without its
names, numbers, titles, paths or code: *Public repositories* in the
`kalinichenko:github` skill says what a private source is and what to write
instead.

## The pull request

Go on in the same turn when all of these hold:

- The task is an issue taken into work, or the person asked for a pull request.
- The branch is not the default branch.
- The check on the final branch passes.

Then:

1. Push the branch. When the push succeeds and the branch has an open pull
   request, add the summary's lines to its `## Review`. When the push
   succeeds and the branch has none, open the pull request through the
   `kalinichenko:github` skill, with the summary under `## Review`.
2. When questions on business logic are still open, ask them. An answer that
   needs no fix goes into `## Review`. The fix for an answer, when it needs
   one, goes through *Fixes from other places* and *The summary*, and then
   through this section again, its conditions first.
3. When the last push in step 1 succeeded, the pull request is open and no
   question on business logic is open, show the `gh pr merge` command that
   *Pull requests* in that skill gives. Ask one question with three answers:
   merge and clean up, merge only, or do not merge. When
   `git for-each-ref --format='%(worktreepath)' refs/heads/<branch>` prints
   nothing or the first path of `git worktree list`, the branch has no linked
   worktree, and `gh` deletes the local branch itself: ask only whether to
   merge, and do no *Cleanup*. On a merge answer, run the merge in
   the checkout that holds the branch, as that section says. When it
   succeeds, do *Finishing* from that skill, and on merge and clean up, its
   *Cleanup* after that. When it fails, give the error, and keep the worktree
   and the branch.

Only the merge and the open questions on business logic wait for the person.

## A spec and a plan

In Claude Code, the global prompt sends you here at two checks of
superpowers. They are not a review of a change, and the rounds above do not
run on them. In Codex this section does not apply, and the two checks run as
superpowers sets them: Codex has no Fable, and it does not call itself.

**The spec.** `superpowers:brainstorming` sends one subagent with its
`builder-check-prompt.md` when the written design exists. Send two readers
instead, in one message, with the same prompt: an `Agent` call with
`model: "fable"`, and Codex in the background, from the root of the
repository:

```bash
codex exec -s read-only --ephemeral - <<'EOF'
<the prompt, filled in>
You are one reviewer that another agent runs: start no skill, change no file, and file nothing.
EOF
```

The last line is there because Codex loads the global prompt too. When there
is no `codex` command, `codex login status` fails, or the run fails, as in a
folder that Codex does not trust, go on with Fable alone, and say so when you
hand over the document. Put the questions from both readers into the three
piles of brainstorming.

**The plan.** `superpowers:writing-plans` checks the plan against the spec
itself. After that check, send one `general-purpose` subagent with no
`model`. It reads the spec and the plan, and returns each spec requirement
with no task, each task that contradicts the spec, and each value that
differs from the spec, with the spec line and the plan line, or "none". Fix
the plan before the handoff.
