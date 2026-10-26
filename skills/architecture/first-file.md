# A first architecture file

## The offer

At the first decision moment of a session, in a project with no
`docs/ARCHITECTURE.md` and no `ARCHITECTURE.md` at the root, offer to write
one. Make no offer when the project's `CLAUDE.md` says "This project keeps no
`docs/ARCHITECTURE.md`."

- Write nothing without a yes.
- After a no, do not offer again in that session, and ask whether to add one
  line to the project's `CLAUDE.md`: "This project keeps no
  `docs/ARCHITECTURE.md`." With that line, later sessions do not offer it.
- A yes in the middle of a feature puts the new file into its own commit on
  the current branch, with no change of the feature in it. Commits that
  already exist stay as they are.
- An existing architecture file with no numbered invariants gets the missing
  parts added to it, after the person's yes. It stays where it is.

## The five steps

1. One subagent (see *Models* in `SKILL.md`) reads a few typical files of
   each area, with `bash <skills>/debt/scripts/measure.sh` to find the areas
   that change most. It loads the conventions skills that the project's
   languages call for, as `kalinichenko:react-conventions` for React, so that
   step 5 sees where the code differs from them.
2. It proposes:
   - the codemap;
   - the modules, and the role of each folder (*Modules and layers*);
   - only the patterns that the code keeps everywhere and that are not
     obvious;
   - the limits of decomposition from the project's own sizes: for a file,
     the lines that 90% of the code files stay under, and for a folder, the
     code files of its own that 90% of the folders stay under, each rounded
     up. Count with `git grep -I -c -e '' -- <path>`, and leave out the data
     files that `<skills>/debt/scripts/data.ere` matches. So about a tenth of
     them start on the `debt` list; a person who wants a shorter list picks a
     larger limit.
3. Each proposed invariant has a check that passes on the current tree. Write
   the draft to the file's path, with no commit, and run `invariants.sh`.
   When a check fails now and the person wants the invariant, the paths that
   break it go into its `debt` list, as known debt. They need no issue now:
   the debt map weighs them later. Otherwise the invariant stays out, and the
   report names it as debt.
4. The person confirms or corrects each item.
5. No ADR for an old decision, except in two cases: when two competing ways
   exist and the person picks one of them; and when a choice that the code
   keeps everywhere differs from a rule of a conventions skill, so that the
   ADR records the choice and names the convention that it replaces.

Then offer the line for the project's `CLAUDE.md` and `AGENTS.md`, and write
it only after a yes: a link to the file and one line, with the file's own
path, as `ARCHITECTURE.md` when it is at the root:

> Before a spec, a plan or the first edit of a new feature, read
> `docs/ARCHITECTURE.md`. At the start of a new feature, and for a decision,
> load `kalinichenko:architecture`.

## The parts of the file

Short, in the shape of matklad's ARCHITECTURE.md. It holds only what the code
cannot tell: a file that restates the code costs each reader and helps none.

- a bird's-eye view;
- a codemap: names, not links to code;
- the modules, by area of the business: each one's name, its folder, and the
  rule for its public API, as "its `index.ts`", not the API itself, which the
  code states and each new export would make false;
- the layers: which folders and classes play each role;
- the invariants, numbered `I-1`, `I-2` and on;
- the limits of decomposition;
- the cross-cutting concerns;
- an index of the accepted ADRs.

Each invariant has one MUST statement, a `Check:` line unless it is review
only, and the ADR that set it, when one did. An invariant goes in only when
the code keeps it now, or when a decision sets it: a wish fails each check,
and then agents learn to ignore the checks. There is no NON-NEGOTIABLE mark:
an invariant that the project can break is not an invariant.

```markdown
## Invariants

- **I-1.** Only `src/api/client.ts` calls `fetch`.
  Check: grep `fetch\(` in `src/` except `src/api/client.ts`.
  ADR: 0001.
- **I-2.** No code file in `src/` has more than 400 lines.
  Check: lines 400 in `src/` debt `src/legacy/report.ts`.
- **I-3.** No folder in `src/` holds more than 12 code files of its own.
  Check: files 12 in `src/`.
- **I-4.** Modules talk through their index files.
```

## The `Check:` line

An invariant starts at a line `- **I-<n>.** <statement>`. The lines under it
belong to it, up to the next line that starts with a character other than a
space or a tab; a blank line does not end it. Lines inside a fenced code block
are skipped. A fence closes at a line of the same character, as long or
longer, with nothing but spaces or tabs after it, at the same column as the
opening line. A fence at column 0 also closes at such a line indented 1 to 3
columns more. A tab moves the text to the next multiple of 4 columns.

A fence stops the script in three cases. The lines that it hides could hold
a check.

- It does not close.
- It is indented, and a line that could close it is indented 1 to 3 columns
  past its opening line. Markdown counts those columns from the margin of the
  list item. The script does not know that margin.
- A non-blank line before its closing line is indented less than its opening
  line, as at the end of the list item that holds it.

```
  Check: grep `<ERE>` in `<path>`... [except `<path>`...] [debt `<path>`...]
  Check: lines <N> in `<path>`... [except `<path>`...] [debt `<path>`...]
  Check: files <N> in `<path>`... [except `<path>`...] [debt `<path>`...]
  debt `<path>`...
```

- `grep`: the pattern must find nothing. It is an extended regular
  expression, as `git grep -E` reads it: write `[0-9]`, not `\d`; `\b` does
  not work on macOS.
- `lines`: no code file has more than `<N>` lines.
- `files`: no folder holds more than `<N>` code files of its own, not
  counting its subfolders.
- Each pattern and path is in backticks, so it can hold spaces but not a
  backtick. Items are separated by spaces, and a comma may follow an item. A
  `.` may end the line.
- A line `debt` and paths, indented, anywhere in the invariant after its
  `Check:` line, adds to its `debt` list. A long list goes on such lines, one
  path each.
- A path is literal, from the root of the repository: a file or a folder,
  with or without a trailing `/`. A path P is under an entry E when P is E,
  or P starts with E and `/`.
- `except` paths are out of the check, by design: a hit under one is never
  printed. `debt` paths are known debt: a hit under one is printed, and does
  not fail the check.
- Documents, lockfiles, fixtures and other data are not code: the debt
  skill's `data.ere` leaves them out of every check.
- A path of `in` with no code file under it outside the `except` paths is an
  error, so a typo cannot pass forever.
- An invariant with no `Check:` line is review only. Any other text after
  `Check:` is a line that the script cannot read.
- A `Check:` line and a `debt` line are one line each: do not wrap them. The
  script stops, and does not drop the line, at:
  - a line right after one of them that starts with an item in backticks, or
    with `in` or `except` and an item in backticks;
  - a `debt` line with a word that is not a path;
  - a `debt` line before the `Check:` line of its invariant, or in an
    invariant with no `Check:` line;
  - a `Check:` or `debt` line under no `- **I-<n>.**` line, as under a `*`
    bullet.

  Other prose under an invariant is not read. A line is a `debt` line only
  when a path in backticks comes right after `debt`, with only spaces or
  commas between them: `debt:` or `debt of` starts prose.
- Empty code files count as code files of 0 lines.
