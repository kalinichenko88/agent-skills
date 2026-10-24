# kalinichenko:debt

A map of the technical debt: where the code is large and changes often, where
it breaks the project's own layer rules, where it is copied, and, with
ponytail, where it is over-engineered. At most three places a run become
issues labelled `debt`, each with the numbers that put it there.

## When it starts

- You ask where the technical debt is, or for a debt map of a path.
- You ask to find hotspots, layer or import violations, duplicated code, or
  over-engineering, and file them for refactoring.
- You ask to re-measure the debt issues that are already open.

## What you get

- **Hotspots, measured.** `scripts/measure.sh` ranks the code files by lines ×
  the commits that touched them in 60 days. Tests count; documents, lockfiles,
  fixtures and ignore files are left out. It needs only bash, git and awk. A high
  score alone files nothing: the file must hold more than one concern, with a
  split that can be named and that the project's rules allow.
- **Your rules, not the skill's.** A layer violation is a rule from the
  project's `CLAUDE.md` or `AGENTS.md` that a `git grep` hit breaks. A hit the
  rule's text leaves open is reported as borderline, not filed. With no such
  rule, the step is skipped, and the report says so.
- **Copies, when it can.** `scripts/clones.sh` runs `jscpd`, at a pinned
  version, with `npx` or `bunx` on a copy of the code files, in a temporary
  directory, so the project's `.npmrc`, `bunfig.toml` and `.jscpd.json` run
  and set nothing. Documents, fixtures and SQL stay out, so a copy there hides no
  clone. It lists the clones of 15 lines or more, and the clones one shared
  helper removes are one place. It never goes into a `package.json`. When
  `jscpd` cannot run, the step is skipped. The copy goes to `TMPDIR`, or to
  `~/.cache` when `TMPDIR` is not set; a `TMPDIR` that other users can write,
  as `/tmp` on Linux, is refused.
- **Less code, when ponytail is installed.** Its `ponytail-audit` finds
  dependencies the platform covers, abstractions with one implementation and
  modules that only delegate. A finding the project's own rules contradict is
  dropped. A cut of a few lines is reported as a small cut, not filed. Without
  ponytail the step is skipped; it installs as the
  [review-loop README](../review-loop/README.md#the-ponytail-step) says.
- **Few issues, and no doubles.** At most three places a run. A place an open
  debt issue already covers is re-measured: its `## Where` gets this run's
  numbers. A place closed as not planned is not filed again.
- **Issues take-in reads.** Each issue is labelled `debt`. The label is created
  once when the repository has none. Take-in in `kalinichenko:github` checks
  every open debt issue in the area of a task.
- **Steps in order.** A place larger than one pull request is a parent with a
  sub-issue per step, linked with the roadmap skill's `plan.sh`, so
  `kalinichenko:roadmap` offers them in order.
- **The default branch, and no edits.** Every count comes from `origin/HEAD`,
  not from your local changes; in a clone without it, from `HEAD`, and the
  report says so. The later steps read a checkout of that commit outside the
  repository, and none of them runs its code: no hook, no package manager.
  The map changes no file in the working tree and opens no pull request. A
  project with a debt skill of its own keeps using that one.
