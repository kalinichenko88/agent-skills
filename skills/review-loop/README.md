# kalinichenko:review-loop

A review that ends: rounds that read only the last fixes, a stop at the first
clean round, one last pass over the whole branch when the loop needed more
than one round, Codex as a second reviewer for `xhigh` changes in Claude Code,
a review of the tests for `high` and `xhigh` changes, a review against the
project's architecture file and ADRs beside round 1, a security review last,
and a summary of what the branch changed and what was decided and fixed. A
change to documents only gets one round and no security review. In Claude
Code, Fable and Codex also read a
superpowers spec, and one more subagent checks its plan against it.

## When it starts

- `rules.md` starts it before the first review of a change: `/code-review` or
  `/security-review` in Claude Code, `/review` in Codex, or a review subagent.
- A person's review comments arrive.
- You choose a review level, or decide whether another round is needed.
- In Claude Code, `rules.md` starts it in place of the builder check of
  superpowers' `brainstorming`, and after the self-review of `writing-plans`.

With superpowers installed, it replaces `requesting-code-review` and
`receiving-code-review`. In `subagent-driven-development`, the review after
each task stays as that skill sets it. In place of the final review of
`subagent-driven-development`, this skill starts after the last task.

## What you get

- **Less code first.** When the
  [ponytail](https://github.com/DietrichGebert/ponytail) plugin is installed,
  its `ponytail-review` runs once before the first round, and its cuts are one
  commit. Without ponytail the step is skipped, and the summary says so.
- **A level with a reason.** `low` to `xhigh` by the weight of the change, and
  one sentence that says why. `ultra` only when you ask for it. A change to a
  test file is never `low`: `/code-review low` skips test files. A change to
  documents only, the text of a skill or a prompt included, gets one review
  subagent in place of `/code-review`. When a skill's or a prompt's text comes
  with code, `/code-review` takes the level of the code, and the subagent
  reviews the text.
- **Rounds that read less.** The first round reads the whole branch. Each round
  of fixes is one commit, and the next round reads only that commit.
- **A stop.** The loop ends at the first round that confirms no defect. A
  round that read no file of its range does not count: it runs again, one
  level up when its level skipped the files. A defect is a wrong result, a
  crash or a broken contract that real use reaches, or data loss or a
  security hole on any input, also in the fixes of the loop. A test, a
  comment, a name or wording is a nit, applied without another round. A
  finding that needs a particular input is counted first in a sample of real
  data: a count of zero declines it, unless it is data loss or a security
  hole. After the third round with a defect, the rounds stop. Ask for more,
  and up to three more run.
- **One round for documents.** A change to documents only gets one round of
  the review subagent, and no round reads its fixes. In Claude Code, Codex
  then reads the whole branch once, with the fixes in place, when the branch
  changes the text of a skill or a prompt, or a superpowers spec. No last
  pass runs, and no `/security-review`: its prompt excludes Markdown. The
  fixes for your review comments are one commit, with no round. Ask for more
  rounds, a last pass or a security review, and they run, with rounds on
  their fixes.
- **One last look at the whole branch.** When the loop needed more than one
  round, one pass reads the whole branch again after it stops, to see how the
  fixes fit the rest. It never runs twice.
- **A second model for `xhigh` changes.** In Claude Code, Codex reads the
  whole branch once: beside the last pass, or after round 1 when the loop
  needed only one round. Its findings go through the same checks. Without the
  Codex CLI or its login, or when Codex fails, the step is skipped, and the
  summary says so.
- **A review of the tests.** For `high` and `xhigh` changes, and a change to
  tests only, one review subagent, or `/review` in Codex, reads the tests of
  the whole branch once:
  beside the last pass, or after round 1 when the loop needed only one round.
  It finds a test missing where a defect can hide, a test that passes with
  its code deleted, a test that the change left stale, a test that repeats
  another, and brittle or heavy tests. It runs at the end because the fixes of
  later rounds add tests too, and an older test then often repeats a newer
  one. When the rounds stop after the third round with a defect, the last
  pass and this review are both skipped.
- **A review of the architecture.** In a project with `docs/ARCHITECTURE.md`
  or ADRs, one Opus subagent, or `/review` in Codex, reads the branch against
  them once, beside round 1: for `high` and `xhigh` changes, and for any
  change to that file or an ADR. It runs `invariants.sh --new-since` of
  `kalinichenko:architecture` and `clones.sh` of `kalinichenko:debt`. It finds
  a second structure beside an existing one, a module used past its public
  API, a broken invariant cited as `I-n`, a decision with no ADR or against
  one, a passage of the architecture file that the change made false, a file
  grown past its limit, and a copy to extract. Its fixes join those of
  round 1. With no such file, the summary says once that
  `kalinichenko:architecture` can write the first one, unless the project
  keeps none.
- **Later fixes are reviewed too.** The fixes from the last pass, the Codex
  review and the review of the tests are one commit. The fixes from the
  security review are one commit, and so are those from each set of your
  review comments, also after the pull request opens. Each of these commits
  that fixes a defect has rounds of its own: at the level of the loop's round 1, or `xhigh` for a
  fix to security code. On a change to documents only, a commit gets rounds
  only when you ask for rounds, or for the step that made it.
- **Fewer questions.** The agent fixes the obvious findings and decides the
  rest by itself. It asks only about a change to business logic: a rule, a
  calculation, a state, a permission, the data the product keeps or deletes.
- **A security review last.** `/security-review` runs once on the final
  branch. Its fixes get rounds of their own, as the later fixes above. A
  change to documents only gets no security review, unless you ask for one.
- **A summary.** First a run of the repository's check on the final branch.
  Then what the branch changed as a whole, in one to five bullets. Then the
  rounds, the decisions with their reasons, what was fixed, what was declined
  and why, and the issues filed. Last, the docs the branch changed, or why it
  changed none. The pull request description carries the summary under
  `## Review`. In a public repository, an example from a private source in
  that section or in a reply to a review comment keeps no names, numbers,
  titles, paths or code.
- **Then the pull request.** For an issue taken into work, or when you ask
  for a pull request, the agent opens it after the summary, in the same turn.
  It asks one question: merge and clean up, merge only, or do not merge.
  Clean up removes the worktree and the local branch after the merge, when
  nothing in them would be lost. This needs a passing check and a branch
  other than the default branch. Only the merge and the open questions on
  business logic wait for you.
- **Two readers of a spec, one of a plan.** In Claude Code, the builder check
  of a superpowers spec goes to Fable and Codex in parallel, in place of one
  subagent. Without the Codex CLI or its login, or when Codex fails, Fable
  reads it alone, and the agent says so. After the self-review of the plan,
  one more subagent checks the plan against the spec: a requirement with no
  task, a task that contradicts the spec, or a value that differs from it.

## The ponytail step

ponytail is optional. Install it for the over-engineering review:

```sh
claude plugin marketplace add DietrichGebert/ponytail
claude plugin install ponytail@ponytail
```

Codex:

```sh
codex plugin marketplace add DietrichGebert/ponytail
codex plugin add ponytail@ponytail
```

It is not a dependency of this plugin. Codex plugins cannot declare one. In
Claude Code a dependency would also turn on ponytail's always-on mode, a hook
that needs `node`, for everyone who installs `kalinichenko`.

## The Codex step

The Codex step needs the Codex CLI, logged in:

```sh
npm install -g @openai/codex
codex login
```

It runs `codex exec` in Codex's read-only sandbox, with your Codex config: your
model and reasoning effort apply. It does not need OpenAI's
`codex@openai-codex` plugin for Claude Code: the agent cannot call that
plugin's review commands. You can still run its `/codex:adversarial-review`
yourself.
