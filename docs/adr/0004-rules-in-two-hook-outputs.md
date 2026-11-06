# 0004 rules.md reaches the session in two hook outputs

- Status: accepted
- Date: 2026-11-06

## Context

`rules.md` is the base prompt. `hooks/rules.sh` gave it as one
`additionalContext` on SessionStart and SubagentStart. Claude Code caps one
such string at 10,000 characters. Over the cap, it saves the text to a file,
shows a preview of 2,000 characters, and does not ask the model to read the
file. `rules.md` had 9,941 characters, as `tests/rules_test.sh` counts them:
59 were left. #205 waited in Later until a rule with a measured failing run
needed more room. #253 has one: with `rules.md` as on `main`, 0 of 7 runs
corrected the issue that a decision made false, and with one more sentence 5
of 5 did. That sentence puts `rules.md` at 10,000 of 10,000 characters.

The cap is per string, not per event. The Claude Code hooks reference says
that it "measures each string on its own, even when several hooks run for the
same event", and that "Claude receives all of the values". Codex limits each
hook-output message to about 2,500 tokens by default, and checks each handler
on its own. `rules.md` was 2,362 tokens (`o200k_base`), so it was near the
Codex limit too.

## Options considered

- One file, two hook outputs: a marker line splits `rules.md`, and
  `hooks/hooks.json` runs `rules.sh` once for each part. The room grows to
  about 10,000 characters, and each mention of `rules.md` stays true.
- Two files: the same room, but 88 mentions of `rules.md` in 26 files need
  a check, and the sentence checks of `tests/rules_test.sh` name two files.
- Move the general habits, about 6,200 characters, into skills: a habit that
  must hold in each turn then fires only when a description matches, and
  each habit needs an eval of its own.
- Shorten in place, as PR #163 did: it frees a few hundred characters, and
  the cap comes back after one or two rules.

## Decision

We will keep `rules.md` one file and give it in two parts. The line
`<!-- rules.sh splits the rules here: each part stays under 10,000 characters -->`
stands between two sections. `rules.sh <event> 1` gives the text before it,
and `rules.sh <event> 2` the text after it. `hooks/hooks.json` runs both for
SessionStart and for SubagentStart. The marker stands before *Code review*:
part 1 holds the general habits from the gate to the docs, and part 2 the
calls of the plugin's skills, the Boy Scout Rule and the trailer rule. Each
part starts with a heading of its own, as
"# Global instructions, part 2 of 2", so that a part that comes after the
context of another plugin is not read as a part of it.

A host runs the hooks of one event in parallel and gives no order: in two
runs of Claude Code 2.1.319, part 2 came first. So no text points across the
marker with "above" or "below".

## Consequences

Good: part 1 has 5,416 and part 2 has 4,585 of 10,000 characters, so a new
rule has room in either part. No rule leaves the always-on prompt. Each part
is far under the Codex limit of about 2,500 tokens: about 1,300 and 1,100.

Bad: `hooks/hooks.json` changes, so the release is major and Codex users
trust the hooks again. Each session and each subagent pays for each rule
added, and no cap stops the total before 20,000 characters. A third part
needs another change of `hooks/hooks.json`. An editor puts a new rule in the
part that has room, not only where it reads best. The test counts characters,
not tokens: at 4.2 characters a token, a full part of 10,000 characters is
about 2,380 tokens, near the Codex limit.

## Invariants

None. The *Size* concern of `docs/ARCHITECTURE.md` changes from the file to
each part.

## Confirmation

`tests/rules_test.sh`: for each event, each part stays under 10,000
characters, the two parts and the marker line rebuild `rules.md` byte for
byte, each part starts with its own heading, and `hooks/hooks.json` runs
`rules.sh` under each event with that event and parts 1 and 2. With no part,
`rules.sh` stops with an error, not with the whole file.
