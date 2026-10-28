# kalinichenko:typescript-conventions

House TypeScript style. A codebase that consistently does otherwise wins: the
agent matches it and says so.

## When it starts

- Before the first write or edit to a TypeScript file (`.ts`, `.tsx`, `.mts`,
  `.cts`) in a session. `rules.md` asks for it, so a subagent starts it too.
- You write or review TypeScript: declare an object shape, place a type, an
  enum or a schema that several files use, name a new file or a constant,
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
- **Render conditions get a name**, a `const` declared above the `return`.
- **A branch becomes a component** only when it has handlers of its own and
  JSX more than two levels deep.
- **The runtime before a dependency.** `Intl`, `Object.groupBy`,
  `structuredClone`, `fetch` and `AbortSignal.timeout`, at the version that
  the project pins.
- **A constant's name is CONSTANT_CASE.** A constant is a module-level
  `const` that holds data written out in the code, which no code changes, as
  `MAX_RETRIES = 3`. A `const` that holds a component or a context, or whose
  name opens a JSX tag, is PascalCase, wherever it is. Every other `const` is
  camelCase: a function, a value made or read when the code runs, as
  `new Intl.NumberFormat(…)`, and a `const` inside a function. A name that a
  framework reads, as Next.js `metadata`, stays as the framework wants it.
- **Files are kebab-case, one entity per file.** A file opens with its
  primary export; its helpers, module-level `const`s and own types go below
  it, and so do the variants of a tagged union. A `const` that the export
  reads while the module loads goes above it. A constant of more than 15
  lines goes to the folder's constants file, `constants.ts` or
  `constants.tsx`, even when only one file uses it. A test file, and a file
  whose primary export is the constant, keep theirs.
- **A shared type is a model in `models/`, a schema is in `schemas/`.** A type
  or an enum that two files or more use goes to the `models/` folder of their
  nearest common folder, one model per file. A model made by an operation on
  one other model, as `Omit<Order, 'id'>`, may share that model's file, and a
  tagged (discriminated) union may share its file with its variants. Any other
  model gets a file of its own: one whose own fields hold another model, and
  one made from two models. A zod schema goes to `schemas/` of its area, and
  its model infers the type from it.

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
