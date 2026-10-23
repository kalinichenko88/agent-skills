---
name: typescript-conventions
description: Use when writing or reviewing TypeScript — declaring an object shape, naming a new file, writing a callback, reaching for a dependency — or when setting up lint rules for a new TypeScript project.
---

# TypeScript conventions

A codebase that consistently does otherwise wins — match it and say so.

## Object shapes are `type`, never `interface`

```ts
type User = { id: string; name: string };    // yes
interface User { id: string; name: string }  // no
```

Extension is intersection: `type Admin = User & { role: Role }`.

`interface` is correct for exactly two things — declaration merging and module
augmentation (`declare module 'x' { interface Y { … } }`). Each one carries a
comment naming which; without it it reads as a slip.

Biome: `lint/style/useConsistentTypeDefinitions` at `error`, `style: "type"`.
ESLint: `@typescript-eslint/consistent-type-definitions` set to `"type"`.
Biome does not see `interface X extends Y` — close that bypass with an AST check
only where the guarantee matters.

## `strict: true`, and no `any`

Reach for `unknown` plus a narrowing guard, or a generic. An `any` that survives
review is a type hole, not a shortcut.

## Checking the container does not check the items

```ts
const data: unknown = await response.json();

if (!Array.isArray(data) || !data.every(isSearchResult)) {
  throw new Error('The search response has an unexpected shape');
}

return data;
```

`response.json()` and `JSON.parse` return `any`, so the `unknown` annotation is
part of the check. `Array.isArray` then narrows `unknown` to `any[]` — in
TypeScript 5.x, 6.0 and 7.0 alike. After it, the compiler accepts any use of
the items, so `data as SearchResult[]` checks the array and only asserts each
item: an item without `url` reaches the render as `undefined`. Narrow every
item with a guard, or with the schema library the project already has. A cast
left after a check hides the part that the check did not do.

No shared typescript-eslint config catches that cast. Turn the rule on over the
typed config, with old violations in bulk suppressions (next section):

```js
'@typescript-eslint/no-unsafe-type-assertion': 'error',
```

## A lint rule is `error`, or it is off

`warn` fails nothing. CI passes it, `--quiet` hides it, and the count only
grows. A rule worth having is `error` from the first day. Old violations go to
ESLint's bulk suppressions, not to `warn` on a legacy glob:

```sh
npx eslint . --suppress-rule @typescript-eslint/no-explicit-any
```

Commit `eslint-suppressions.json`. A new violation fails the check. A fixed one
leaves the file with `--prune-suppressions`, so the count only goes down.
Suppressions apply only to rules set to `error`.

## Bodies are braced and expanded

No implicit arrow returns in callbacks and handlers, no one-line braced `if`.
The body goes on its own line, even when it is one statement.

## A blank line goes before `return`

```ts
if (!user) {
  return null;               // only statement in the block — no blank line
}

const name = user.name.trim();

return name;
```

A `return` that is the only statement in its block takes no blank line.

## Render conditions are named constants

```tsx
const settings = config.data?.settings;
const needsInvoiceSetup = settings !== undefined && !isConfigured(settings);

if (needsInvoiceSetup) {
  return <List>…</List>;
}
```

The condition is declared above the return with the other consts, and the name
says what the branch means, not how it is computed. Inline,
`config.data && !isConfigured(config.data.settings)` makes the reader evaluate
the expression to find out what the screen is about.

Narrowing survives the alias only for a `const` holding a whole value. A `let`
drops it, and so does a condition written against `config.data` — bind the value
first, as above, or the branch loses the `undefined` check it just made.

## A branch becomes a component when it has handlers and depth

Both, not either: callbacks of its own — `onClick`, `onSubmit`, `onChange` — and
JSX nested deeper than two levels. Declarative markup stays where it is, however
wordy; a file and a jump buy nothing there.

```tsx
if (needsInvoiceSetup) {    // stays — no handlers, nothing to carry away
  return (
    <List>
      <List.Item
        icon={Icon.Gear}
        title="Fill in the invoice details first"
        actions={
          <ActionPanel>
            <Action.Push title="Open Settings" target={<Settings />} />
          </ActionPanel>
        }
      />
    </List>
  );
}

if (isEditingLineItems) {   // goes — onChange and onRemove per row, three deep
  return <LineItemEditor items={items} onSave={saveLineItems} />;
}
```

What moves with the extracted component is its state and its handlers, which is
the point; the early returns above it stay a table of contents for the screen.
Loading and empty states — `return <Form isLoading />` — are the same case,
already one line.

## Reach for the runtime before a dependency

Node and Bun ship most of what a utility library used to. Check the engine the
project pins — `engines`, the Docker base image — before installing anything or
writing a formatter by hand.

| Instead of | Use |
| --- | --- |
| date-fns, moment, hand-rolled date strings | `Intl.DateTimeFormat`, `Intl.RelativeTimeFormat` |
| a currency or percent helper | `Intl.NumberFormat` |
| pluralize | `Intl.PluralRules` |
| lodash `groupBy`, `cloneDeep` | `Object.groupBy`, `structuredClone` |
| axios | `fetch` |
| p-timeout, a manual `AbortController` timer | `AbortSignal.timeout` |

`Intl` takes locale and time zone as arguments — pass them explicitly rather
than inheriting whatever the host has.

## Files are kebab-case, one entity per file

`create-vault.ts`, not `createVault.ts`. Intra-file order: imports → the primary
export → private helpers below it.
