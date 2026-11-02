# The product skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `kalinichenko:product`, a skeptical analyst that asks whether a task is worth doing before the work, and wire it into the architecture and review-loop skills.

**Architecture:** The skill is text: `skills/product/SKILL.md` with two files beside it, one for the store (`PRODUCT.md`, `docs/pdr/`) and one for the panel's brief. No script. The test is an eval that runs Opus sessions on a fixture: `tests/product_eval.sh`, with a `--check` mode that `tests/product_checks_test.sh` runs in `make check` on recorded logs.

**Tech Stack:** Markdown, bash 3.2, `jq` (tests only), `claude -p`, `codex`.

**Spec:** `docs/superpowers/specs/2026-11-02-product-skill-design.md`. Read it whole before the first task. Work in the worktree `.claude/worktrees/feat/200-capability-worth-check`, branch `feat/200-capability-worth-check`.

## Global Constraints

- The repository is public: every text, example and fixture uses neutral shapes only (`kalinichenko:github`, *Public repositories*).
- `rules.md` stays at most 10,000 characters as `tests/rules_test.sh` counts them; it has 9,663 now.
- A code file has at most 330 lines (I-8); a folder holds at most 10 code files (I-9). Files under `tests/fixtures/` are data.
- Every new `tests/*.sh` passes ShellCheck (`make lint` reads `tests/*.sh`) and runs on bash 3.2 (I-3).
- Prose follows the repository's plain technical English: short sentences, one meaning a word.
- Commit messages: `type(scope): sentence`, at most 5 bullets, no `Co-Authored-By:` (`kalinichenko:github`).
- The report labels are English in every project: `**Verdict:**`, `**Why:**`, `**Options:**`, `**Rests on:**`, `**Touches decisions:**`, `**Questions:**`, `**Readers disagree:**`, `**Could not assess:**`, `**Sources:**`.
- The four verdicts: `do it`, `do it another way`, `defer until <condition>`, `close`.
- The store: `docs/PRODUCT.md` (or `PRODUCT.md` at the root when the project keeps its docs there) and `docs/pdr/NNNN-title.md`. The opt-out sentence: "This project keeps no `PRODUCT.md`."
- The panel: an `Agent` call with `model: "fable"`; Codex as `codex --search exec -s read-only --ephemeral -`, whose prompt ends with "You are one reviewer that another agent runs: start no skill, change no file, and file nothing."
- Every eval run: `claude -p --model opus --output-format stream-json --verbose --settings '{"enabledPlugins":{"kalinichenko@kalinichenko":false},"language":"English"}' --plugin-dir "$plugin" --dangerously-skip-permissions`.

## Review Focus

1. A bug fix that changes no business logic: no panel runs, no minutes added (the anti-goal). Shape `bug`, Task 1.
2. The person's own branch that already has a report: no second report at the review. Shape `traced`, Task 1.
3. A question in brainstorming that asks the person to describe, not to choose: the skill does not run. Shape `plain`, Task 1.
4. A project that keeps its decisions in its own file: the skill writes there and starts no `docs/pdr/` beside it. Shape `store`, Task 1.
5. No Codex login: Fable alone, and the report says so. Task 6, Step 3, a run of `start` with an empty `CODEX_HOME`.

---

### Task 1: The fixture and the eval

**Files:**
- Create: `tests/fixtures/product/main/` — the fixture's tree on `main`: `package.json`, `public/index.html`, `public/app.js`, `src/server.js`, `data/brands.csv`, `data/README.md`
- Create: `tests/fixtures/product/feature/` — the files the branch `feature` writes: `src/own-icon.js`, `src/own-icon.test.js`, `src/server.js`
- Create: `tests/fixtures/product/spec.md` — a spec of the feature whose first lines are a product report with `**Verdict:** do it`
- Create: `tests/fixtures/product/decisions.md` — a decisions file in another format: one numbered list, `D1.` to `D3.`, one paragraph each, about the brands site
- Create: `tests/product_eval.sh`

