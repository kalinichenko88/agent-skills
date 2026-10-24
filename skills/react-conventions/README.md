# kalinichenko:react-conventions

Layer and feature boundaries in a React app, where a sub-component's own files
go, request state as one union, and no `ref.current` in render. Each rule is
one that agents broke in a test without it.

## When it starts

- Before the first write or edit to a React component or hook in a session.
  `rules.md` asks for it, so a subagent starts it too.
- You add a feature beside existing ones, or import from another feature or
  layer.
- One feature needs something that another feature owns.
- You add a hook, a helper or a constant that one sub-component uses.
- You register a reducer, a route or a provider.
- A component holds a request's loading, error and data.
- You read a value from `useRef`, or write `usePrevious`.

## The rules

- **Layers import downward only:** `app → features → shared → ui → core`. When
  a lower layer must know a feature, the lower layer owns an extension point
  and the feature registers itself, or `app` wires the two together.
- **A feature uses another only through its `index.ts`, in one direction.** A
  generic helper is never part of a feature's API: it moves down to `shared`
  before a second feature imports it.
- **A part's own files live in its folder.** A sub-component with a hook,
  helper or constant file of its own is a folder. A file that two parts use
  goes to their nearest common folder. The page's own files sit at the feature
  root.
- **A request's state is one union:** `idle`, `loading`, `failed` or `done`,
  not three flags that can disagree. A data library that the project already
  has holds this state instead.
- **Render reads props, state and context, not refs.** A ref change schedules
  no render. `usePrevious` keeps the previous value in state.
