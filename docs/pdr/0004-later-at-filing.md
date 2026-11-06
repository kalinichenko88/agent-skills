# 0004 Filing puts a low finding straight into Later

- Status: rejected
- Level: feature
- Date: 2026-11-06

## Decision

We will not give an out-of-scope finding a class of its own for low
severity. Filing sets no `Later` milestone and no priority label: a low
finding is filed as any other finding that is not a nit, and triage gives
it its milestone. A low finding is no nit: a comment that says something
false, or working code with no test, is filed (`skills/github/filing.md`).

## Rests on

- On 2026-11-06, each of the 6 open out-of-scope findings of this tracker
  has a milestone, put there by triage: the low ones #76, #147, #168 and
  #179 in `Later`, #197 and #227 in M3. The saving is one row of the triage
  approval for each low finding.
- An open issue with a label and a milestone is not in the list that triage
  reads (`skills/roadmap/triage.md:35-38`). A low finding filed into
  `Later` with a label would never be triaged.
- A task goes into `Later` only after the person says so
  (`skills/roadmap/SKILL.md:151`, `skills/roadmap/README.md:40`). The
  milestone is the importance, and no priority labels (PR #110).
- Of the 54 issues that hold a filed out-of-scope finding, 48 are closed,
  with a median of 0 days to close: no backlog of findings waits for
  triage.

## Revisit when

A tracker that uses craft holds more open low findings with no milestone
than one triage approval can take.

## Options considered

- `--milestone Later` at filing, and a low label where there is no `Later`
  (#260): one triage row less for each low finding, against two decisions
  of roadmap and an issue that triage never lists.
- Filing as before, with triage placing each finding: no change for a low
  finding.

## Links

#260, PR #110, `skills/github/filing.md` *No free host*, `skills/roadmap/triage.md` *Label and milestone*
