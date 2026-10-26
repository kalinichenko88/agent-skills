# The architecture skill — design

Date: 2026-10-25. Status: design, approved for planning when the person says
so. Issues: #87 is the parent; its sub-issues are #96 (the skill), #97 (the
review lens), #98 (debt), #99 (the measurement) and #100 (the dependency
graph). This document covers all five. The first pull request delivers #96.

A new skill in the `kalinichenko` plugin, `kalinichenko:architecture`. It makes
a change grow into the project's existing structure, keeps the project's layers
and its decomposition, and records the decisions that matter as ADRs. It works
in Claude Code and in Codex.

## Why

An agent that adds a feature reads the code that the task needs. Nothing makes
it look for the code that already does the same kind of work. So new code
grows beside the existing structure, not into it: a second HTTP client, a
second way to keep settings, a new folder for one module. Each diff looks
correct. After some months the project has two or three ways to do one thing,
and files that grew past what anyone can read. Nothing records why the
structure is as it is, so the next agent cannot tell a decision from an
accident.

Measured elsewhere (#87 *Prior art* has the sources):

- GitClear, 211M changed lines: copied lines grew from 8.3% to 12.3% from 2021
  to 2024, and moved lines fell from 25% to under 10%.
- OpenAI, "Harness engineering": "Codex replicates patterns that already exist
  in the repository — even uneven or suboptimal ones".
- Keep the Why: 7 of 10 fresh sessions offered a simplification that was
  already rejected; 0 of 10 with one recorded entry.

What the person asked for, in this session:

- Layer boundaries, the direction of data, and clean code. The spirit, not the
  letter: no rules of a framework, as Nest or Laravel. Those are the
  decisions of one project.
- Decomposition, above all as the project grows: a module or a file must not
  grow without end. The skill proposes how to split it, extracts shared code,
  and extracts duplicated code into shared code. But when the shared code gets
  too complex, a copy is better, as in Go.
- Deterministic tools where they can do the work: scripts, dependency graphs.
  A tool for one language is a soft dependency: used where it runs, skipped
  where it does not.
- At the start of a feature, the skill looks at it critically: which problem
  we solve, whether it needs solving, the simplest way to solve it, and how it
  fits into the existing architecture.
- The skill works in the review and in the debt map.
- It uses `kalinichenko:github` to file issues and `kalinichenko:roadmap` to
  read the roadmap. It is about code, and it changes neither skill.

## Goals

1. At the start of a feature, the agent names the problem, checks that it
   needs solving, and puts the simplest way first.
2. At the moment of a decision, the agent finds the code that already does this
   kind of work and extends it, or writes down why the existing structure
   cannot take the change.
3. Each project keeps a short `docs/ARCHITECTURE.md` with numbered invariants,
   and an ADR for each decision that needs one.
4. Modules by area of the business, layers by role inside each module, one
   direction of dependencies and data, clean code: as principles that the
   skill maps onto each project's own folders.
5. Decomposition: a size limit per project, a named split when a change goes
   past it, and one rule for shared code against a copy.
6. Deterministic checks before a model reads: `invariants.sh`, the debt
   skill's `measure.sh` and `clones.sh`, and a dependency graph where one runs.
7. The same checks in the review (#97) and in the debt map (#98).
8. Claude Code and Codex.

## Non-goals

- No rules of a framework or a stack. The code style of a stack stays in
  `typescript-conventions` and `react-conventions`.
- No fixed step of the workflow, as a step before the spec. #87 declined it:
  during the brainstorming and the spec, the agent collects the context, and
  the decisions change. A step before the spec decides with less context than
  the spec has.
- No new always-on rule in `rules.md` (#87, decision 4). Also, `rules.md` is
  about 9,100 of the 10,000 characters that `tests/rules_test.sh` allows.
- No ADR tool, no arc42, no C4, no ADRs in bulk for old decisions.
- No fitness-function tool installed into a project. An ADR's Confirmation
  line names one; adding it is the project's task.
- No change to the github and roadmap skills.
- No dependency inversion by default, and no four layers of Clean
  Architecture. The direction of dependencies is a principle; an interface
  between the logic and the data is not. An interface comes when a second
  implementation exists, or when a test needs a real seam.

## Anti-goals

The skill fails, even when each step runs, if:

- `docs/ARCHITECTURE.md` restates what the code says. ETH (arXiv 2602.11988)
  found that context files "do not generally improve task success" and cost
  more than 20% extra, and that repository overviews do not help. The file
  holds only what the code cannot tell.
- An invariant is a wish. An invariant goes in only when the code keeps it
  now, or when a decision sets it. Otherwise each check fails, and the agents
  learn to ignore the checks.
- The skill adds the abstraction it is meant to prevent: an interface with one
  implementation, a layer for a future need, a shared helper with a flag for
  each caller.
- A step runs code of the project: a package manager, a script, a build, or
  text from `docs/ARCHITECTURE.md` as a shell command.
- The review argues again with an accepted ADR.

## Constraints

- Scripts are bash, with `git`, `awk` and `jq`, as the plugin's other scripts.
  `npx` or `bunx` and a graph tool are soft dependencies.
- The safety rules of the debt skill hold for every step: no package manager,
  no script of the project, no build, in the project's tree.
- Prose follows the plugin's style: Simplified Technical English. Code,
  comments and commit messages are English.
- `make check` runs the scripts' tests on fixtures. A test that calls the
  model is an eval, outside `make check`.
- Codex has no subagent with a model. In Codex, the agent does each step that
  the table below gives to a subagent.

## The project's files

**`docs/ARCHITECTURE.md`**, short, in the shape of matklad's ARCHITECTURE.md.
A project that already has `ARCHITECTURE.md` at its root keeps it there, and
the skill and its scripts use that file. One that already keeps its ADRs in
`doc/adr/` or `docs/decisions/` keeps them there. A second place for the same
document is the drift that this skill stops. An existing file with no
numbered invariants gets the missing parts added to it, after the person's
yes. Its parts:

- a bird's-eye view;
- a codemap: names, not links to code;
- the modules, by area of the business: each one's name, its folder, and the
  rule for its public API, as "its `index.ts`", not the API itself, which the
  code states and each new export would make false (see *Modules and
  layers*);
- the layers: which folders and classes play each role;
- the invariants, numbered `I-1`, `I-2` and on;
- the limits of decomposition (see *Decomposition*);
- the cross-cutting concerns;
- an index of the accepted ADRs.

Each invariant has one MUST statement, a `Check:` line unless it is review
only, and the ADR that set it, when one did. A review finding cites `I-3`,
and an ADR says "amends I-3". An ADR that amends `I-3` changes its statement
and its `Check:` line in the same commit, so the check passes again. A FAIL is
then always a defect: no reader looks for an ADR to excuse one. A `Check:`
line of any kind can name two lists of paths: after `except`, the paths that
it leaves out by design, as the one module that may call `fetch`; after
`debt`, the paths that break it now, as known debt (see *Decomposition*).
There is no NON-NEGOTIABLE mark: an invariant that the project can break is
not an invariant. The invariants are the
project's constitution, as in Spec Kit, but a section of this file and not a
file of their own: two files go stale faster, and then one must say which of
them wins.

An example, for its shape:

```markdown
## Invariants

- **I-1.** Only `src/api/client.ts` calls `fetch`.
  Check: grep `fetch\(` in `src/` except `src/api/client.ts`.
  ADR: 0001.
- **I-2.** No code file in `src/` has more than 400 lines.
  Check: lines 400 in `src/` debt `src/legacy/report.ts`.
- **I-3.** No folder in `src/` holds more than 12 code files of its own.
  Check: files 12 in `src/`.
```

**`docs/adr/NNNN-title.md`**: one decision per file. A file is never renamed
or deleted, so a link to it does not rot. The template:

`# NNNN Title`, then Status (accepted | rejected | superseded by NNNN), Date, Context, Options considered (at least two, one line each),
Decision ("We will …"), Consequences (good and bad), Invariants (the ones it
adds or amends, as `I-n`, or none), Confirmation (the check that enforces it:
a `Check:` line, a lint rule, a test, or "review only").

**`CLAUDE.md` and `AGENTS.md`** get a link and one line, written only after
the person's yes: "Before a spec, a plan or the first edit of a new feature,
read `docs/ARCHITECTURE.md`. At the start of a new feature, and for a
decision, load `kalinichenko:architecture`." The line names the file at the
path where the project keeps it, as `ARCHITECTURE.md` at the root.
Keep the Why and Vercel measured that such a line loads a skill where its
description alone often does not.

## The start of a feature

Decided with the person. This is not the step before the spec that #87
declined: that step decided the structure with less context than the spec
has. This one decides no structure. It decides what we build and why. The
structure waits for the moment of a decision, when there is more context.

It starts at a new capability: a screen, an endpoint, a module, an
integration. Not at a bug fix, and not at a small change to existing
behaviour.

The agent answers four questions itself first, from the code and the data,
and asks the person only what it cannot find:

1. **The problem.** One sentence, in the user's words: who has it, when, and
   what goes wrong. The problem, not a solution: "the list takes 4 seconds to
   load", not "add a cache".
2. **Does it need solving?** The proof that it exists: a measurement, a
   report, a count, as the rule "count it first" asks of a bug fix. What
   happens if we do not solve it. Whether an existing feature, a setting or
   the platform solves it already.
3. **The simplest way.** The ladder: do nothing → a setting → what the code
   already has → extend what exists → new code, as little as works. The first
   step that solves the problem is the answer.
4. **What it touches.** Facts only: the code that already does similar work,
   with `path:line`, and the modules it touches. Where the new code goes, by
   module and by layer, is decided at the moment of a decision, not here.

The result is a short block of the four answers at the start of the spec, or
in the conversation when there is no spec. When the problem has no proof, or a
simpler way exists, the skill says so plainly, with the proof, and puts the
simpler way first. The person decides; the skill never stops the work.

With `superpowers:brainstorming` in the session, its order holds: its first
message is the opt-out line and one question, and it reads the code only after
the person says yes to its offer to look. So the block comes first in the
message that reports what that look found, and again at the start of the
spec. With no such look, it comes only where the paragraph above puts it.
Never before its first question.

## The moment of a decision

The skill's description names two moments, not stages: the start of a
feature, above, and the moment of a decision:

- where new code goes;
- a new module, layer, dependency, pattern or data store;
- a choice between options that a spec or a plan records;
- a change to a file or a module that is past its limit.

The moment can come in brainstorming, in a spec, in a plan, or in code with no
spec. The steps:

1. Read `docs/ARCHITECTURE.md` and the ADRs that it links for the area. Run
   `invariants.sh`. With no such file, offer to write one (see *A first
   `docs/ARCHITECTURE.md`*).
2. Find the code that already does this kind of work, and name it with
   `path:line`. Extend it.
3. A new structure needs a reason why the existing one cannot take the change,
   in Spec Kit's words: "simpler alternative rejected because".
4. When the change goes into a file or a module past its limit, or into a file
   that does more than one job, name the split (see *Decomposition*).
5. Give at most three options, the recommendation first, each with its cost in
   files and concepts, and the cost of the next likely change in the same
   area. No option adds an abstraction with one implementation or a layer for
   a future need.
6. **The gate.** The main session checks the recommended option against the
   text of each invariant of the area and its `Check:` line: it keeps it, or
   it breaks it. The option is not in the tree yet, so `invariants.sh` cannot
   judge it; the script runs once the edit exists, before its commit, and
   again in the review. A broken invariant ends in one of three ways: change
   the design; write an ADR that amends the invariant, its statement and its
   `Check:` line, with its "simpler alternative rejected because"; or, for a
   limit of decomposition only, put the path into the `debt` list with its
   debt issue, by *When to split*. Never a silent exception.
7. Decide whether the decision needs an ADR (see *ADRs*). Most decisions do
   not.
8. **A second reader** for a decision that needs an ADR. One subagent that
   does not see the conversation (see *Models*) gets the area of
   `docs/ARCHITECTURE.md`, its ADRs, the code that step 2 found, the options
   and the gate, and the block of *The start of a feature* when there is one.
   It checks whether the problem has its proof, whether the simplest way came
   first, whether the search missed existing code, whether the reason for a
   new structure holds, whether the gate is right, and what the next likely
   change will cost. Its answer is advice: the main session
   answers each point, and a point on which the two do not agree goes to the
   person.

**Consistency first** (decided with the person). When the project's code
breaks a principle of *Modules and layers* everywhere, as components that all
call `fetch` with no service layer, the first option follows the project's own
way: one way is better than two. The skill names the breach, and the second
option brings the principle in: an ADR that sets it, and a parent issue with
the steps of the migration, through `kalinichenko:github` and
`kalinichenko:roadmap`. The principle comes into the project as a whole, not
one file at a time. The person chooses at the decision.

Consistency first covers the principles of this skill only. A rule of a
conventions skill keeps its own text: `react-conventions` says that an upward
import that already exists is debt, not a precedent, and forbids another one
beside it. Only an accepted ADR of the project overrides a convention, also
for a choice that the first `docs/ARCHITECTURE.md` records (step 5 of *A
first `docs/ARCHITECTURE.md`*).

The ADR is written when the decision is final: in the pull request with the
code, with the status `accepted`. The review of the pull request is where it
is argued, and the merge makes it true. An ADR file that
`git diff <base>..HEAD` adds is under review: the lens and the person argue
it. One that exists at the base is settled. A branch that changes it past its
Status line breaks *ADRs* below, and the lens reports that. A spec or a plan
names the ADR that the work will add, by its title, and does not write it.

A finding outside the task, such as two competing ways that the task does not
touch, becomes an issue through `kalinichenko:github`. When the decision is
about a part that a milestone already plans, `roadmap.sh` of
`kalinichenko:roadmap` gives that milestone as context.

## Modules and layers

The skill holds principles. The project's `docs/ARCHITECTURE.md` holds the
letter: which of its folders is which module, and which plays which role.

- **Modules by area of the business, not by technology:** `orders`,
  `billing`, `users`, not only `controllers`, `services`, `utils`. What
  changes together stays together. A module uses another only through its
  public API, in one direction, with no cycles. This is the rule of
  `react-conventions` for features, for any stack.
- **Layers by role inside a module, not by the name a framework gives them:**
  - the edge takes input from outside and gives output: an HTTP controller, a
    CLI command, a queue handler, a UI component or page;
  - the check at the edge validates and shapes the input once, before the
    logic sees it: a request or form object, a DTO, a schema;
  - the logic holds the rules of the product: services, use cases. It knows no
    transport and no UI;
  - the data keeps and loads state: repositories, models, stores, API clients.
- **Direction.** Dependencies point one way: edge → logic → data. A lower
  layer never imports a higher one. Data flows the same way: in through the
  edge, checked, through the logic to the data; the answer goes out through
  the edge. On the frontend: a user action → logic → store → render. A write
  always goes through the logic. Whether the edge may read data directly, as a
  component that reads a store through a selector, is the project's decision.
- **Clean code.** A unit does one job. The edge is thin: no rule of the
  product in a controller or a component. The logic reaches the network or the
  database only through the data layer. Validation happens once, at the edge.
  One way to do one kind of work.
- **Hide what can change.** The calls to an external API, a database or a
  library live in one place of the data layer, so a change of the vendor
  touches one module. Whether their types pass through to the logic is the
  project's decision: a mapper comes with a second source or a real change,
  not before, by the non-goal on interfaces.
- **The cost of a change is the measure.** A change to one rule of the product
  that needs edits in many modules shows a wrong border. Change coupling in
  #100 measures it.

**Into the project.** The first `docs/ARCHITECTURE.md` finds which folders and
classes are the modules and play each role in this project, whatever the
framework calls them, and writes the principles as invariants with `Check:`
lines on those paths. The person confirms each one. When the code already
keeps another choice everywhere, as fat models, the file records that choice:
only what the code already keeps goes in. A later change goes through an ADR,
by *Consistency first*.

`react-conventions` keeps the layer order `app → features → shared → ui →
core` and its feature rules. The principles above are the roles inside that
order. They refer to it and do not copy it. When an accepted ADR of a project
differs from a convention, the ADR wins in that project, and it names the
convention that it replaces.

## Decomposition

- **Signals**, from the debt skill's scripts: the size of a file and of a
  module (`wc -l`, the count of files), how hot a file is (`measure.sh`: its
  lines times the commits that touched it in 60 days), and the copies
  (`clones.sh`). With #100: the import graph and change coupling.
- **The limits are the project's**: invariants with a `lines` check for a
  file and a `files` check for a folder. The skill keeps no number of its own.
  It proposes, for each, the size that 90% of the project's code files, or
  folders, stay under, rounded; the person confirms or changes it. So about a
  tenth of them start on the `debt` list; a person who wants a shorter list
  picks a larger limit.
- **The `debt` list.** The files and folders already past a limit go into
  the check's `debt` list, so the check passes now. `invariants.sh` prints
  each of them with its size, as known debt. A path that drops below the limit
  leaves the list. After the first `docs/ARCHITECTURE.md`, a path joins it
  only in a pull request that also files its debt issue, by *When to split*
  below. A new number for the limit needs an ADR.
- **At the decision**, when the change goes into a file or a module past its
  limit, or into a file that does more than one job, the skill names the
  split: the new files, what goes into each, and by which role.
- **When to split.** A split that only moves code, with no change of
  behaviour, goes into the same pull request, as its own commit before the
  feature: make the change easy, then make the easy change (Kent Beck). A
  split that needs decisions of its own: the change goes in as it is, the file
  joins the `debt` list, and the split becomes a debt issue through
  `kalinichenko:github`, in the same pull request.
- **Shared code or a copy**, as in Go: "A little copying is better than a
  little dependency." Extract the shared code only when all three hold:
  1. the copies do one job for one reason, and would change together;
  2. the shared version needs no flag or branch for each caller;
  3. the extraction ties together no two modules that do not know each other
     otherwise: the shared code goes to a lower layer.

  When one of them fails, keep the copy. Two copies are fine. A third copy is
  the time to check the three again.

## ADRs

A decision needs an ADR when:

1. it changes the structure, the direction of a dependency, a public
   interface, or a quality goal (Nygard's categories);
2. it is costly to undo, or it adds an external dependency;
3. it sets a pattern that later code must follow: without the ADR, a reviewer
   would see two competing ways (Spotify's test);
4. it reverses or narrows an accepted ADR, or amends an invariant. Then a new
   ADR supersedes the old one, and the old one is not edited, except its
   Status line.

No ADR when none of the four holds: the choice is local and cheap to undo, or
a lint rule or a documented convention already enforces it. The four win: a
new external dependency needs an ADR, however small. An option that the person rejects for a
lasting reason gets an ADR with the status `rejected`, so that the next agent
does not offer it again.

The template above guards against Zimmermann's anti-patterns: "Mega-ADR",
"Blueprint or Policy in Disguise", "Sprint" (one option), "Free Lunch Coupon"
(no consequences).

## A first `docs/ARCHITECTURE.md`

The skill offers to write it at the first decision moment of a session, in a
project that has none. It writes nothing without a yes. After a no, it does
not offer again in that session, and it asks whether to add one line to the
project's `CLAUDE.md`: "This project keeps no `docs/ARCHITECTURE.md`." With
that line, later sessions do not offer it. A yes in the middle of a feature
puts the new file into its own commit on the current branch, with no change
of the feature in it. Commits that already exist stay as they are.

1. One subagent (see *Models*) reads a few typical files of each area, as
   Agent OS's `/discover-standards` does, with `measure.sh` to find the areas
   that change most, and with the graphs of #100 when they run. It loads the
   conventions skills that the project's languages call for, as
   `kalinichenko:react-conventions` for React, so that step 5 sees where the
   code differs from them.
2. It proposes: the codemap; the modules and the role of each folder; only
   the patterns that the code keeps everywhere and that are not obvious; the
   limits of decomposition from the project's own sizes.
3. Each proposed invariant has a check that passes on the current tree. When
   it fails now and the person wants the invariant, the paths that break it go
   into its `debt` list, as known debt. These paths need no issue now: the
   debt map weighs them later by its own rules (see *The debt map*).
   Otherwise the invariant stays out, and the report names it as debt.
4. The person confirms or corrects each item.
5. No ADR for an old decision, except in two cases: when two competing ways
   exist and the person picks one of them; and when a choice that the code
   keeps everywhere differs from a rule of a conventions skill, so that the
   ADR records the choice and names the convention that it replaces.

## `invariants.sh`

`skills/architecture/scripts/invariants.sh [ref]`, run from the root of the
project's checkout. It reads `docs/ARCHITECTURE.md`, or `ARCHITECTURE.md` at
the root when the first is not there, at the ref, or in the working tree with
no ref, and runs each `Check:` line. Three kinds of check in #96:

- `grep`: an extended regular expression and the paths it reads. It must find
  nothing.
- `lines`: a number and the paths it reads. No code file there has more
  lines.
- `files`: a number and the paths it reads. No folder there holds more code
  files of its own, not counting its subfolders.

Each kind can also name its `except` paths, which it leaves out by design,
and its `debt` paths, which break it now. Code and data are told apart by the
debt skill's `data.ere`. #100 adds a fourth kind: "A does not import B", from
the import graph. With no architecture file at the ref, the script prints one
line that says so and exits 0.

`invariants.sh --new-since <base> [ref]` gives the same report and marks
`new` each hit that the base does not have, under a FAIL and under the known
debt of a PASS. It reads the checks at the ref and runs them on both trees, so
the base needs no architecture file, and a check that the branch amends is the
same at both. Before it compares, it follows the renames of files: a file
that `git diff -M <base> <ref>` shows as renamed is compared with its old
path. A folder is compared by its path
only, because `git diff` names no folder renames. So when a branch only
renames a folder of a `debt` list, and renames it in the list too, its known
debt shows as `new`; the lens reads the diff and sees the move.
A hit of `grep` is matched by its path and the text of its line, not by its
line number, which moves. Identical hits are counted: when the ref has more
hits with one path and one text than the base, the extra ones are new. A hit
of `lines` or `files` is new when the run on the base has no hit at its old
path (for a folder, its path), or a smaller one there. So a file that the
branch moves into the paths of a check, or out of its `except` paths, brings
a `new` hit.

The output is one line per invariant, `I-1 PASS` or `I-2 FAIL`, and under each
FAIL what it found: the `git grep` lines, or the files and folders and their
sizes. Under a PASS, each path of its `debt` list that still breaks the check
is printed, as known debt: with its lines for `grep`, with its size for
`lines` and `files`. A path of the `debt` list that no longer breaks it is
printed as no longer debt, so that the list shrinks. The `except` paths are
never printed. An invariant with no `Check:` line prints `I-4 review only`.
The exit status is 0 when no check fails, 1 when one fails, and 2 when a
check did not run: a wrong call, no git repository, a line that the script
cannot read, a `Check:` or `debt` line that no invariant holds, a code fence
that does not close, a path of `in` with no code file outside its `except`
paths, a pattern that git rejects, or no debt skill
beside this one. Then the lines on stderr name the cause.

The script builds each `git grep` call itself, with `--` before the paths, and
puts the pattern in its own argument after `-e`, so a pattern that starts with
`-`, as `-webkit-`, is a pattern and not a flag. No text of
`docs/ARCHITECTURE.md` runs as
a shell command. A pattern that would break out of its argument fails as a
pattern, not as a command.

One script for three places: the gate at the decision, the review lens (#97),
and step 2 of the debt map (#98).

## Models

Decided with the person.

| Step | Who | Why |
| --- | --- | --- |
| The start of a feature, the decision and its options | the main session | It has the context of the brainstorming and the spec. A subagent decides with less context. |
| Find the code that already does this kind of work | an `Explore` subagent, `model: "sonnet"` | Reading. The file contents stay out of the main context. #99 checks `haiku`. |
| The second reader for a decision that needs an ADR (step 8) | one subagent that does not see the conversation, `model: "fable"`, `effort: "xhigh"` | Rare, and costly to undo by definition. A reader that does not see the conversation does not take the main session's bias. |
| A first `docs/ARCHITECTURE.md` | one subagent, `model: "fable"`, `effort: "xhigh"` | Once per project. Every later decision reads this file. |
| The review lens (#97) | one subagent that does not see the conversation, `model: "opus"`, effort of the review's level, at least `high` | It runs at each `high` and `xhigh` review, and at each review that touches the architecture file or an ADR; `fable` costs 2.5 times as much. |

Codex reads the whole branch at `xhigh` already, with a prompt for defects
only. #99 checks whether Codex with the lens prompt finds what the Claude lens
misses. It gets the lens only when it does.

## The review lens (#97)

Only in a project that has an architecture file or an ADR folder, as
*The project's files* finds them. There, one review subagent reads the range
of round 1 of `kalinichenko:review-loop` against them, once, beside round 1,
for `high` and `xhigh` changes, and for any change that touches the
architecture file or an ADR, as a `medium` change that adds a dependency and
its ADR, or a change to documents only, which review-loop gives no level. Its
effort is the review's level, and `high` when that level is lower or there
is none. Elsewhere it does not run, so a review in
another repository costs nothing more; the reuse angle of `/code-review`
covers part of the copies there. Instead, review-loop's summary says once per
pull request, in one line and with no subagent, that
`kalinichenko:architecture` can write the first file, unless the project's
`CLAUDE.md` says that it keeps none. So a project that never loaded the skill
still hears of it.

The lens runs `invariants.sh --new-since <base> HEAD` first. Each `new` hit
is the branch's. When the branch left the invariant as it was and moved no
file into or out from under a path of its `debt` list, a FAIL with no `new`
hit was on the base already: it is a finding outside the task, an issue
through `kalinichenko:github`, or one already filed. Otherwise `new` does not
tell all of the branch's hits: the lens compares the head's output with that
of `invariants.sh <base>`, which reads the base's own architecture file. Then
it runs
`clones.sh` on a read-only checkout of the head, keeping the clones that touch
a file the branch changed. Its findings:

- a second structure beside an existing one. A change that follows the
  project's own way, by *Consistency first*, is not one, even when that way
  breaks a principle;
- a module that uses another not through its public API, or against the
  direction, or in a cycle;
- a `new` hit, cited as `I-n`: each one under a FAIL, and each `grep` hit
  under the known debt of a PASS, as a second `fetch(` call in a path of the
  `debt` list. An ADR that amends the invariant changes its check, so it
  leaves no FAIL to excuse;
- a decision that needs an ADR, and has none;
- a change against an accepted ADR, with no ADR that supersedes it, or an
  edit past its Status line of an ADR that exists at the base;
- a passage of `docs/ARCHITECTURE.md` that the change made false;
- a file or a module that the branch grew past its limit, with no split and
  no debt issue; or a path of a `debt` list that the branch grew when its
  split only moves code, which *When to split* puts into this pull request;
- a copy of existing code that the three conditions say to extract;
- a shared helper with a flag or a branch for each caller.

The findings go through *The findings* of
review-loop. `tests/review_loop_eval.sh` counts the lens apart from the
rounds. #60 keeps the tests lens and the task lens.

## The debt map (#98)

Step 2 of `kalinichenko:debt` also runs `invariants.sh` in its `<tree>`. Each
FAIL is a broken rule whose issue cites `I-n`. A path of the `debt` list of a
`grep` check is a broken rule too. A path of the `debt` list of a `lines` or
`files` check is a hotspot, weighed by the debt skill's own rule for a place,
read for a folder as for a file: a place, or *next*. An invariant with no `Check:` line is named
in the report. Step 4 sorts each clone place by the three conditions of
*Decomposition*: a place that fails one is a copy kept on purpose, named in
the report and not filed. `docs/ARCHITECTURE.md` is the
project's own file, so the debt skill still carries no rules of its own
(PR #58).

## The dependency graph (#100)

A soft dependency. A trial on a fixture first: codebase-memory-mcp 0.12.1
(162 languages through tree-sitter, no build) against dependency-cruiser on a
TS tree with path aliases. The same edges: take codebase-memory-mcp. More
missing or wrong edges: take the set per language, dependency-cruiser for
`package.json`, `ruff analyze graph` for Python, `go list -json` for `go.mod`,
and skip the rest with a line that says so. `graph.sh <tree>` follows the shape
of `clones.sh`: a pinned version, in a private directory, on a copy of the
code files, with no package manager and no script of the project in the
project's tree. Each tool has its own runner, and an absent runner gives a
`skipped:` line:

- codebase-memory-mcp: `npx` or `bunx`, as `jscpd` in `clones.sh`;
- dependency-cruiser: `npx` only, with a pinned `typescript` beside it, as
  `npx -p typescript@<pin> -p dependency-cruiser@<pin> depcruise`: without
  it, dependency-cruiser reads no `.ts` file. `bunx` keeps only the last
  `-p`, so with no `npx` the tool gives a `skipped:` line. It runs with
  `--no-config`, so
  the project's `.dependency-cruiser.js`, which the copy holds as code, never
  loads. When the copy has a `tsconfig.json`, it gets `--ts-config` for the
  path aliases. When it fails on that file, as on an `extends` of a package
  (`@tsconfig/node20`) or of a generated file (`.svelte-kit/tsconfig.json`)
  that the copy does not hold, it runs again without it and prints a line
  that the edges through path aliases are missing. Which `tsconfig*.json`
  holds the aliases, as `tsconfig.app.json` behind a `tsconfig.json` with
  only `references`, the trial settles;
- ruff: `uvx ruff@<pin>`, when `uvx` is on `PATH`;
- `go list`: the `go` on `PATH`, with no network and no other toolchain
  (`GOPROXY=off`, `GOTOOLCHAIN=local`). A module that is not in the cache, or
  a `go` line of `go.mod` newer than the local `go`, gives an error line, not
  a download.

Unlike `clones.sh`, the copy keeps the files that the tools read as data and
that `data.ere` leaves out: each `tsconfig*.json`, because one can extend
another, as `tsconfig.base.json` with the path aliases; `go.sum`;
`pyproject.toml` (`go.mod` is code to `data.ere`, so the copy has it
already). The trial gives both tools the same copy. Its uses: the codemap of
a first
`docs/ARCHITECTURE.md`, the edges and cycles that a branch adds, the cycles in
the debt map, and the check "A does not import B".

A second graph, from history, with no tool past `git` and `awk`: change
coupling. Files of different modules that often change in the same commits
show a wrong border: one rule of the product that lives in several modules.
A script in the shape of `measure.sh` prints the pairs of modules, with the
count of shared commits in 60 days. Its uses: the decomposition at the
decision, the debt map, and the modules of a first `docs/ARCHITECTURE.md`.

## The measurement (#99)

An eval in the shape of `tests/skill_load_eval.sh`, outside `make check`, with
its checks run in `make check` on one recorded run. A fixture with one module
that wraps every HTTP call, and four arms: no file and no skill; the file and
a link from `CLAUDE.md`; the same and the skill by its description; the same
and the `CLAUDE.md` line. It counts the runs that use the wrapper, the runs
that load the skill before the spec or the first edit, the runs that write the
block of *The start of a feature*, the runs that write one
ADR for a task that needs a new data store, and the runs that split a file
past its limit first. It also compares `sonnet` with `haiku` for the search,
and the Claude lens with Codex. The numbers can close #87, cut the skill down
to the ADR rules, or decide again the line in `CLAUDE.md` (#99 has the rules).

## Order

1. #96: the skill, `invariants.sh` and its test, this document.
2. #97 and #98, in parallel: each changes another skill.
3. #100: the import graph and its kind of check, and change coupling.
4. #99: the measurement, after #97, because it compares two lenses.

## Left to the builder

- The text of `SKILL.md` and its description, written with the
  `superpowers:writing-skills` skill. #99 measures whether the description
  loads it.
- Whether the skill keeps its parts in one `SKILL.md` or in files beside it,
  as `github` keeps `take-in.md` and `filing.md`.
- The exact syntax of a `Check:` line, within *invariants.sh* above: one line,
  read by the script without a shell, the pattern in backticks or another
  quote that holds spaces. A long `debt` list goes on indented lines right
  under it, each `debt` and one path, so that no such line looks like the
  `ADR:` line.
- The layout of the ADR template, within the fields above.
- The README of the skill, and its line in the plugin README.
