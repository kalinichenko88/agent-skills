# kalinichenko:product

A skeptical analyst. Before the work, it asks whether a task is worth doing,
and in which form: who gains and how many, the money, the direction of the
project, the law, the client, and what fails when a part fails. Another way,
a deferral or a close is a good answer, and you decide. The project keeps
its product decisions in `docs/PRODUCT.md` and one `docs/pdr/` file per
decision, as it keeps the code's decisions in `docs/ARCHITECTURE.md` and its
ADRs.

## When it starts

- A feature starts: a new capability, or a change of what the product does
  for its users.
- A bug fix changes business logic: a rule, a calculation, a state, a
  permission, the data.
- A branch is reviewed: someone else's always; yours when it had no check of
  its worth at its start.
- Brainstorming asks a question that chooses between ways.
- A decision concerns the whole project: the licence, open source or not,
  distribution, pricing, the money model, the hosting.

A bug fix that changes no business logic gets no check.

## What you get

- **A verdict before the work.** Do it, do it another way, defer until a
  condition, or close. Each claim has a number, a `path:line` or a source;
  a claim with no proof says so, and a general risk is left out. At most
  three options, the recommendation first, each with its cost.
- **Facts from outside the code.** At the full depth, Fable and Codex read
  the task in parallel, each with a web search, and neither sees the
  conversation: prices, limits, terms of service, the text of a law, how
  others solve it, known failures. Where they disagree, you see both sides.
- **Questions for the right people.** Each question names who answers it:
  the client, a lawyer, or you. On the law, it cites the rule and the cases,
  and never says that something is legal.
- **Decisions on record, and checked again.** Each decision you take goes
  into a PDR, with what it rests on and when to revisit it. When a task
  touches an accepted decision, its ground is checked again. A decision that
  got in the way twice comes back to you.
- **You decide.** The work waits for your answer. With no one to answer, it
  goes on as asked, and the question stays open in the summary and the pull
  request's description.
- **A store, when you want one.** In a project with none, it offers once a
  session to write `PRODUCT.md`, and writes nothing without your yes. A
  project with its own decision file keeps it: new entries go there.
