---
name: react-conventions
description: Use when writing or reviewing React code — adding a feature beside existing ones, placing a sub-component's hook, helper or constant inside a feature, importing from another feature or layer, letting one feature use another, registering a reducer, route or provider, holding a request's loading, error and data in a component, reading a value from useRef or writing usePrevious.
---

# React conventions

## Layers import downward only

Top to bottom: `app → features → shared → ui → core`. A layer imports only the
layers below it. Inside `features`, the next section says when one feature may
use another.

An upward import that already exists is debt, not a precedent. Do not add
another one beside it. Report each existing one as a finding outside the
change.

```ts
// core/store.ts
import { offersReducer } from '../features/offers/offers-slice';   // no: core imports a feature
```

When a lower layer must know a feature — a store, a router, a list of
providers — the feature registers itself through an extension point that the
lower layer owns, or `app` wires the two together:

```ts
// core/store.ts: the extension point, no feature imports
import { combineSlices } from '@reduxjs/toolkit';

import { sessionSlice } from './session-slice';

// interface: declaration merging, each feature adds its slice
export interface LazyLoadedSlices {}

export const rootReducer = combineSlices(sessionSlice).withLazyLoadedSlices<LazyLoadedSlices>();
```

```ts
// features/offers/offers-slice.ts: the feature registers itself
import { createSlice, type WithSlice } from '@reduxjs/toolkit';

import { rootReducer } from '../../core/store';

const offersSlice = createSlice({ /* … */ });

declare module '../../core/store' {
  // interface: module augmentation
  interface LazyLoadedSlices extends WithSlice<typeof offersSlice> {}
}

export const injectedOffersSlice = offersSlice.injectInto(rootReducer);
```

## A feature uses another only through its index, one way

By default a feature imports no other feature. When a page needs two features,
the page or `app` composes them, and neither knows about the other:

```tsx
<OffersList toolbar={<SearchBox scope="offers" />} />
```

When feature A needs something feature B owns — a component, hook or API of B's
domain — A imports it through `features/b/index.ts`, and only in one direction:
with `offers → search`, `search → offers` is forbidden. Two features that need
each other share a part that belongs on a lower layer.

```ts
import { useSearch } from '../search';                 // offers → search, through the index
import { useSearch } from '../search/use-search';      // no: a deep import
import { abortPrevious } from '../reports';            // no: a generic helper
```

A generic helper — abort logic, a formatter, a fetch wrapper — is never part of
a feature's API, even through its `index.ts`. It moves down to `shared` before
the second feature imports it. A move leaves one copy: in the same change, the
body goes to `shared` unchanged, and the old place becomes one line,
`export { abortPrevious } from '../../shared/abort-previous';`, or loses the
helper. Show that one-line file in the change. A copy in the second feature,
even one marked to move later, is the failure this rule prevents: two copies
drift apart.

## A part's own files live in its folder

A sub-component with a hook, helper or constant file of its own is a folder:
its component and the files that only it uses. A file that two parts use goes
to their nearest common folder; a type or a schema goes into its `models/` or
`schemas/` folder there, as typescript-conventions says. The page is the
feature's top part, so its own files sit at the feature root.

```
features/orders/
├── index.ts
├── orders-page.tsx        composes the parts
├── fetch-orders.ts        the page's request
├── models/order.ts        the type that the page and the table use
└── orders-table/
    ├── orders-table.tsx   ROWS_PER_PAGE stays in it, below the export
    └── use-table-sort.ts  only the table uses it
```

A flat `features/orders/use-table-sort.ts`, beside a flat `orders-table.tsx`,
would say that the page uses the hook, or more than one part does. A
sub-component with no file of its own stays one file next to its parent.

## A request's state is one union

```tsx
// no: three flags that can disagree
const [isLoading, setIsLoading] = useState(false);
const [error, setError] = useState<Error | null>(null);
const [results, setResults] = useState<SearchResult[]>([]);
```

```tsx
type SearchState =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'failed'; error: Error }
  | { status: 'done'; results: SearchResult[] };

const [search, setSearch] = useState<SearchState>({ status: 'idle' });
```

Three flags allow eight combinations, and only four of them are real. Every
transition then resets the other two by hand, and one missed reset shows an
error over fresh results. With one union, each transition is one `setSearch`,
and the render branches on `status`. If the project already has a data library
(TanStack Query, RTK Query), it holds this state instead.

## Render reads props, state and context — not refs

A ref change schedules no render. A value read from `ref.current` in the
component body can be stale, and the UI does not update when it changes. The
common `usePrevious` — `useRef`, an effect that writes it,
`return ref.current` — does exactly this: an arrow next to a changed price
disappears on the next unrelated render.

```ts
export function usePrevious<T>(value: T): T | undefined {
  const [state, setState] = useState<{ value: T; previous: T | undefined }>({ value, previous: undefined });

  if (!Object.is(state.value, value)) {
    setState({ value, previous: state.value });
  }

  return state.previous;
}
```

It returns the previous *different* value: A → B → B gives
`undefined → A → A`. Pass a primitive or a value with a stable identity: an
object literal made in the same render is new every time and loops.

Read and write refs in effects and event handlers. A value that the UI shows is
state. The one exception is lazy initialisation:

```ts
if (playerRef.current === null) {
  playerRef.current = new Player();
}
```
