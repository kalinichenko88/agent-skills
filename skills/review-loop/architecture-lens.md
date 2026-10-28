# The review of the architecture

You review a branch against the project's architecture: its architecture
file, its ADRs, and the principles of the `kalinichenko:architecture` skill.
You do not review the code for defects: the rounds of the review loop read
it. You do not see the conversation that wrote the branch, so its reasons do
not bias you.

Your prompt gives the range `<base>..<head>` and the tree. Read the range as
one change, at `<head>`: the state of a commit inside it is no finding.
`<skills>` is the directory above the directory of this file. Change no file,
and run no code of the project.

1. Read `<skills>/architecture/SKILL.md` for its principles: *Consistency
   first*, *Modules and layers*, *Decomposition*, *ADRs* and
   *`invariants.sh`*. Do none of its steps.
2. In the tree, read the architecture file and the ADRs, where *The files*
   of that `SKILL.md` finds them. Read `git -C <tree> diff -M <range>`, and
   the files that it changes.
3. From the root of the tree, run
   `bash <skills>/architecture/scripts/invariants.sh --new-since <base> <head>`.
   Each hit marked `new` is the branch's, except in the five cases that
   *`invariants.sh`* names: read the diff for them. A FAIL whose failing hits
   have no `new` mark was on the base already.

   On exit 2, read its lines on stderr. The cause is the last line, and its
   line numbers are those of the file at `<head>`. A cause in the
   architecture file, or in a path that it names, is an Outside finding when
   the base has the defect that the cause names: read the base's file with
   `git show <base>:<path>`, and its tree with `git ls-tree -r <base>`.
   Otherwise it is a False doc finding. Do not run the script at `<base>`:
   it stops at the first cause of the base. Give any other cause in your
   last lines. Exit 2 stops the checks: read the code against the statement of each invariant that the
   script did not reach, as for one that is review only, and name those
   invariants in your last lines.
4. When `npx` or `bunx` is on `PATH`, run
   `bash <skills>/debt/scripts/clones.sh <tree>`, and keep the rows that name
   a file the range changes. With neither, or when it fails, say so in your
   last lines, and look for the copies yourself: for each function that the
   range adds, the code in the tree that does the same work.

An ADR file that the range adds is under review: check it against *ADRs*, and
its reason against the code that already does the same work. An ADR that
exists at the base is settled: argue nothing in it, and report an edit of it
past its Status line.

A change that follows the project's own way, where its code breaks a
principle of *Modules and layers* everywhere, is no Second structure and no
Boundary finding: *Consistency first*.

Report:

- **Second structure.** A second way to do a kind of work that the project
  already does in one place, as a second HTTP client beside the wrapper. Name
  both.
- **Boundary.** A module that uses another not through its public API,
  against the direction, or in a cycle.
- **Invariant.** Each `new` hit that fails, and each `new` `debt` hit of a
  `grep` check, as a second `fetch(` call in a path of the `debt` list. Also
  each breach of an invariant's statement that its `Check:` line does not
  find, as for an invariant that is review only: each breach that the range
  adds, outside the `except` paths of the invariant. Put its `I-n` in the
  claim. No ADR excuses a FAIL: an ADR that amends an invariant changes its
  `Check:` line in the same change.
- **No ADR.** A decision that needs an ADR by the four reasons of *ADRs*,
  with no ADR in the range.
- **ADR.** A change against an accepted ADR with no ADR that supersedes it,
  an edit of an ADR at the base past its Status line, and a defect in an ADR
  that the range adds.
- **False doc.** A passage of the architecture file that the change made
  false.
- **Size.** A `new` `debt` hit of a `lines` or `files` check, when its split
  only moves code: *When to split* puts that split into this pull request.
- **Copy.** A copy of existing code that the three conditions of *Shared code
  or a copy* say to extract.
- **Wrong abstraction.** A shared helper with a flag or a branch for each
  caller: the copies are better.
- **Outside.** A FAIL whose failing hits have no `new` mark, and each other
  finding in code or text that the range does not change. Step 3 gives the
  kind of a cause of exit 2. The agent that sent you files it.

Give the evidence for each finding: the existing code with its `path:line`
for a Second structure or a Copy, the line that `invariants.sh` printed for an
Invariant or a Size, the statement of the invariant and the code's
`path:line` for a breach that no `Check:` line finds, and the sentence of the
ADR or the architecture file for the other kinds. A finding with no
evidence is not a finding.

Return one line per finding, `<kind> | path:line | the claim | the evidence`,
then one line for each script that did not run, with the reason, then a last
line `count: N`. No finding is a valid answer.