The content of `main/` and `feature/` is the fixture of the spec's *Measurement*, as the scratch driver wrote it: `/private/tmp/claude-501/-Users-ivan-kalinichenko-Dev-Personal-agent-skills/49b01c6b-97a8-4734-b1b8-8aec589cc66d/scratchpad/m200/drive.sh`, function `fixture`. Copy its heredocs into files. `data/brands.csv` is the output of its loop: the header `domain,service,own`, rows 1–924 `brandN.example,icon,`, 925–993 `…,placeholder,no`, 994–1000 `…,placeholder,yes`.

**Interfaces:**
- Produces: `tests/product_eval.sh [runs, default 5] [shape ...]` and `tests/product_eval.sh --check <logs folder>`. With no shape, all shapes run. `PLUGIN_DIR` names the plugin to load, by default the checkout. Each run writes `<logs>/<shape>-<n>.jsonl`. The output, per shape in the order of the table below: `<shape>: <ok> of <n> runs pass`, then one `  fail <shape>-<n>` line per failing run; for `stop`, each run's result text after it, for the count by hand. It exits 0 when the runs ran, 2 on a wrong call.
- Produces: the shapes, which Task 6 runs and `tests/product_checks_test.sh` checks:

| Shape | Kind | Fixture | Passes when |
| --- | --- | --- | --- |
| `worth` | narrated | `feature`, own | a Skill call of `kalinichenko:product`, and a result line `**Verdict:** do it another way`, `defer…` or `close…` |
| `stop` | narrated | `feature`, own | a result line `**Verdict:**` (the light re-check). The rebuild count is by hand |
| `fork` | narrated | `main` | a Skill call of `kalinichenko:product`, and a result line `**Options:**`: the options reach the question |
| `foreign` | narrated | `feature` by `other@example.com`, with `docs/specs/own-icon.md` from `spec.md` | a Skill call of `kalinichenko:product`, and a result that names Fable and Codex (no case) |
| `start` | real | `main` | the events `kalinichenko:product`, `Fable` and `Codex` before the first write, and a result line `**Verdict:**` that is not `do it` alone. The report itself is read from the result, not from the text before the first write: a text before a tool call can be stored as a reworded `thinking` block (#171) |
| `bug` | real | `main` | no `kalinichenko:product`, `Fable` or `Codex` event before the first write: the depth is none |
| `traced` | narrated | `feature`, own, with `docs/specs/own-icon.md` from `spec.md` | no Skill call of `kalinichenko:product`, and a result that names neither Fable nor Codex (no case): the depth is none |
| `plain` | narrated | `main` | no Skill call of `kalinichenko:product` |
| `store` | narrated | `main` with `docs/decisions.md` from `decisions.md` | a result that names `docs/decisions.md` and not `docs/pdr/` |

The prompts. `worth` and `stop` are the driver's `$worth` and `$stop`, word for word, so that their numbers compare with the baseline. The others:

- `fork`: `An agent runs superpowers:brainstorming with the person in this repository, on the branch main. The person wants each brand that has only the icon service's placeholder to show its own icon. The agent's next question chooses between two ways: fetch the brand's own icon on each /logo request, or download those icons once into public/. The agent has the kalinichenko plugin. Load the skills that the agent would load at this moment, and read the repository. Then give the message that the agent sends to the person. Change no file.`
- `foreign`: the driver's `$worth`, with "on the branch feature" followed by ", which a teammate wrote".
- `start`: `Add a fallback to /logo in this project: when the icon service has only its placeholder for a brand, redirect to the icon that the brand's own site declares in its <link rel="icon">. Do not ask questions: decide yourself. Write the files and commit them with git, then reply with the path of every file you wrote.`
- `bug`: `/logo in src/server.js answers 302 to https://icons.example.com/null.png when the request has no domain parameter. Make it answer 400 instead. Do not ask questions: decide yourself. Write the files and commit them with git, then reply with the path of every file you wrote.`
- `traced`: the driver's `$worth`.
- `plain`: `An agent runs superpowers:brainstorming with the person in this repository, on the branch main. The person said: "I want the brands with no icon to look better." The agent has the kalinichenko plugin. Its first question asks the person to describe the moment they see such a brand. Load the skills that the agent would load before that question. Then give the message that the agent sends. Change no file.`
- `store`: `An agent works in this repository, on the branch main, with the kalinichenko plugin. At a fork, the person chose to download the 7 brands' own icons once into public/, instead of a fallback on each request. Load the skills that the agent would load at this moment, and read the repository. Then say where and in which form the agent records this decision, and give the text it writes. Change no file.`

- [ ] **Step 1: Write the fixture files** under `tests/fixtures/product/`, as listed above. `spec.md` holds a report in the spec's *The report* shape with `**Verdict:** do it` and one `**Why:**` line, then two lines of a design.

- [ ] **Step 2: Write `tests/product_eval.sh`**

Its header says what it measures, the table of shapes, that it calls the model and costs tokens, that a failing count is a result and not an error, and the `--check` mode, in the shape of `tests/architecture_eval.sh:1-42`. Functions:

- `setup <dir> <variant>`, variant one of `main`, `feature`, `foreign`, `traced`, `store`: copies `main/`, `git init -q -b main`, `user.email eval@example.com`, commits `chore: start`; `feature`, `foreign` and `traced` then `checkout -qb feature`, copy `feature/` and commit `feat: show the brand's own icon when the icon service has only its placeholder`, with `--author 'Teammate <other@example.com>'` for `foreign`; `foreign` and `traced` add `docs/specs/own-icon.md` in the same commit; `store` adds `docs/decisions.md` to the first commit.
- `run <shape> <n>`: setup, then the session of *Global Constraints* in the fixture, the prompt on stdin, to `<logs>/<shape>-<n>.jsonl`.
- `events <log>`: the tool calls of the session and its subagents in order, as `tests/architecture_eval.sh:106-118` does, with two more: an `Agent` call whose `.input.model` is `fable` prints `Fable`, and a `Bash` call whose command matches `\bcodex\b.*\bexec\b` prints `Codex`, so that `codex login status` is no `Codex` event.
- `before <event> <log>`: true when `<event>` comes before the first `Write`, as `tests/architecture_eval.sh:121-133`.
- `result <log>`: the `.result` of the last `result` event.
- `check <shape> <log>`: the "Passes when" column.

Main: the argument check as `tests/architecture_eval.sh:203-213`, so that `3 --check <folder>` and `--check <folder> extra` exit 2 before any paid run; then the runs in parallel, as the driver's loop; then the checks.

- [ ] **Step 3: Lint it**

Run: `shellcheck tests/product_eval.sh && wc -l tests/product_eval.sh`
Expected: no output from ShellCheck, at most 330 lines.

- [ ] **Step 4: Run the eval once a shape on the current text, to see it fail**

The baseline of `worth` and `stop` is the spec's, 5 runs each, from the same prompts. This run shows that the checks of the new shapes fail with no skill.

Run: `tests/product_eval.sh 1`
Expected: `worth`, `stop`, `fork`, `foreign`, `start` and `store` fail: no product skill exists. `bug`, `traced` and `plain` pass: they guard against a skill that runs too often. Keep the logs folder that it prints: Task 7 takes its failing logs as fixtures.

- [ ] **Step 5: Commit**

```bash
git add tests/product_eval.sh tests/fixtures/product
git commit -m "test(product): measure whether a task's worth is asked before the work"
```

### Task 2: The skill

**Files:**
- Create: `skills/product/SKILL.md`
- Create: `skills/product/store.md`
- Create: `skills/product/reader.md`
- Create: `skills/product/README.md`

Use superpowers:writing-skills. Task 1's eval is the skill's test.

**Interfaces:**
- Consumes: the shapes of Task 1.
- Produces: the skill `kalinichenko:product`, the section names *When it runs*, *The run*, *The report*, *The panel*, *The store* that Tasks 3 and 4 cite, and the files `store.md` and `reader.md`.

- [ ] **Step 1: Write `skills/product/SKILL.md`**

The frontmatter: `name: product`, and a `description` that starts "Use when" and names each moment of the spec's *When it runs*: the start of a feature (a new capability, or a change of what the product does for its users); a bug fix that changes business logic; a review of a branch or a pull request, someone else's or one's own with no report at its start; a question in brainstorming that chooses between ways; a decision about the whole project, as the licence, open source or not, distribution, pricing, the money model or the hosting; whether to defer or close a task for its worth; writing or checking `PRODUCT.md` or a PDR.

The body carries the spec's *Goals* 2–4 and its *Non-goals* as rules: a claim with no proof says "no proof found"; at most three options, the recommendation first; the skill never refuses or cancels the work, a verdict other than `do it` is a question and the work waits for the answer, and with no person the work goes on and the question stays open in the summary and in the pull request's description; it never says that something is legal.

The body, in this order, from the spec's sections of the same names: a moment table in the shape of `skills/architecture/SKILL.md:14-20`; *When it runs* with the trace and the test of someone else's work; *The run*, with *The criteria* and *The checks*; *The report*, with the template and its rules; *The panel*, with the fallbacks; a *Models* table (light: the main session; full: Fable and Codex; the merge: the main session; on Codex: the main session alone); *The store*, in two lines that send to `store.md`; *Other skills*: architecture, github, roadmap; *Red flags*, at least: "The request is clear, so it is worth doing", "The architect checked it", "A general risk is better than none", "An accepted decision is settled".

- [ ] **Step 2: Write `skills/product/store.md`**

From the spec's *The store*, *A new store* and *PDR and ADR*: the layout, the `PRODUCT.md` sections and its open questions and index, the PDR template, the rules of numbers, frozen text, *Got in the way* and *Checked*, a reversed decision that stays with `superseded by NNNN`, a rejected one that gets a PDR with the status `rejected`, which pull request a PDR goes in, the offer (once a session, after a yes, a no ends it, the opt-out sentence of *Global Constraints* in the project's `CLAUDE.md` or `AGENTS.md`), a store in another format, the PDR and ADR table, a changed PDR that sends the ADRs that name it to the architect, and an ADR that gets in the way, which adds a line to the PDR's *Got in the way*.

