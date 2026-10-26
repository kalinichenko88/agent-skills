# Global instructions

## The repository's own gate (always)

Before claiming a task done, run the repository's own check command — the single
target that chains lint, typecheck and tests (`make check`, `bun run check`, the
`check`/`ci` script in `package.json`, whatever CI calls). If there is none, run
the closest equivalent and say so. Report the actual outcome — "should pass" is
not a result.

## A bug fix ships with its test (always)

Every bug fix carries the test that would have caught it: written before the
fix, seen failing against the unfixed code, passing after. It asserts the
behaviour that was reported, not the internals of the fix.

If the bug shows on several surfaces, guard each one. Fixing the surface the
report named and leaving its siblings is how the bug comes back under a new
name.

**The input comes from the source, not from your head.** Red-then-green proves
the test exercises the code. It does not prove the case exists. A guard built on
an input the real source never emits goes green forever while the real shape
stays unchecked — and the fix underneath it can be doing nothing, or harm.

So before the report is even believed, count it: pull a sample of real payloads
and say how many carry the shape. Zero means the fix does not need to exist, and
that is the finding. Then write the case against a recorded payload — whitespace,
pretty-printing and all — not a string typed to make the assertion pass.

In Claude Code, a Haiku subagent does the counting: one `Agent` call with
`subagent_type: "Explore"` and `model: "haiku"`, given the source, the sample
size and the shape. It returns the count and the ids that carry the shape. Fetch
one or two of those payloads yourself, check the shape on them, and write the
case against one.

Measured, the one time this was skipped: a "list items run together" bug, filed
off a hand-written `<li>a</li><li>b</li>`, tested green, shipped. The sources
turned out never to emit two block tags without whitespace between them — 0 of
100 bodies — so the fix changed no table it claimed to fix and put a blank line
inside 6 of 10 real lists. The test was green over data that never moved.

## Use the platform before reaching past it (always)

Whatever the project runs on — Node, Bun, Deno, Go, the browser — check what its
standard library already does at the version the project pins, before writing a
helper by hand or adding a dependency. Runtimes ship faster than training data:
verify against current docs (context7, the release notes), not memory, and take
the newest API the pinned version actually supports.

`Intl.NumberFormat` instead of a hand-written currency formatter,
`structuredClone` instead of a deep-clone package, `slices`/`maps` instead of a
copied generic helper. A dependency earns its place only where the platform has
no answer — name the API you checked before concluding that.

## Code speaks English (always)

Inside the code everything is English: identifiers — variables, functions,
types, files, branches — and every comment, docstring and TODO. This holds in
every project, whatever language the team speaks. Mixed-language symbols are
ungreppable and split a codebase into dialects.

Another language appears only in the data layer: user-facing copy, translation
catalogues, fixtures and seed data, and values that simply *are* text in that
language. The key stays `greeting.ru`; the string it holds does not have to be
English.

Commit messages are English too, in every repository. They are the log of the
code: `git log` and `git blame` are read long after the team that wrote them,
and a history in two languages is as ungreppable as a codebase in two.

The rest of the prose — README, docs, issues, PR titles and descriptions — is
the project's own call. Match what the repository already does rather than
imposing English on it.

## Plain technical prose (always)

Write like ASD-STE100, the Simplified Technical English of aircraft maintenance
manuals. This applies to all prose: replies, docs, comments, commit messages,
issues. The same rules apply in other languages.

- Write short sentences.
- Use each word only in its direct meaning.
- Do not write text that can have two meanings.
- Do not use complex grammar.

## Docs move with the change (always)

A change that alters user-visible behaviour, a public contract, or how the thing
is installed updates the documents that describe it — in the same change, not a
follow-up. README, the project's instruction file, API docs, ADRs: whichever
ones now say something false.

- Before finishing, name the docs the change touched, or say "docs impact: none"
  with a one-line why. Saying nothing is not an answer.
- In Claude Code, the same kind of subagent finds them: give it what the
  change alters — behaviour, names, commands, install steps — and the files it
  changed. It returns each passage that is now false as `file:line`, the
  sentence and why, or "none" with the files it read. The edits are yours.
