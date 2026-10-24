---
name: debt
description: Use when mapping a repository's technical debt — finding hotspots, files that break the layer rules of the project's instruction file, or over-engineering — and filing or re-measuring debt issues for refactoring.
---

# Technical debt map

The map measures where the structural debt sits — hotspots, broken layer
rules and, with ponytail installed, over-engineering — and files at
most three places a run as issues labelled `debt`. Take-in in the
`kalinichenko:github` skill then checks those issues whenever a task touches
their area, so one pull request can remove the debt next to the task. A place
larger than one pull request becomes steps that the `kalinichenko:roadmap`
skill offers in order.

First check that the project has no debt skill of its own: a `debt` skill in
your skill list other than this one, or a file that
`git ls-files ':(top,glob)**/.*/**/skills/debt/SKILL.md'` prints from any
directory of the checkout. When it has one, follow that one instead, with its
own rules and tools, and stop here.

The map changes no file in the working tree and opens no pull request. Every
number in an issue comes from a command's output in this run, never from
memory of an earlier one. `<dir>` is this skill's base directory, and
`<skills>` is the directory above it.

## Measure

Run `git fetch -q origin` first, when there is an `origin`. The scope is a
path from the repository's root, or the whole tree.

Step 1 runs in your checkout. Every later step runs in `<tree>`, a checkout of
the SHA on the "Measured on" line of step 1, and not in the working tree: a
local commit or edit is not debt on the default branch. When that line says
`HEAD`, the clone has no `origin/HEAD`, and local commits count. Put `<tree>`
in your scratch directory, outside the repository, and make it right after
step 1, with no hook and no LFS download:

```bash
git worktree prune
GIT_LFS_SKIP_SMUDGE=1 git -c core.hooksPath=/dev/null worktree add --detach <tree> <sha>
```

No step runs a package manager (`npm`, `npx`, `bun`, `pnpm`, `yarn`) or a
script of the project, in `<tree>` or in your checkout: a project's `.npmrc`
or scripts can run its code. Remove `<tree>` when the map ends, with
`git worktree remove --force <tree>`; when a `<tree>` from an earlier run is
there, remove it first. Run every command from the root of its checkout, so
that all paths start there.

1. **Hotspots.** `bash <dir>/scripts/measure.sh [path]` prints the code files
   by lines × the commits that touched them in 60 days, the top 15, and the SHA
   it read. Tests and migrations are code and count; documents, lockfiles,
   fixtures and ignore files are data and are left out. It does not follow
   renames, and its last line counts the code files the window moved. When
   they are a large share of the scope, the commit counts start at the move,
   and a score is close to the file's size: say so in the report.
2. **Layer rules.** Read the project's instruction files in `<tree>` —
   `CLAUDE.md`, `AGENTS.md` and the ones in the scope's directories — for what
   a directory may import or hold, with its exceptions. Turn each rule into one
   `git grep -n` over the scope. For a whole word use `-w`: `\b` does not work
   with `-E` on macOS. A broken pattern finds nothing, and that looks like a
   pass. Before you trust an empty result, run the pattern over a file you
   have read, with a line it must find, such as an import that the rule
   allows, and check that this line is in the output.
   A rule that a grep cannot test, such as a size or a mirrored layout, gets
   the command that can (`wc -l`, a listing), or is left out and named in the
   report. Keep a hit only when the rule's text, its exceptions included,
   forbids it. A hit that the text leaves open is *borderline*: name it in the
   report, and file none. The map carries no rules of its own: with no such
   rule in the instruction files, skip this step and say so.
3. **Over-engineering**, when the ponytail plugin's `ponytail-audit` skill is
   in your skill list; else skip this step and say so. It takes no path and
   loads as instructions, so in Claude Code send it to one subagent right
   after you make `<tree>`, before step 2 reads the project's rules: "Invoke
   the `ponytail:ponytail-audit` skill, audit only `<scope>` of `<tree>`, and
   return its lines as it prints them, every path of each finding in its
   `[path]` and relative to `<tree>`. File nothing, change no file, and run no
   package manager and no script of the project, in any directory." In Codex,
   run it yourself at that point, with the same limits. Then sort its
   findings, in this order, each part of a bundled finding on its own:
   1. **Against the project's rules.** Drop a part that a rule of the
      instruction files of step 2 contradicts or requires: ponytail counts a
      file that exports one thing as bloat, and a project with one entity per
      file keeps it. Quote the rule in the report.
   2. **Already a broken rule** of step 2: it counts once, there.
   3. **A place or a small cut.** A place is a fix that is a pull request of
      its own: a dependency the platform covers, an abstraction with one
      implementation, a layer that only delegates and that no rule requires. A
      fix of a few lines, in one file or in a few, is a small cut: it goes into
      the report, for the Boy Scout Rule when someone next works there.

