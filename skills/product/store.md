# The store of product decisions

The store holds the project's product decisions: what the users see, pay or
get, and what the company owes by law, tax or contract. The code's
decisions are ADRs, in `kalinichenko:architecture`.

```
docs/
  ARCHITECTURE.md   the code's structure, the index of ADRs
  adr/0007-….md
  PRODUCT.md        the direction, the constraints, the open questions, the index of PDRs
  pdr/0012-….md     one decision per file
```

`PRODUCT.md` is at `docs/PRODUCT.md`, or at the root when the project keeps
its docs there. The PDRs are in `docs/pdr/`. A system file of the plugin has
a name in capitals; a record has a name in lower case.

## Find the store

1. `docs/PRODUCT.md` or `PRODUCT.md`, and `docs/pdr/`.
2. With neither: the project's own decision files, by name, in `docs/` and at
   the root: a decisions file, a product or requirements document, a list of
   legal questions.
3. With one in another format: use it as it is, and write new entries in its
   format. Never make a second place for the same decisions. Offer once to
   move its entries into this store, and move them only after a yes.
4. With none: the offer of *A new store*.

When the task touches an old entry with no ground or no condition to
revisit, propose to add them.

## `PRODUCT.md`

The skill reads it at each run. Its sections:

- what the project is, and for whom;
- its direction, and the current goal;
- what it will not do;
- the constraints: the law (where it sells, which rules apply), the client
  and the contract, the money;
- the open questions;
- the index of the PDRs: one line each.

```markdown
## Open questions

### Q-3 <the question>
- Answers: lawyer | client | owner
- Blocks: #45, PDR 0012
- Since: 2026-10-01

## Decisions

- [0012 Three plans, monthly billing](pdr/0012-three-plans.md) — accepted; revisit when: payment failures pass 5 %
```

A question that gets its answer becomes a PDR, and its entry leaves the
list.

## A PDR

`docs/pdr/NNNN-title.md`, one decision per file:

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

- The number comes after the highest PDR. A number is never used again. A
  file is never renamed or deleted, so a link to it does not rot.
- After the decision is accepted, its text does not change. Only the Status
  line changes, and lines are added to *Got in the way* and *Checked*.
- With two lines in *Got in the way*, propose to revisit the decision. Only
  the person changes its status.
- A reversed decision stays, with `superseded by NNNN`.
- A decision that the person rejects for a lasting reason gets a PDR with
  the status `rejected`, so that the next agent does not offer it again.
- A new PDR adds its line to the index of `PRODUCT.md` in the same commit.

**Where it is written.** A PDR goes in the pull request of the work that it
decides. A decision with no work of its own goes in a pull request of its
own. A new line of *Got in the way* or *Checked* goes in the pull request of
the task that found it.

## A new store

In a project with no store, offer once a session to write `PRODUCT.md`,
from the README, the docs, the issues and the person's answers. Make no
offer when the project's `CLAUDE.md` or `AGENTS.md` says "This project keeps
no `PRODUCT.md`."

- Write nothing without a yes.
- After a no, do not offer again in that session, and ask whether to add
  that line to the project's `CLAUDE.md`.
- A first `PRODUCT.md` holds only what the person confirms. Its open
  questions and its first PDRs come from decisions that the person names.

## PDR and ADR

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

The border of a corner case is the business logic: a rule, a calculation, a
state, a permission, the data. What the user lives through is the PDR's; how
the code gets there is the ADR's. An ADR links a PDR in its *Context*.

- When a PDR changes, find the ADRs that name it (`PDR 0012`), and say which
  of them may no longer hold. The architect takes them from there.
- When an ADR gets in the way of the product, as a provider with no payment
  method that a country needs, the PDR gets a line in *Got in the way*, and
  the revisit starts from the PDR.
