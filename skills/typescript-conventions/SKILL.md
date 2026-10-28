---
name: typescript-conventions
description: Use when writing or reviewing TypeScript — declaring an object shape, placing a type, an enum or a schema that several files use, naming a new file or a constant, writing a callback, reaching for a dependency — or when setting up lint rules for a new TypeScript project.
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
the items. `Array.isArray` checks the container; `data as SearchResult[]`
checks nothing and only asserts each item: an item without `url` reaches the
render as `undefined`. Narrow every
item with a guard, or with the schema library the project already has. A cast
left after a check hides the part that the check did not do.

## Bodies are braced and expanded

No implicit arrow returns in callbacks and handlers, no one-line braced `if`.
The body goes on its own line, even when it is one statement.

```tsx
const inStock = items.filter((item) => {
  return item.quantity > 0;
});

{results.map((result) => {
  return (
    <li key={result.id}>
      <a href={result.url}>{result.title}</a>
    </li>
  );
})}
```

JSX is no exception. `results.map((result) => (<li …>…</li>))` is an implicit
return too: a callback that renders a list takes braces and a `return`.

## A blank line goes before `return`

```ts
if (!user) {
  return null;               // only statement in the block — no blank line
}

const name = user.name.trim();

return name;
```

A `return` that is the only statement in its block takes no blank line.

## Render conditions get a name

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
export → everything it uses below it: private helpers, module-level `const`s,
and the types that only this file uses. A file opens with what it is for.

```ts
import type { Order } from './models/order';

export function orderSummary(order: Order): string {
  const rows = order.lines.map((line) => {
    return `${line.productId} × ${line.quantity}: ${formatCents(line.quantity * line.unitPriceCents)}`;
  });

  return rows.join('\n');
}

const money = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });

function formatCents(cents: number): string {
  return money.format(cents / 100);
}
```

Not: `const money` and `formatCents` above `orderSummary`. A `const` below the
export is safe: the function reads it when it runs, after the module has
loaded.

A tagged union's file opens with the union. Its variants go below it, exported
or not: the union uses them, and a type can name a type declared below it.

```ts
// models/discount.ts
export type Discount = PercentDiscount | FixedDiscount;

export type PercentDiscount = { kind: 'percent'; percent: number };

export type FixedDiscount = { kind: 'fixed'; amountCents: number };
```

A literal of more than 15 lines — a list of entries, a lookup table, a config
such as column definitions or filter descriptors — goes to a `constants.ts`
beside the file that uses it, even when only that one file uses it. The lines
of the literal count, not those of the declaration around it. A shorter
literal stays below the export. `constants.ts` is the one exception to one
entity per file: it holds every long literal of its folder.

```ts
// constants.ts
export const SHIPPING_COUNTRIES = [
  { code: 'AT', name: 'Austria' },
  { code: 'BE', name: 'Belgium' },
  // … 28 more countries, one per line
];
```

```ts
// shipping-country.ts
import { SHIPPING_COUNTRIES } from './constants';

export function shippingCountryName(code: string): string {
  const country = SHIPPING_COUNTRIES.find((entry) => {
    return entry.code === code;
  });

  return country?.name ?? OTHER_COUNTRY;
}

const OTHER_COUNTRY = 'Another country';
```

Not: the 30 countries below `shippingCountryName` in its own file, and not
`OTHER_COUNTRY` in `constants.ts`.

## A constant's name is CONSTANT_CASE

A constant is a module-level `const` whose value is a literal in the code: a
string, a number, a boolean, or an array or object made only of these. The
value is fixed when the code is written, as a constant of a compiled language.

```ts
const MAX_RETRIES = 3;
const FALLBACK_MESSAGE = 'The payment failed. Try another card.';
```

Every other `const` is camelCase:

- a value that the code makes when it runs, also at module level:
  `new Intl.NumberFormat(…)`, as `money` above, `Date.now()`, `z.object(…)`,
  `new Map([…])`;
- a `const` inside a function, also when its value is a literal.

Not: `const PRICE_FORMAT = new Intl.NumberFormat(…)`. The formatter is an
object that the module makes when it loads, not a value written in the code.

## A shared type is a model in `models/`, a schema is in `schemas/`

A model is a type or an enum. A model that two files or more use goes to the
`models/` folder of its area: the nearest folder that holds every file that
uses it. One model per file, named after the model. Two cases may share a
file:

- A model made by an operation on one other model may go into that model's
  file: `OrderDraft = Omit<Order, 'id'>`, `PartialOrder = Partial<Order>`,
  `MaybeOrder = Order | null`, `PaidOrder = Order & { paidAt: string }`.
- A tagged (discriminated) union and its variants, which share a tag field,
  may share the union's file: `Discount = PercentDiscount | FixedDiscount`,
  each variant with `kind`.

A model outside these two cases gets a file of its own: one whose own fields
hold another model, as `Order` holds `lines: OrderLine[]`, and one made from
two models, as `Order & Customer`. A type that only one file uses stays in
that file, below the primary export.

A schema, a zod one for instance, goes to the `schemas/` folder of its area,
beside `models/`, one schema per file. A model that has a schema infers its
type from it, so the shape is written once. A model that no code parses has
no schema and is written by hand.

```
orders/
├── models/
│   ├── order.ts         Order, and OrderDraft = Omit<Order, 'id'>
│   ├── order-line.ts    OrderLine
│   ├── customer.ts      Customer, by hand: no code parses it
│   └── discount.ts      Discount = PercentDiscount | FixedDiscount, tagged by kind
├── schemas/
│   ├── order.ts         orderSchema, the response of fetch-orders.ts
│   └── order-line.ts    orderLineSchema
├── fetch-orders.ts
├── order-total.ts
└── order-summary.ts
```

```ts
// schemas/order.ts
import { z } from 'zod';

import { orderLineSchema } from './order-line';

export const orderSchema = z.object({
  id: z.string(),
  customerId: z.string(),
  lines: z.array(orderLineSchema),
});
```

```ts
// models/order.ts
import type { z } from 'zod';

import type { orderSchema } from '../schemas/order';

export type Order = z.infer<typeof orderSchema>;

export type OrderDraft = Omit<Order, 'id'>;
```

Not: `Order`, `OrderLine`, `Customer` and `Discount` together in one
`order.ts`, and not a schema beside the fetch that parses with it.
