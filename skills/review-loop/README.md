# kalinichenko:review-loop

A review that ends: rounds that read only the last fixes, a stop at the first
clean round, one last pass over the whole branch when a defect was fixed, a
security review last, and a summary of what was decided and fixed.

## When it starts

- `rules.md` starts it before the first review of a change: `/code-review` or
  `/security-review` in Claude Code, `/review` in Codex, or a review subagent.
- A person's review comments arrive.
- You choose a review level, or decide whether another round is needed.

## What you get

- **Less code first.** When the
  [ponytail](https://github.com/DietrichGebert/ponytail) plugin is installed,
  its `ponytail-review` runs once before the first round, and its cuts are one
  commit. Without ponytail the step is skipped, and the
  summary says so.
- **A level with a reason.** `low` to `xhigh` by the weight of the change, and
  one sentence that says why. `ultra` only when you ask for it.
- **Rounds that read less.** The first round reads the whole branch. Each round
  of fixes is one commit, and the next round reads only that commit.
- **A stop.** The loop ends at the first round that confirms no defect. Nits
  are applied without another round. After the third round with a defect, the
  agent asks you.
- **One last look at the whole branch.** When the loop fixed a defect, one
  pass reads the whole branch again after it stops, to see how the fixes fit
  the rest. Its fixes go through the same rounds. It never runs twice.
- **Fewer questions.** The agent fixes the obvious findings and decides the
  rest by itself. It asks only about a change to business logic: a rule, a
  calculation, a state, a permission, the data the product keeps or deletes.
- **A security review last.** `/security-review` runs once on the final
  branch. Its fixes go through the same rounds of `/code-review`.
- **A summary.** The rounds, the decisions with their reasons, what was fixed,
  what was declined and why, and the issues filed. The pull request
  description carries it under `## Review`.

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