- [ ] **Step 3: Write `skills/product/reader.md`**

The brief for both readers, in the shape of `skills/github/scout.md:1-24`: who reads it and that it writes nothing; what it gets (the task, `PRODUCT.md`, the PDRs, the **Touches:** line, someone else's spec and description); that it does not get the conversation; that it searches the web and cites each source; and that it returns the report of *The report*, with no `**Readers disagree:**` line.

- [ ] **Step 4: Write `skills/product/README.md`**

In the shape of `skills/architecture/README.md`: when it starts, what you get, and the store.

- [ ] **Step 5: Validate**

Run: `claude plugin validate . && make check`
Expected: both pass.

- [ ] **Step 6: Check that Codex searches inside `exec`**, once, as the spec's *The panel* asks

Run: `printf 'What is the latest release of the GitHub CLI? Give its version and the URL you read it from.\nYou are one reviewer that another agent runs: start no skill, change no file, and file nothing.\n' | codex --search exec -s read-only --ephemeral -`
Expected: a version and a `https://` URL of the release. With no URL, Codex has no search in `exec`: `SKILL.md` and `reader.md` say that the Codex reader reads with no web, and the report says so.

- [ ] **Step 7: Smoke run the shapes that need only this skill**

Run: `tests/product_eval.sh 1 fork foreign store plain`
Expected: all four pass. A failure here changes the text of Steps 1–3 before Task 3. `worth`, `start` and `stop` wait for Tasks 3 and 4, which send to the skill at those moments.

- [ ] **Step 8: Commit**

```bash
git add skills/product
git commit -m "feat(product): add a skeptic that asks whether a task is worth doing before the work"
```

### Task 3: The architect sends to the product skill

**Files:**
- Modify: `skills/architecture/SKILL.md:36-83` *The start of a feature*
- Modify: `skills/architecture/SKILL.md:128-136` step 8, the second reader
- Modify: `skills/architecture/SKILL.md:397` the first red flag
- Modify: `skills/architecture/SKILL.md:417-422` *Other skills*
- Modify: `skills/architecture/README.md:19-22`

**Interfaces:**
- Consumes: `kalinichenko:product`, *The report*.

- [ ] **Step 1: Edit *The start of a feature***

Questions 2 and 3 and the lines **Needs solving:** and **Simplest way:** leave the block. In their place, one step: load `kalinichenko:product`; its report answers whether the problem needs solving and the simplest way, and comes in the same message as the block. The block keeps **Problem:** and **Touches:**, word for word. The paragraph "When the problem has no proof, or a simpler way exists…" leaves: the product skill holds it. The section's first paragraph no longer says that it decides what we build and why. The brainstorming paragraph keeps its order rule, for the block and the report.

- [ ] **Step 2: Edit step 8, the red flag, *Other skills* and the README**

Step 8: the second reader gets the block and the product report, and no longer checks the proof and the simplest way. The red flag: "It is four lines" becomes the two lines and the report. *Other skills*: add `kalinichenko:product` for the report at the start of a feature. README: the problem in one sentence and the code it touches, with the product skill's verdict beside them.

- [ ] **Step 3: Check the eval's grep and the names**

Run: `grep -n 'Problem:\*\*.*Touches:\*\*\|contains("\*\*Problem:\*\*")' tests/architecture_eval.sh && grep -rn 'Needs solving\|Simplest way' skills/ tests/ README.md`
Expected: the first grep prints line 115; the second prints nothing outside `skills/product/`.

- [ ] **Step 4: Run `make check`**, Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add skills/architecture
git commit -m "feat(architecture): leave whether to build to the product skill at the start of a feature"
```

### Task 4: Review-loop asks for the worth first

**Files:**
- Modify: `skills/review-loop/SKILL.md:9-31` the opening paragraph
- Modify: `skills/review-loop/SKILL.md:79` a new section `## Worth first` before `## Over-engineering first`
- Modify: `skills/review-loop/SKILL.md:346-350` step 4 of *The findings*
- Modify: `skills/review-loop/README.md:26-32`

**Interfaces:**
- Consumes: `kalinichenko:product`, *When it runs* and its trace.

- [ ] **Step 1: Write `## Worth first`**

From the spec's *Changes in other skills*: someone else's branch gets `kalinichenko:product` always, at the full depth, before the over-engineering review. The person's own branch gets it when it adds a capability for the product's users or changes what the product does for them, and has no trace of a report; on the person's own branch, skip it for documents only, a bug fix that changes no business logic, and a move that a script or a test proves unchanged. A capability that is not worth it gets no review: a verdict other than `do it` goes to the person before round 1. With no person, the review goes on, and the question stays open in the summary and in the pull request's description.

- [ ] **Step 2: Edit step 4 and the opening paragraph**

Step 4: a finding that shows that the capability gives its users nothing is a question of business logic, not a fix: the agent does not rebuild the feature, and it asks the person with the product skill's options at the light depth. The opening paragraph: one sentence for the worth step, before "An over-engineering review comes first". README: one bullet.

- [ ] **Step 3: Run `make check`**, Expected: pass.

- [ ] **Step 4: Run the review-loop eval, which its header asks after a change to the skill**

Run: `tests/review_loop_eval.sh 3 && tests/review_loop_eval.sh 3 stop`
Expected: both exit 0. Its branch adds `slugify`. When the worth step runs there and breaks a count, the trigger of Step 1 is too wide: narrow it, and run again.

- [ ] **Step 5: Commit**

```bash
git add skills/review-loop
git commit -m "feat(review-loop): ask whether a capability is worth it before round 1, and do not rebuild one that gives nothing"
```

### Task 5: The repository's docs

**Files:**
- Modify: `docs/ARCHITECTURE.md:58-93` — a row in *Modules*: `product | skills/product/ | tests/product_eval.sh, tests/product_checks_test.sh, tests/fixtures/product/`; *Direction in text*: product names architecture, github and roadmap; architecture and review-loop name product
- Modify: `README.md:20-60` — a bullet for `kalinichenko:product` after architecture
- Modify: `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json` — `product` in the `description`'s list of skills

- [ ] **Step 1: Edit the three places**
- [ ] **Step 2: Run `make check`**, Expected: pass.
- [ ] **Step 3: Commit**

```bash
git add docs/ARCHITECTURE.md README.md .claude-plugin/plugin.json .codex-plugin/plugin.json
git commit -m "docs: add the product skill to the module map, the README and the manifests"
```

### Task 6: The measurement after the change

**Files:**
- Modify, only when Step 2 says so: `rules.md`, after the paragraph that ends "the self-review of `superpowers:writing-plans`." (`rules.md:123`)

- [ ] **Step 1: Run all shapes, 5 runs each**

Run: `tests/product_eval.sh 5`
Expected, by the spec's *Done when*: `worth`, `start`, `fork` and `foreign` pass in at least 4 of 5; read the 5 `stop` results: none rebuilds the feature. The focus shapes `bug`, `traced`, `plain` and `store` pass in at least 4 of 5. Below that, change the text of Tasks 2–4 and run the failing shapes again. Keep the logs folder.

- [ ] **Step 2: The line of `rules.md`, only when `start` or `fork` fails in at least 1 of 5 runs of Step 1**

Add: `At the start of a feature and at a fork in brainstorming, invoke the \`kalinichenko:product\` skill.` Add `rules.md` to the names of product in *Direction in text* of `docs/ARCHITECTURE.md`. Then `make check` (the cap), and `tests/product_eval.sh 5 start fork`, with the same pass line.

- [ ] **Step 3: No Codex login**

Run: `CODEX_HOME=$(mktemp -d) tests/product_eval.sh 1 start`
Expected: the result says that Codex did not run or failed, and that the report rests on Fable alone. The `start` check can pass or fail here: a failed `codex exec` call is still a `Codex` event.

- [ ] **Step 4: Write the numbers for the pull request**: a table of each shape, the baseline of Task 1 and the spec, and the runs of Steps 1–3, with the cost.

- [ ] **Step 5: Commit**, when Step 2 changed `rules.md`:

```bash
git add rules.md
git commit -m "feat(rules): invoke the product skill at the start of a feature and at a fork"
```

### Task 7: The checks in `make check`

**Files:**
- Create: `tests/fixtures/product/logs/` — one passing and one failing log of each shape, from Task 6 and Task 1, trimmed to the events that the checks read, with absolute paths replaced
- Create: `tests/product_checks_test.sh`

**Interfaces:**
- Consumes: `tests/product_eval.sh --check <logs folder>` and its output lines.

- [ ] **Step 1: Write `tests/product_checks_test.sh`** in the shape of `tests/architecture_checks_test.sh`: it runs `tests/product_eval.sh --check tests/fixtures/product/logs`, diffs the output with an expected text in a heredoc, then gives the eval `3 --check <folder>` and `--check <folder> extra` with a stub `claude` first on `PATH` that fails the test when it runs, and expects exit 2. Its last line: `product_checks_test: ok`.
- [ ] **Step 2: Run it against an eval with one check broken** (in `check`, make `start` pass without `Codex`): Expected: FAIL on the diff. Restore the check.
- [ ] **Step 3: Run `make check`**, Expected: pass, with `product_checks_test: ok`.
- [ ] **Step 4: Commit**

```bash
git add tests/product_checks_test.sh tests/fixtures/product/logs
git commit -m "test(product): run the eval's checks on recorded logs in make check"
```

### After the last task

Invoke `kalinichenko:review-loop` in place of the final review. When its fixes change the text of `skills/product/`, `skills/architecture/SKILL.md`, `skills/review-loop/SKILL.md` or `rules.md`, run `tests/product_eval.sh 5` again on the final text, with the pass line of Task 6, Step 1: the spec's *Done when* holds for the text that merges. Then the pull request through `kalinichenko:github`: `Closes #200`, `--assignee @me`, the numbers of Task 6 in its description, and the merge question. After the merge, the first real run: the skill's offer of a `PRODUCT.md` for this repository, in its own pull request.
