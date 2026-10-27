# 0001 Keep the recently viewed orders in localStorage

- Status: accepted
- Date: 2026-10-27

## Context

The shop keeps no state on the device. The recently viewed orders must stay
after the browser restarts.

## Options considered

- localStorage: synchronous, 5 MB, strings only.

## Decision

We will keep the last 10 orders in localStorage, under one key.

## Consequences

Good: no dependency and no schema.
Bad: a second kind of state on the device needs this decision again.

## Invariants

None.

## Confirmation

Review only.
