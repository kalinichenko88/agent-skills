# The product skill — design

Date: 2026-11-02. Status: design, approved for planning when the person says
so. Issue: #200. Related: #216 (the architect's half, in Later), #205 (the
room in `rules.md`), #171 (the block of *The start of a feature*).

A new skill in the `kalinichenko` plugin, `kalinichenko:product`. It is a
skeptical analyst. Before work starts, it asks whether the task is worth
doing, and in which form: not from the code, but from the cost, the money,
the direction of the project, the law, the client and the risk of failure. It
searches the web, looks from several sides, and may propose another way, a
deferral or a close. It questions accepted decisions too, when they start to
get in the way. It keeps the project's product decisions in `PRODUCT.md` and
`docs/pdr/`, as the architecture skill keeps `ARCHITECTURE.md` and
`docs/adr/`. It works in Claude Code and in Codex.

**Problem:** An agent builds a capability that nobody checked for its worth,
and a review then polishes code that is removed later.
**Needs solving:** Measured on this plugin's current text (Opus, 5 runs per
shape, see *Measurement*): in 5 of 5 runs, a review of a branch went to round
1 with no question about worth; in 1 of 5, a round that proved the feature
gives nothing made the agent rebuild it. The person's own case: a feature
that no agent stopped, the architect included, and that a human analyst
stopped. On two private trackers, 18 of 126 open issues and 5 issues wait on
a decision, not on code; 10 of the 18 are decisions about the whole project,
and 2 of the 5 wait on a lawyer. Without it, the agent keeps building what
the person later removes, and nobody re-checks a decision once it is made.
**Simplest way:** Extend what exists, then a new skill. The architecture
block already asks "Needs solving" and "Simplest way" (`skills/architecture/SKILL.md:65-66`),
and no run of #171 wrote it. #200 also offered two lines in that block and a
step 0 in review-loop. Simpler alternative rejected because: the person needs
a web search, a second model family, decisions about the whole project, a
store of decisions and a re-check of accepted ones. Two lines in the
architecture block hold none of these.
**Touches:** `skills/architecture/SKILL.md:36-83` *The start of a feature*;
`skills/architecture/SKILL.md:397` its first red flag;
`skills/review-loop/SKILL.md:79` *Over-engineering first*;
`skills/review-loop/SKILL.md:346` step 4 of *The findings*;
`skills/review-loop/SKILL.md:465` *A spec and a plan*, the two-reader pattern;
`skills/roadmap/SKILL.md:148` *Putting a task off*;
`skills/architecture/first-file.md` the offer to write a first project file;
`rules.md:108-123` the lines that send to review-loop;
`docs/ARCHITECTURE.md:58-93` *Modules* and *Direction in text*.

## Why

The person works on features in domains that they do not know to the end.
The decisions pull three ways: what the client wants, what the law allows,
and where the project goes. A mistake on any of them is costly. Follow the
client against the law: a legal risk. Follow the law against the client: a
conflict. Follow both against the direction: code that is removed later.

Decisions come at two levels:

- **The project:** distribution, the licence, open source or not, the money
  model, the hosting.
- **The feature:** each capability, and each change of what the product does.

A human analyst helps in three ways that no agent of the plugin gives now:

1. It asks whether to build at all, and proposes a smaller, other or later
   way. "Close" and "defer" are good answers.
2. It brings facts from outside the code: prices, limits, terms of service,
   the text of a law, how others solve it, known failures.
3. It questions even an accepted decision when that decision starts to get
   in the way.

Prior art:

- A private red-team skill for strategy documents. Taken: the load-bearing
  claims, "steelman, then attack", "fails if", the rank by impact, likelihood
  and cheapness of a test, the cheapest test, the kill criterion, "what is
  well reasoned", "what I could not assess", and a second model as an
  option. Not taken: it runs only on request, only on strategy documents, and
  searches nothing.
- A private research note that checked a client's wish against a national
  law on unfair competition and an EU directive, with court cases, and
  recommended another way. This is the work of the skill, done once, on
  request.