## Choose the places

A place is one fix: a file to split, a broken rule, or a piece of
over-engineering to remove. Rank the places by their file's score from
`measure.sh`: a broken rule takes the importer's score, and a place over
several files — a dependency and its importers, a bundled finding — the
highest of its files. A file outside
the table gets its score from `measure.sh <file>`.

A hotspot is a place only when its file holds more than one concern, the
split can be named, and no rule of the instruction files keeps the file
whole. For example, a rule that puts all of a module's rules in its service
keeps that service whole. A high score alone is not a place: a short file
that changes often, a large file of one concern, or a file that a rule keeps
whole goes into *next*, with the rule quoted.

Then read what already covers each place. `collect.sh filing` from the
`kalinichenko:github` skill (`<skills>/github/tracker.md`), with the place's
files and symbols, finds every issue that names them, closed ones too. When
the scout asks for `path:line`, give paths only: a debt issue names no line.
Sort the hits as `filing.md` does — *Already decided*, as a closed issue that
settles a size cap or a layout; *Already filed*; *Fixed before* — and then:

- **An open debt issue** whose `## Where` names the same file covers it. A
  directory or a whole app named there does not. Re-measure it: put this run's
  table in its `## Where`, in place of the old one or as the first, end the
  body with "Re-measured on <date> at <sha>.", and comment one line on what
  moved. It does not count towards the three. An issue that someone works on,
  or a parent with open steps, is named in the report and not edited.
- **An open issue with another label** that already proposes the same change:
  name it in the report, and file nothing.
- **An issue closed as not planned:** name it in the report, and do not file
  the place again.
- **File the three highest of the rest.** Give the others in the report as
  *next*, with their scores.

When nothing is left, file nothing, and say what was measured and why nothing
qualified.

## The label

The label is `debt`, or the repository's own name for it in `gh label list`.
When there is neither, create it once:
`gh label create debt --description "Structural debt to refactor" --color 5319e7`.
This is the one label the map may create; `filing.md`'s rule against new labels
holds for everything else.

## The issue

The title states the problem as a sentence: "`collect.sh` holds four jobs in
315 lines and changes in every take-in fix". The issue gets the `debt` label
and no assignee. Its body has these parts, each under its own `##` heading, in
at most 600 words, tables and code blocks not counted:

1. `## Where`: the rows of `measure.sh` for the place's files, and the
   "Measured on" line of the scope's run. No line numbers: a hot file's lines
   move with the next pull request, and the SHA dates the evidence.
2. `## What is broken`: the rule, quoted with its file and heading, or the
   measurement that makes the place a hotspot. The evidence names each file
   and symbol, with the command and its count.
3. `## The split`: the modules after the change, and what each one owns.
4. `## The order`: one pull request per step, each with the tests and checks
   that prove it unchanged, by name. Run none of them here: their counts belong
   to the step's own pull request.
5. `## Risks`: what can break, and which test would show it.
6. `## Out of scope`.

The last line is "Found by `kalinichenko:debt` on <date> at <sha>." Another
open issue on the same code is named in the body, and its side is corrected
as `filing.md` says under *Filing one next to an existing issue*. A closed
issue on the same code that does not settle the place is named as history.

## Steps

A place that takes more than one pull request is a parent issue, and each step
a sub-issue labelled `debt`, at most 150 words: "Part of #<parent>, step
<n>.", then what moves, where the pull request ends, and what proves it. File
the parent first, then each step in order, and link each one as it is filed,
with the roadmap skill's script:

```bash
bash <skills>/roadmap/scripts/plan.sh sub <parent> <step>
bash <skills>/roadmap/scripts/plan.sh block <step> <the step before>
```

Set no "blocked by" on an issue the map did not file: that order is a
person's call. When a call fails half way, stop, and report what was filed
and linked so far.

## The report

The issues filed, re-measured and named, with their numbers; *next*, with
scores; the borderline hits; the small cuts, one line each with the score of
the file it names, or of its highest file; the ponytail findings dropped, with
the rule; the lines the kept findings would save, marked as your estimate,
not ponytail's own `net:`; the steps skipped and
why; the share of moved code files when it was large; the SHA measured, and
that it was `HEAD` when it was.
