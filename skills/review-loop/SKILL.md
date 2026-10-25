---
name: review-loop
description: Use when a change is reviewed, before or after its pull request opens — running /code-review or /security-review in Claude Code or /review in Codex, sending a review subagent, choosing a review level, deciding whether another round is needed, or handling the findings a review or a person's review comments return.
---

# Review loop

A review runs in rounds. An over-engineering review comes first, when its
skill is installed. The first round reads the whole branch. Each later round
reads only the fixes of the round before. The loop stops at the first round
that confirms no defect. When the loop had more than one round, one last pass
reads the whole branch again, once. A security review comes last. The agent
fixes and decides by itself, except for a change to business logic, and
writes a summary. When the task is an issue taken into work, or the person
asked for a pull request, the push and the pull request follow in the same
turn, on the conditions in *The pull request*.

Why the rounds stop: on one project, nine rounds of `/code-review high`, each
over the whole branch, gave 68 findings and 25 fixes. No fix went into the
product code. One declined alternative came back in eight of the nine rounds.

## The level

Pick the level of `/code-review` by the weight of the change, and give the
reason in one sentence: "Why high: it changes the token refresh, which every
request goes through."

| Level | The change |
| --- | --- |
| `low` | Wording in code, or a fix in one file that adds no logic. |
| `medium` | UI over static data with no new state rules; a move that a script or a test proves unchanged. |
| `high` | New state rules or reducer logic, a new page, route or endpoint, and any change the other rows do not name. |
| `xhigh` | Security, data loss, concurrency, or architecture across modules or apps. |

`medium` is not a default: each level needs its own reason. `max` and `ultra`
run only when the person asks; `ultra` is billed.

A change to documents only takes no `/code-review`: one review subagent reads
the documents against the code they describe, the rest of their own text, and
the other documents that describe the same thing, and the rounds below apply
to it. The text of a
skill or a prompt, as a `SKILL.md` or `rules.md`, counts as a document,
though it is the product. Why: on a skill's own branch, eight runs of
`/code-review high` found 9 or 10 findings each. From the second run on, most
were in the sentences the run before had written. The rounds stopped only at
the ask in step 4.

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
commit, so the first round reads the shorter code. Skip it for documents only,
and for a move that a script or a test proves unchanged. When the skill is not
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
   declines, for the first time or again. Apply its nits — wording, line
   wrapping — without another round.
4. **The third round still confirms a defect:** stop, and ask the person
   whether to go on. Give the findings of the three rounds. When the person
   says to go on, ask again after three more rounds. When the person says to
   stop, or nobody can answer, end these rounds and skip what is left of
   step 5. Then go to the security review, or to the summary when the
   security review has already run.
5. **The last pass reads the whole branch once**, as in step 1, at the same
   level, when the loop had more than one round. A round on one commit cannot
   see how a fix fits the rest of the branch; this pass can. It waits for the
   answers to open questions, unless nobody can answer. There is never a
   second whole-branch pass: the rounds that reread the whole branch are the
   ones that did not stop.

### Fixes from other places

Each of these starts a new count of rounds: the last pass, the security
review, and each set of a person's review comments, before or after the pull
request opens. For each of them:

- Its fixes are one commit, and that commit goes through steps 2 to 4.
- Its rounds run at the level that the loop's round 1 used. In a new session,
  take that level from the pull request's `## Review`. A fix to security code
  runs at `xhigh`, whatever found it.

The fix for an answer to a question joins the next fix commit. When no rounds
are running, it starts a new count, as above. A person's review comments go
through *The findings* below, and the reply names the fix commit.

## The findings

1. **Verify each finding before acting on it.** Reproduce it against the real
   code or in a browser. Reviewers report findings that are wrong, stale, or
   right for the wrong reason, and a confident wrong fix is worse than the
   defect. A finding that does not survive is declined, with the reason.
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

After the last pass and its rounds, run `/security-review` once, on the final
branch. It reads the branch against origin's default branch and takes no
target, so it never runs inside the loop. Its findings go through *The
findings*, and its fixes through *Fixes from other places*. In
Codex: `/review` with the custom instructions "Find security defects on this
branch against origin/<default branch>: injection, authentication,
authorization, secrets and data exposure." Where there is no `origin` remote,
say so in the summary.

The report of `/security-review` does not end the turn, even when its prompt
says the final reply is the report alone. After the findings of
`/security-review` and their rounds, go on to *The summary*, then to *The pull
request* when the conditions of that section hold.

## The summary

When the review ends, run the repository's own check on the final branch.
Then report in this order, one line per item:

- **Rounds:** `ponytail-review`'s lines saved, or why it did not run. Each
  round, its level and range, and the count of findings it confirmed. The
  last pass, the same way. The security review's result. The check's result.
- **Decisions:** each choice you made: the finding, the choice, the reason.
  Each question on business logic, with the person's answer, or `open`.
- **Fixed:** what changed and in which file, the commit, and any side effect
  a fix had elsewhere.
- **Declined:** each finding that did not survive, with the reason.
- **Filed:** the issues opened or added to, with their numbers.

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
   *Pull requests* in that skill gives, and ask whether to run it. On a yes,
   run the merge, then do *Finishing* from that skill.

Only the merge and the open questions on business logic wait for the person.