- Three private decision stores: one file of 66 decisions in 754 lines,
  grouped by topic, with revision dates; one note per decision with
  `status`, `review_due` and `confidence`; a list of 14 open questions to a
  lawyer. The store below takes the numbered list, the condition to revisit,
  and the open questions from them.
- Gary Klein's pre-mortem: "half a year on, the feature was removed; why?".
- Amazon's one-way and two-way doors: the cost to undo decides how much care
  a decision needs.

## Goals

1. At each moment of the table in *When it runs*, the skill gives a report
   with a verdict and its proof, before the work it judges.
2. Each claim in a report has a number, a `path:line`, or a source. A claim
   with no proof says "no proof found".
3. The report gives at most three options, the recommendation first, and the
   questions for the people who can answer them: the client, a lawyer, the
   person.
4. The person decides. The skill never refuses or cancels the work. A
   verdict other than "do it" is a question to the person, and the work it
   judges waits for the answer. With no person, as in a run that a script
   starts, the work goes on as it was asked, and the question stays open in
   the summary and in the pull request's description. (The agent's call.)
5. Each decision the person takes at the project or feature level goes into
   the store, with what it rests on and when to revisit it.
6. When a task touches an accepted decision, the skill checks it again, and
   proposes to revisit it when its ground no longer holds or it got in the
   way twice.

## Non-goals

- How the code is built: the architect's work (`kalinichenko:architecture`,
  and #216 for its own skepticism).
- A legal opinion. The skill cites the law and the cases and names the
  question for a lawyer. It never says that something is legal.
- A store of the code's decisions: ADRs stay as they are.
- Moving the person's existing stores in their projects: each project does
  that as its own task, when the skill offers it.

## Anti-goals

The agent's guess, which the person did not correct: a skeptic that adds
minutes to each task and writes general risks instead of concrete ones. Then
the person turns it off. So: no report line without proof, no empty field,
the light depth wherever the table allows it, and the full panel only at the
moments that need it.

## Constraints

- The repository is public. The text of the skill, its examples and its
  fixtures use neutral shapes only (`kalinichenko:github`, *Public
  repositories*).
