# 0003 The flows are specified as host-neutral scenarios in scenarios/

- Status: accepted
- Date: 2026-11-03

## Context

The flow skills (github, roadmap, review-loop, product) say what they do only
as instructions to an agent in Claude Code or Codex: send a subagent, run
`gh`, run `/code-review`. Nothing says what a flow does apart from how one
host does it (#231).

The take-in of the github skill shows the cost. `skills/github/take-in.md`
changed in 15 commits from 2026-10-19 to 2026-11-03. `tests/github_scripts_test.sh`
runs `take-in-check.sh` on 12 states of an issue, but no test checks what
the model does with them: the messages to the person, and the order of the
writes. The evals that do run the model mix what the person sees with how
one host does it: `tests/review_loop_eval.sh` checks "at most three rounds"
and "/security-review in a subagent" side by side.

The person intends a second implementation of the flows: an agent loop on a
server, with no shell, which keeps its own tasks and reaches GitHub through a
connector. No repository or date records it yet.

The README of a skill and the pictures in `docs/<skill>/` already show a flow
to a reader, in sections named "scenario", with Claude Code words in them.

## Options considered

- Scenarios in a folder of their own, `scenarios/`, beside `skills/`: one
  Markdown file for each flow, four labels (Given, When, Then, Never) for
  each scenario, and the terms in `scenarios/TERMS.md`.
- The same files under `docs/scenarios/`: as cheap, but `docs/` holds the
  documents about craft, and a scenario is the text that craft is checked
  against.
- A "Scenarios" section in each `SKILL.md`: one place to edit, but another
  implementation then reads the text of the skills, and a host word sits a
  line away from the scenario.
- The cases of an eval, in the header and the task strings of a
  `tests/*_eval.sh`, as the other evals keep them: no new folder, but the
  cases then name the fake and the host of that eval, and another
  implementation cannot use them.
- Gherkin `.feature` files: a known form, but its tooling gives nothing to
  another implementation, and gherkin-lint had its last release, 4.2.4, in
  2023.
- Scenarios in a repository of their own: each implementation pins it, but
  a change of a flow then needs two pull requests. Of the last 30 commits
  that change `skills/` or `rules.md`, about 15 change what the person sees.

## Decision

We will keep the scenarios in `scenarios/`, one file for each flow, at
`scenarios/<skill>/<flow>.md`, in the shape that `scenarios/README.md` gives.
A scenario takes the words for a thing that an implementation keeps in its
own way from `scenarios/TERMS.md`, and names no agent host, no command and
no subagent. craft is one implementation of them, and
`tests/scenarios_eval.sh` checks craft against three of them. Where the
README of a skill or a picture differs from a scenario, the scenario holds.
The conventions skills get no scenarios: their text depends on no host
already.

A probe ran on 2026-11-03, before this decision: three take-in scenarios,
one `claude -p` run each, with a fake `gh` over a JSON tracker. Each run
cost $0.28 to $0.80. The fake reached the session. The eval checks each of
the 17 Then and Never items of the three scenarios, one check each, from the
tracker, the branches, the workspace, the tool calls and the messages. 15 of
the 17 checks gave a verdict. A message that ends a run was in its log as
text. A message that comes before a tool call can reach the log only as
thinking in other words, without the task's id and title, as #206 found.
In that case the log cannot show what it told: the two checks of the gist of the
free task gave no verdict.

## Consequences

Good: a pull request that changes what a flow does can change its skill, its
scenario and its test together. Another implementation has a text to follow
that names nothing of craft. The probe checks what the script tests cannot:
the model's writes, their order, and the messages that end a run. A move
into a repository of its own stays cheap, with `git subtree split`.

Bad: a change of a flow now edits two texts, and only the review ties them.
`TERMS.md` repeats some meanings that a skill holds too, as *busy* in
`skills/github/tracker.md`: another implementation reads only `scenarios/`.
A message before a tool call cannot be checked from a Claude Code log. The
shape fits a flow that a message of the person starts; a flow that the run
starts itself, as the filing of a finding, needs a When of another kind. The
word "scenario" also names the picture sections of the READMEs. The first
file covers only the take-in of the github skill, and the folder installs
with the plugin.

## Invariants

None. `scenarios/` holds Markdown, which the checks read as data.

## Confirmation

`tests/scenarios_checks_test.sh` checks that each scenario that the eval
names is a heading of `scenarios/github/take-in.md`. The rest is review
only. A grep in the `lint` target of the `Makefile` is the place for the
rule that a scenario names no agent host, as for the other forms that a set
of files may not hold. The person chose no check of the words of a scenario
for now (#231): it comes with the check of the shape.
