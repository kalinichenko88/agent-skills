# kalinichenko:architecture

New code grows into the project's existing structure, not beside it: one HTTP
client, one way to format a price, files that a person can read. The project
keeps a short `docs/ARCHITECTURE.md` with numbered invariants that a script
checks, and an ADR for each decision that needs one.

## When it starts

- A new feature starts: a screen or page, an endpoint, a module, an
  integration.
- A decision comes up: where new code goes; a new module, layer, dependency,
  pattern or data store; a choice between options in a spec or a plan; a
  change to a file or a module past its size limit.
- You write or check `docs/ARCHITECTURE.md`, its invariants, or an ADR.

## What you get

- **The problem before the code.** At the start of a feature, four short
  answers: the problem in one sentence, the proof that it needs solving, the
  simplest way to solve it, and the code that already does similar work. When
  a simpler way exists, it comes first. You decide; the work never stops.
- **One way to do one kind of work.** At a decision, the agent finds the code
  that already does this kind of work and extends it. A new structure needs a
  reason why the existing one cannot take the change. At most three options,
  each with its cost, and no abstraction for a future need.
- **Your invariants, checked.** `docs/ARCHITECTURE.md` (or `ARCHITECTURE.md`
  at the root) holds numbered invariants. Each has a `Check:` line, or is
  checked in review only. A check is a pattern that must find nothing, a size
  limit for a file, or a size limit for a folder. `scripts/invariants.sh` runs them and prints PASS or FAIL for
  each. A file or folder already past its limit is known debt, listed in the
  check, so the check passes now and the list shrinks over time. With
  `--new-since <base>`, it marks the hits that a branch adds. It needs only
  bash, git and awk.
- **Splits before growth.** A change into a file past its limit names the
  split first. A split that only moves code goes into the same pull request,
  as its own commit before the feature; one that needs decisions of its own
  becomes a debt issue.
- **Shared code only when it pays.** Duplicated code becomes shared code only
  when the copies do one job, need no flag for each caller, and tie no two
  unrelated modules together. Otherwise the copy stays.
- **Decisions on record.** A decision that changes the structure, is costly
  to undo, adds a dependency or sets a pattern gets an ADR in `docs/adr/`,
  with at least two options and its costs. A second reader that does not see
  the conversation checks it first. An option you reject for a lasting reason
  gets an ADR too, so no agent offers it again.
- **A first file, when you want one.** In a project with none, it offers once
  a session to write `docs/ARCHITECTURE.md` from the code as it is, and writes
  nothing without your yes. After a no, one line in `CLAUDE.md` stops the
  offer.
- **No code of yours runs.** No step runs a package manager, a script of the
  project or a build in your project's tree. The text of `docs/ARCHITECTURE.md` never runs as a
  command: `invariants.sh` passes each pattern and path to `git grep` as an
  argument of its own.
