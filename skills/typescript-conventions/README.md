# kalinichenko:typescript-conventions

House TypeScript style. A codebase that consistently does otherwise wins: the
agent matches it and says so.

## When it starts

- Before the first write or edit to a TypeScript file (`.ts`, `.tsx`, `.mts`,
  `.cts`) in a session. `rules.md` asks for it, so a subagent starts it too.
- You write or review TypeScript: declare an object shape, name a new file,
  write a callback, reach for a dependency.
- You set up lint rules for a new TypeScript project.

## The rules

- **Object shapes are `type`, never `interface`.** `interface` is only for
  declaration merging and module augmentation, with a comment that says which.
- **`strict: true`, and no `any`.** `unknown` with a narrowing guard, or a
  generic.
- **A check of the array checks each item.** `Array.isArray` checks only the
  container. Each item gets a guard, or the project's schema library.
- **Bodies are braced and expanded.** No implicit arrow returns in callbacks,
  a JSX `.map` included, no one-line braced `if`.
- **A blank line before `return`**, unless it is the only statement in its
  block.
- **Render conditions are named constants**, declared above the `return`.
- **A branch becomes a component** only when it has handlers of its own and
  JSX more than two levels deep.
- **The runtime before a dependency.** `Intl`, `Object.groupBy`,
  `structuredClone`, `fetch` and `AbortSignal.timeout`, at the version that
  the project pins.
- **Files are kebab-case, one entity per file.** A file opens with its
  primary export; its helpers, module constants and own types go below it.

## Recommended lint rules

The skill asks for a blank line before `return`. To make ESLint enforce it in
a project, add this rule from `@stylistic`:

```js
'@stylistic/padding-line-between-statements': [
  'error',
  { blankLine: 'always', prev: '*', next: 'return' },
],
```

It does not touch a `return` that is the only statement in its block.