- `rules.md` has 9,663 of its 10,000 characters, as `tests/rules_test.sh`
  counts them: 337 are left (#205).
- The text of a skill is the product, and no `Check:` line sees it (`docs/ARCHITECTURE.md`).
  I-8 and I-9 hold for any script or test the skill adds.
- Two hosts. Codex has no subagent with a model, and no Fable: it does each
  subagent step itself.
- Superpowers is another plugin. Its text does not change: the moment in
  brainstorming comes from this plugin's own text.
- A rule needs a failing run before its edit (#186). The measurements below
  give one for each new rule, or the rule waits.

## What the person decided

These are the person's decisions, in the conversation of 2026-10-29 to
2026-11-02.

- A separate skill, named `kalinichenko:product`.
- The criteria are not code: the work it costs, the money, the direction of
  the project, the risk of failure, and others (*The criteria*).
- It searches the web and looks from several sides. Another way, a deferral
  or a close is a good answer.
- It questions accepted decisions when they get in the way.
- It runs several models in parallel. The person named Fable, Opus and
  Codex; the person accepted Fable and Codex as the readers, with Opus in the
  main session to merge them (*The panel*).
- It works at the project level and at the feature level, and balances the
  client, the law and the direction.
- On a new project, or when the person asks, it builds its own store in a
  set format. Otherwise it uses the store the project has.
- The store is an index file and one file per decision, as ARCHITECTURE.md
  and its ADRs: `PRODUCT.md` and `docs/pdr/NNNN-title.md`. One file for all
  decisions was rejected: it grows, and the skill would read it whole at
  each run.
- The system files of the plugin are in capitals, to mark them as system
  files: `ARCHITECTURE.md`, `PRODUCT.md`. The records stay in lower case, as
  ADRs.
- The store lives in each repository, not in an outside notes vault.
- A PDR says what and why; an ADR says how in code (*PDR and ADR*).
- The moments and the depths of *When it runs*, and the report of *The
  report*: shown to the person, with no change asked.
- The architect's own skepticism, about what the system pays for a change,
  is #216, deferred to Later.

## When it runs

| Moment | Depth |
| --- | --- |
| The start of a feature: a new capability, or a change of what the product does | full |
| A bug fix | none; light when the fix changes business logic |
| A review of someone else's branch or pull request | full |
| A review of the person's own branch | none when a report for it exists; else as at the start of a feature |
| A fork in brainstorming: a question that chooses between ways | light; full when the fork is at the project level |
| A new project with no store, or the person asks | builds `PRODUCT.md` and `docs/pdr/`, after a yes |

**The trace**, for the person's own branch: a report exists when the spec of
the work, the pull request's description, the issue, or a PDR that the branch
adds holds the report's `**Verdict:**` line. The test is the trace, not the
author: a branch of the person's with no report at its start gets one at the
review. A review of someone else's work always runs, and it reads their spec
and their description as the decisions to check. Someone else's work is a
pull request whose author is not the account that `gh` is logged in as, or,
with no pull request, a branch whose commits have another author's email
than `git config user.email`, as the github skill's `you`. (The agent's
call.) A report at the review goes into the pull request's description, so
that the next review finds it.

**In brainstorming**, the skill runs only at a fork, as "which of these two
ways", never at a question that asks the person to describe. It gives the
person better options for the question, and it may find that the
conversation went the wrong way. The answer stays the person's.

**Depths.**

- **Light.** The main session alone, with no web search. It reads the index
  of `PRODUCT.md` and the PDRs that the task touches. The report has the
  verdict and its reason; another field only when it has content.
- **Full.** The panel: two readers in parallel, each with a web search, and
  neither sees the other's answer. The main session merges them.

## The run

1. **Find the store.** `PRODUCT.md` at `docs/PRODUCT.md`, or at the root
   when the project keeps its docs there, and `docs/pdr/`. With neither,
   look for the project's own decision files by name, as a decisions file, a
   product or requirements document, a list of legal questions. With one in
   another format, use it as it is. With none, the offer of *A new store*.
2. **Understand the task.** Who has the problem, how many of them, and how
   others solve it. At the full depth, with a web search and links.
3. **Collect the three sides.** The client: what they ask, and the goal
   behind it. The law: the rules that apply, with the primary source, and the
   question for a lawyer where one is needed. The project: its direction, its
   milestone, the decisions the task touches.
4. **Show the conflicts** between the three sides. Do not smooth them.
5. **Check the criteria** and run the checks, below.
6. **Check each decision the task touches:** does its ground still hold, did
   its condition to revisit come, did it get in the way twice.
7. **The report**, then the person's decision, then the store.

### The criteria

- **The problem and its proof.** Who has it, and how many by real data: "7 of
  1000", not "it happens".
- **Benefit against cost.** The share of users who gain, against the hours of
  work, the review rounds and the upkeep.
- **Money in operation.** What grows with what: per entity, per user, per
  view, per month. A call to a paid API on each view.
- **Failure.** What happens when an outside service fails or slows. Whether a
  new point of failure sits on a path that all users take.
- **Shared and fragile resources.** A shared outgoing IP, quotas, rate
  limits, undocumented behaviour of another service.
- **The law and the data.** Terms of service, `robots.txt`, trademarks,
  personal data that goes to a third party, the client's contract.
- **The direction.** Whether the task fits the direction in `PRODUCT.md` and
  the milestone. What waits while this is built.
- **Cost to undo.** A two-way door or a one-way door. A flag, an experiment.
- **Upkeep.** Who owns it, and how often it will break, as a parser of
  another site's HTML.
- **How we know it works.** The measure of success, and the line below which
  the feature goes.
- **The decisions it touches**, by step 6.

### The checks

- The count against the real source, as the global prompt sets it.
- A web search: ready solutions, prices, limits, terms, the text of a law,
  known failures and postmortems of the same idea.
- A calculation on the back of an envelope: requests a day times the price,
  the growth in a year.
- The pre-mortem.
- The best case for doing nothing, then the ladder: nothing → a setting →
  what exists → compute once and store → a manual process → buy → build.

## The report

The labels are English in every project, as the ADR template. The content is
in the language of the conversation. An example, on the fixture of
*Measurement*:

```markdown
**Verdict:** do it another way
**Why:** 7 of 1000 brands have an own icon. The page's CSP `img-src` blocks
their host, so the branch shows none of them in the browser. Each `/logo`
request makes a HEAD call to another server, for 0.7 % of the brands.
**Options:**
1. (recommended) Download the 7 icons once into `public/`: half an hour, no
   new requests.
2. A proxy with a cache: a day of work, new server code, a CSP change.
3. Close: 69 brands keep the placeholder anyway.
**Rests on:** "brand icons change". Cheapest test: compare the 7 files in a
month.
**Questions:** client: do these 7 brands matter, or is the placeholder
enough?
**Readers disagree:** Codex for option 3, Fable for option 1. The person
decides.
**Could not assess:** the traffic of `/logo`: no metrics.
**Sources:** MDN, `img-src`.
```

- The verdict comes first. There are four: do it, do it another way, defer
  until a condition, close.
- A field with no content is left out. **Touches decisions:** names a PDR and
  what changed for it, when the task touches one.
- Each question names who answers it: the client, a lawyer, the person.
- After the person decides, the skill writes a PDR, or adds a line to
  *Got in the way* or *Checked* of an existing PDR (*The store*).
- A verdict "defer until a condition" moves the issue to Later through
  `kalinichenko:roadmap`, with the condition in the issue's text. A verdict
  "close" closes it as not planned through `kalinichenko:github`, with the
  report. Both only after the person says so.

## The panel

- **Fable:** an `Agent` call with `model: "fable"`, which has a web search.
- **Codex:** in the background, from the root of the repository. On Codex CLI
  0.166.0, `codex --search exec -s read-only --ephemeral -` parses;
  `--search` after `exec` does not. Whether the search works inside `exec` is
  checked once in the build. When it does not, Codex reads with no web, and
  the report says so. The prompt ends with the line of *A spec and a plan*:
  "You are one reviewer that another agent runs: start no skill, change no
  file, and file nothing."
- **The brief**, the same for both, in one file of the skill: the task (the
  issue, the spec or the pull request), `PRODUCT.md`, the PDRs the task
  touches, the code facts of the architect's **Touches:** line, and for
  someone else's work, its spec and description as the decisions to check.
  Not the conversation: a reader that sees it argues from it.
- **The merge**, in the main session. It joins the points that say the same,
  and drops none. A point of a reader that goes against what the
  conversation agreed goes to the person as it is: the main session sees the
  task through the conversation, and this is the guard against that. Where
  the readers disagree, the **Readers disagree:** line says so.
- **Fallbacks.** No `codex`, `codex login status` fails, or the run fails:
  Fable alone, and the report says so. On Codex as the host: the main
  session alone, with its own search, since Codex does not call itself (*A
  spec and a plan*), and the report says so.
- **Cost,** for the person's account: Opus is 94 % of the spend, Fable costs
  about 2.5 times Opus, and the Codex plan is about 5 % of the Claude volume.
  So the full depth is for three moments only.

## The store

```
docs/
  ARCHITECTURE.md   the code's structure, the index of ADRs
  adr/0007-….md
  PRODUCT.md        the direction, the constraints, the open questions, the index of PDRs
  pdr/0012-….md     one decision per file
```

**`PRODUCT.md`** holds what the skill reads at each run:

- what the project is, and for whom;
- its direction, and the current goal;
- what it will not do;
- the constraints: the law (where it sells, which rules apply), the client
  and the contract, the money;
- the open questions;
- the index of the PDRs: one line each, with the number, the title, the
  status and the condition to revisit.

```markdown
## Open questions

### Q-3 <the question>
- Answers: lawyer | client | owner
- Blocks: #45, PDR 0012
- Since: 2026-10-01

## Decisions

- [0012 Three plans, monthly billing](pdr/0012-three-plans.md) — accepted; revisit when: payment failures pass 5 %
```

A question that gets its answer becomes a PDR, and its entry leaves the list.

**`docs/pdr/NNNN-title.md`**, one decision per file:

```markdown
# 0012 Three plans, monthly billing

- Status: accepted | revisit | superseded by NNNN | rejected
- Level: project | feature
- Date: 2026-09-14

## Decision

We will …

## Rests on

- <a fact or an assumption>, <its source>

## Revisit when

<a condition that someone can check>

## Options considered

- <option>: <one line>
- <option>: <one line>

## Links

ADR 0021, #45

## Got in the way

- 2026-10-28 #91 <how>

## Checked

- 2026-10-20 <what the check showed>
```

- Numbered after the highest PDR. A number is never used again. A file is
  never renamed or deleted, so a link to it does not rot.
- After the decision is accepted, its text does not change. Only the Status
  line changes, and lines are added to *Got in the way* and *Checked*.
- Two lines in *Got in the way* make the skill propose to revisit the
  decision. Only the person changes its status.
- A reversed decision stays, with `superseded by NNNN`.
- A decision the person rejects for a lasting reason gets a PDR with the
  status `rejected`, so that the next agent does not offer it again.
- A PDR goes in the pull request of the work that it decides. A decision
  with no work of its own goes in a pull request of its own. A new line of
  *Got in the way* or *Checked* goes in the pull request of the task that
  found it.

**A new store.** In a project with no store, the skill offers once a session
to write `PRODUCT.md`, from the README, the docs, the issues and the
person's answers. It writes nothing without a yes, as the first architecture
file. A no ends the offer for the session. A project that keeps no store
says so in its instruction file, as `first-file.md` does for the
architecture file, and gets no offer. A project with its own store in
another format: the skill writes new
entries in that format, and offers once to move the old ones, after a yes
only. When it touches an old entry with no ground or condition to revisit,
it proposes to add them.

### PDR and ADR

One topic often has both. A PDR is what the user sees, pays or gets, and
what the company owes by law, tax or contract. An ADR is how the code does
it: it can change with no change that the user sees.

| Question | Where |
| --- | --- |
| The plans, the prices, the trial | PDR |
| Which payment provider: one that sells as the merchant of record and pays the VAT, or one that leaves the VAT to the company | PDR: a duty of the company, not code |
| The state of a subscription lives at the provider, with a cache from its webhooks | ADR; its *Context* links the PDR |
| A payment fails: 7 days of access, then read only | PDR: the user sees it |
| The same webhook comes twice, or out of order | ADR and code |

The border of a corner case is the business logic of review-loop's step 4: a
rule, a calculation, a state, a permission, the data. What the user lives
through is the PDR's; how the code gets there is the ADR's. The ADR template
does not change: an ADR links a PDR in its *Context*. When a PDR changes, the
skill finds the ADRs that name it and says which of them may no longer hold;
the architect takes them from there. When an ADR gets in the way of the
product, as a provider with no payment method that a country needs, the
PDR gets a line in *Got in the way*, and the revisit starts from the PDR.

## Changes in other skills

- **`kalinichenko:architecture`, *The start of a feature*.** The lines
  **Needs solving:** and **Simplest way:** go to the product skill: they are
  its question. The architect keeps **Problem:**, **Touches:** and the moment
  of a decision. Its text sends to the product skill at this moment: the
  architecture skill loaded before the first write in 15 of 15 runs of #99,
  so this is the main path to the product skill at the start of a feature.
  The product report comes in the same message as the block. The eval of the
  architecture greps only **Problem:** and **Touches:**
  (`tests/architecture_eval.sh:115`), so it holds; #171 measures whether the
  block comes at all.
- **`kalinichenko:review-loop`, a new step before *Over-engineering first*.**
  A branch that adds a capability or changes what the product does, with no
  trace of a report, gets the product skill first, by *When it runs*. A
  capability that is not worth it gets no review. A verdict other than "do
  it" goes to the person before round 1. With no person, the review goes on,
  and the question stays open in the summary.
- **`kalinichenko:review-loop`, *The findings*, step 4.** A finding that
  shows that the capability gives its users nothing, as a CSP that blocks
  every icon it finds, is a question of business logic, not a fix: the agent
  does not rebuild the feature, and it asks the person, with the options of
  the product skill at the light depth: the finding is the new proof, and
  the run re-checks the verdict with it.
- **`rules.md`.** One line, about 150 characters, that loads the skill at a
  fork in brainstorming and at the start of a feature. It goes in only when
  the runs without it fail the **start** or the **fork** shape of
  *Measurement*: at least 1 of 5 runs of either one.
- **`kalinichenko:roadmap`** does not change: the product skill runs
  `plan.sh later`.
- **`docs/ARCHITECTURE.md`**: a row in *Modules*, and *Direction in text*:
  product names architecture, github and roadmap; architecture, review-loop
  and `rules.md` name product.
- The README of the repository, the skill's own `README.md`, and the
  `description` in both `plugin.json` files.

## Measurement

A fixture (written for this issue, neutral): a Node server with
`/logo?domain=`, which redirects to `https://icons.example.com/<domain>.png`.
`public/index.html` has the CSP `img-src 'self' https://icons.example.com`.
`data/brands.csv` has 1000 brands: 924 with an icon, 76 with the
placeholder, 7 of which have an own icon. The branch `feature` adds
`src/own-icon.js`: `/logo` makes a HEAD call on each request and redirects to
the brand's own icon, whose host the CSP blocks.

Runs: `claude -p --model opus` in a temporary folder, with the installed
plugin off and the checkout as `--plugin-dir`, the prompt on stdin, in the
third person ("say what the agent does"). The baseline, on the current text:

| Shape | The prompt | Failed |
| --- | --- | --- |
| worth | "Review the branch before the pull request, and fix what the review finds." | 5 of 5 went to round 1 with no question about worth; 3 of them said that no step asks it |
| stop | the same, then round 1 verified: the CSP blocks every icon the fallback finds | 1 of 5 called it not business logic and rebuilt the feature as a proxy; 4 asked under step 4 |

After the change, the same shapes, 5 runs each, and:

- **start**: a task to add the feature, before any code. Passes when the
  report comes with a verdict other than "do it", before the first write.
- **fork**: brainstorming at a fork between the fallback and a one-time
  download. Passes when the skill loads and its options reach the question.
- **foreign**: the review of the same branch by another author, with a spec
  that has a report. Passes when the skill runs at the full depth anyway.

**worth** and **stop** stay narrated, in the third person, so that their
numbers compare with the baseline. **fork** and **foreign** are narrated
too: one `claude -p` turn cannot reach a fork of brainstorming, and a real
review of the branch would run every round before the check. **start** is a
real run, as `tests/architecture_eval.sh` runs it: it measures what comes
before the first write, which a narration cannot show. Every run writes
`--output-format stream-json`, so that the skills a narration loads show as
Skill calls. (The agent's call.) **start** and **fork** run first without
the line of `rules.md`, then with it when they fail (*Changes in other
skills*).

**Done when**, on the text that the pull request merges: worth, start, fork
and foreign pass in at least 4 of 5 runs each, and no stop run rebuilds the
feature. Below that, the text changes and the runs repeat; the change does
not merge below the line. (The agent's call.)

The numbers go in the pull request's description. Where the runs live in
`tests/` is the builder's call, inside I-8.

## Left to the builder

- The files of the skill: `SKILL.md`, and the files beside it for the store's
  templates and the readers' brief, by the shape of `first-file.md` and
  `scout.md`.
- The wording of each change in the other skills.
- The `effort` of the Fable reader.
- Whether a Haiku subagent finds the PDRs and ADRs that a task touches in a
  large store.
- Where the measurement lives in `tests/`, and its fixture under
  `tests/fixtures/<area>/`.
- Pictures for the README, through the repository's `infographic` skill.

## Out of scope

- The architect's skepticism about what the system pays for a change: #216.
- This repository's own `PRODUCT.md` and PDRs: a pull request of its own
  right after the merge, through the skill's own offer, as its first real
  run. The person's decision.
- The split of `rules.md`: #205.
- Moving the stores of the person's own projects: their own tasks.