- A follow-up is allowed only for a broader sweep the change merely brushes
  against — never for the document that describes the very behaviour changed.

## Code review (always)

Before the first review of a change — `/code-review` or `/security-review` in
Claude Code, `/review` in Codex, a review subagent — and when a person's review
comments arrive, invoke the `kalinichenko:review-loop` skill. It sets the
level, what each round reads and when the rounds stop, the security review,
which findings to fix or decide without asking, and the summary at the end. A
read-only review subagent does not load it. An agent that acts on a
finding, with the skill or without it, first verifies it against the real
code: a confident wrong fix is worse than the defect.

## The Boy Scout Rule (always)

Leave the code you touch cleaner than you found it. The rule is the Scouts'
campground rule as Robert C. Martin put it in *Clean Code*: every check-in
leaves the module a little better than the check-out found it, and a codebase
that only ever receives that kind of care does not rot.

It covers the files the task edits and the files next to them in the same
module: the module as the project's instruction file or a conventions skill
draws it, or else the directory of a file the task edits. A finding there, from
a stale comment or a broken link to a bug in the next function, goes into this
change when it meets three conditions. It is clear: there is one way to fix it,
and nothing outside the module relies on what it changes. It is smaller than
the task's own diff, and all such fixes together are smaller too. Dropping it
leaves the task whole. A bug brings its test. A test belongs to the module of
the code it tests, wherever it lives. List each one in the PR description as
not part of the task. A finding that fails one condition is an issue. Cleaner
than you found it is not the same as rebuilt.

## Code conventions (always)

Before the first write or edit to a TypeScript file (`.ts`, `.tsx`, `.mts`,
`.cts`) in a session, invoke the `kalinichenko:typescript-conventions` skill.
Before the first write or edit to a React component or hook, invoke
`kalinichenko:react-conventions` too. A subagent invokes them itself.

## GitHub (always)

A commit message, a pull request, an issue, a workflow file — anything that
touches a repository's GitHub surface goes through the `kalinichenko:github`
skill. Invoke it before the first `git commit`, `gh` call or workflow edit, not
after: it carries commit trailers, PR ownership and merge style, issue filing,
keeping issues true as the code moves, which open issues ride along with a task,
and action pinning. A read-only subagent, as a review or a Haiku subagent
above, files nothing, whatever the rules below say. It does not load the
skill. It names each finding in its report, and the agent that sent it decides
on each one. One sent with the skill's `scout.md`, or with the roadmap skill's
`lanes.md`, follows that file instead.

Three rules stay here in full, because they have to fire when nobody is thinking
about GitHub at all.

**Out-of-scope findings become issues.** Anything worth fixing that is **not**
part of the current task — a bug, a latent defect, an improvement worth making
later — gets filed as an issue instead of being fixed inline or dropped in the
chat. Do not derail the task to fix it; do not ask first. If the Boy Scout Rule
above takes it, it goes into the current PR instead, listed in the description
as not part of the task. The skill draws that
line and carries the how: a search of the tracker first, adding to an open
issue on the same code before opening a new one, existing labels only, and every
number listed in the final report. Where there is no GitHub remote or
`gh auth status` fails, name the finding in the final report instead.

**A defect in this plugin goes to its tracker, after the person says yes.**
These rules, the hooks, a `kalinichenko:` skill and its scripts are the plugin.
One of them can be wrong: a script fails on valid input, two rules say opposite
things, or a rule followed as written gives a wrong result. That is an issue
for `kalinichenko88/agent-skills`, not for the project you work in. In a
checkout of `agent-skills`, the rule above applies instead. A step you skipped
is not a defect. Do not derail the task. Unlike the rule above, ask first: show
the person the title and the body, with nothing from their project in it, and
file only after a yes. The skill's `filing.md` carries the how.

**Never add a `Co-Authored-By:` trailer** to a commit message — no Claude, no
model name, no `noreply@anthropic.com`.
