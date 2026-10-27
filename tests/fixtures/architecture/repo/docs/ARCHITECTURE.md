# Architecture

A small web client of a shop. `src/api/` talks to the server, `src/lib/`
holds the helpers that every feature uses, and each folder of
`src/features/` holds one screen.

## Modules

| Module | Folder | Public API |
| --- | --- | --- |
| api | `src/api/` | `request()` in `src/api/client.ts` |
| lib | `src/lib/` | `formatPrice()` in `src/lib/money.ts` |
| a feature | `src/features/<name>/` | its `index.ts` |

A feature uses `api` and `lib`. `api` and `lib` use no feature.

## Invariants

- **I-1.** Only `src/api/client.ts` calls `fetch`: every request goes through
  `request()`, which sets the base URL, the token and the retry.
  Check: grep `fetch\(` in `src` except `src/api/client.ts`.
- **I-2.** A code file has at most 40 lines.
  Check: lines 40 in `src` debt `src/features/cart/index.ts`.

## ADRs

The ADRs go in `docs/adr/`. None yet.
