---
name: react-conventions
description: Use when writing or reviewing React code — adding a feature beside existing ones, importing from another feature or layer, registering a reducer, route or provider, holding a request's loading, error and data in a component, reading a value from useRef or writing usePrevious — or when setting up lint for a React project's folders.
---

# React conventions

## Layers import downward only

Top to bottom: `app → features → shared → ui → core`. A layer imports only the
layers below it.

An upward import that already exists is debt, not a precedent. Do not add a
second one beside it. Report the first one as a finding outside the change.

When a lower layer must know a feature — a store, a router, a list of
providers — the feature registers itself through an extension point that the
lower layer owns, or `app` wires the two together:

```ts
// core/store.ts: the extension point, no feature imports
// interface: declaration merging, each feature adds its slice
export interface LazyLoadedSlices {}

export const rootReducer = combineSlices(sessionSlice).withLazyLoadedSlices<LazyLoadedSlices>();

// features/offers/offers-slice.ts: the feature registers itself
declare module '../../core/store' {
  // interface: declaration merging
  interface LazyLoadedSlices extends WithSlice<typeof offersSlice> {}
}

export const injectedOffersSlice = offersSlice.injectInto(rootReducer);
```

Lint enforces the order with a ready rule — `import/no-restricted-paths` from
`eslint-plugin-import` or `eslint-plugin-import-x`. A hand-written regex over
import strings misses path aliases and relative paths.

```js
const features = readdirSync('src/features');

'import/no-restricted-paths': ['error', { zones: [
  { target: './src/core', from: ['./src/ui', './src/shared', './src/features', './src/app'] },
  { target: './src/ui', from: ['./src/shared', './src/features', './src/app'] },
  { target: './src/shared', from: ['./src/features', './src/app'] },
  { target: './src/features', from: './src/app' },
  ...features.map((name) => {
    return { target: `./src/features/${name}`, from: './src/features', except: [`./${name}`] };
  }),
] }],
```

## Features do not import each other

Code that two features need moves down to `shared` before the second feature
imports it. A move leaves one copy: in the same change, the old place re-exports
it from `shared` or loses it. The old body need not be in view for that — the
old place becomes one line, `export { x } from '../../shared/x';`, and the body
moves unchanged. Show that one-line file in the change. A copy in the second
feature, even one marked to move later, is the failure this rule prevents: two
copies drift apart. A feature has one entry, `features/x/index.ts`, and `app`
imports only that entry:

```js
'no-restricted-imports': ['error', { patterns: [{
  regex: 'features/[^/]+/.+',
  message: 'Import a feature through its index.',
}] }],
```

## A request's state is one union

```tsx
type SearchState =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'failed'; error: Error }
  | { status: 'done'; results: SearchResult[] };

const [search, setSearch] = useState<SearchState>({ status: 'idle' });
```

Three `useState` calls — `isLoading`, `error`, `results` — allow eight
combinations, and only four of them are real. Every transition then resets the
other two by hand, and one missed reset shows an error over fresh results. With
one union, each transition is one `setSearch`, and the render branches on
`status`. If the project already has a data library (TanStack Query, RTK
Query), it holds this state instead.

## Render reads props, state and context — not refs

A ref changes without a re-render. A value read from `ref.current` in the
component body comes from an earlier moment, and the UI does not update when it
changes. The common `usePrevious` — `useRef`, an effect that writes it,
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

Read and write refs in effects and event handlers. A value that the UI shows is
state. The one exception is lazy initialisation:
`if (ref.current === null) { ref.current = new Player(); }`.
`eslint-plugin-react-hooks` reports the rest with the React Compiler checks in
its `recommended` preset (6.x; `recommended-latest` in 5.2).
