# kalinichenko:review-loop

A review that ends: rounds that read only the last fixes, a stop at the first
clean round, one last pass over the whole branch when the loop needed more
than one round, a security review last, and a summary of what was decided and
fixed.

## When it starts

- `rules.md` starts it before the first review of a change: `/code-review` or
  `/security-review` in Claude Code, `/review` in Codex, or a review subagent.
- A person's review comments arrive.
- You choose a review level, or decide whether another round is needed.

## What you get

- **Less code first.** When the
  [ponytail](https://github.com/DietrichGebert/ponytail) plugin is installed,
  its `ponytail-review` runs once before the first round, and its cuts are one
  commit. Without ponytail the step is skipped, and the summary says so.
- **A level with a reason.** `low` to `xhigh` by the weight of the change, and
  one sentence that says why. `ultra` only when you ask for it. A change to
  documents only, the text of a skill or a prompt included, gets one review
  subagent in place of `/code-review`. When a skill's or a prompt's text comes
  with code, `/code-review` takes the level of the code, and the subagent
  reviews the text.
- **Rounds that read less.** The first round reads the whole branch. Each round
  of fixes is one commit, and the next round reads only that commit.
- **A stop.** The loop ends at the first round that confirms no defect. Nits
  are applied without another round. After the third round with a defect, the
  agent asks you, and again after every three more rounds.
- **One last look at the whole branch.** When the loop needed more than one
  round, one pass reads the whole branch again after it stops, to see how the
  fixes fit the rest. It never runs twice.
- **Later fixes are reviewed too.** The fixes from the last pass, the security
  review or your review comments, also after the pull request opens, are one
  commit with rounds of its own: at the level of the loop's round 1, or
  `xhigh` for a fix to security code.
- **Fewer questions.** The agent fixes the obvious findings and decides the
  rest by itself. It asks only about a change to business logic: a rule, a
  calculation, a state, a permission, the data the product keeps or deletes.
- **A security review last.** `/security-review` runs once on the final
  branch. Its fixes get rounds of their own, as the later fixes above.
- **A summary.** First a run of the repository's check on the final branch.
  Then the rounds, the decisions with their reasons, what was fixed, what was
  declined and why, and the issues filed. The pull request description
  carries the summary under `## Review`. In a public repository, an example
  from a private source in that section or in a reply to a review comment
  keeps no names, numbers, titles, paths or code.
- **Then the pull request.** For an issue taken into work, or when you ask
  for a pull request, the agent opens it after the summary and asks whether
  to merge, in the same turn. This needs a passing check and a branch other
  than the default branch. Only the merge and the open questions on business
  logic wait for you.

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
