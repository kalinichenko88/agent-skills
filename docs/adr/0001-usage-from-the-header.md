# 0001 Each script prints its usage from its header

- Status: accepted
- Date: 2026-10-26

## Context

Each script in `skills/*/scripts/` writes its calls in its header, as
`#   name.sh <args>` lines (pattern 1). Its `usage` printed them in three
ways. `collect.sh` read the lines of its own header with `sed`. `plan.sh`
repeated its eleven lines in a heredoc. The other 12 scripts repeated them in
one `echo`. On 2026-10-26 the header and the `usage` agreed in all 14 scripts.
But a change to the arguments had to change two places, and nothing checked
that they agreed. An agent that added a script saw three ways and no rule
(#121).

## Options considered

- The `sed` of `collect.sh` in each script: the header is the only source of
  the calls.
- One `echo` in each script, as 12 of 14 had: two places for each change, and
  a check of them needs a test that reads each header, which is the `sed`
  again.

## Decision

We will print the usage of each script from its header, with one line that is
the same in each script:

```bash
sed -n "s/^#   ${0##*/}/usage: ${0##*/}/p" "$0" >&2
```

## Consequences

Good: a change to a call changes the header only. The line has no name in it,
so a copy cannot print the calls of another script.

Bad: `usage` reads the script through `$0`. A script that changes its
directory, as `measure.sh` and `invariants.sh` do, must call `usage` before
it. A header line with words after its arguments, as in `read.sh`, prints
these words too.

## Invariants

None.

## Confirmation

Review only. `tests/github_scripts_test.sh`,
`tests/roadmap_scripts_test.sh` and `tests/architecture_scripts_test.sh`
check the usage of `collect.sh`, `plan.sh` and `invariants.sh`.
