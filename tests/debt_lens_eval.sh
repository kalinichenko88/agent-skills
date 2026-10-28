#!/usr/bin/env bash
# Sends the review of the instruction files, skills/debt/instructions-lens.md,
# to one fixture, with the prompt that step 5 of the debt map gives it, at
# model fable. The fixture is a small monorepo: a root CLAUDE.md, AGENTS.md as
# a symlink to it, a nested apps/web/CLAUDE.md with a copy as AGENTS.md beside
# it, and docs/ARCHITECTURE.md. It prints each report, and exits 1 when a
# report misses one of these checks:
#
# - a repeat or contradiction on CLAUDE.md § Workspaces, whose list repeats
#   the codemap and lacks apps/admin;
# - a repeat on CLAUDE.md § Imports and on CLAUDE.md § Database, which state
#   I-1 and I-2 again;
# - a repeat on apps/web/CLAUDE.md § Routes, which pattern 1 states again;
# - a contradiction on § Types or § Props: type against interface;
# - a contradiction on the intro of docs/ARCHITECTURE.md, which says that the
#   file repeats no instruction file;
# - a redundancy on CLAUDE.md § Database, its incident history, and on
#   CLAUDE.md § Lint, which eslint.config.js enforces;
# - a citation of packages/ui/src/index.ts, whose comment cites § Imports;
# - no finding on CLAUDE.md § Environment, the only place of its text, and no
#   repeat between an AGENTS.md and the CLAUDE.md of its folder: the root
#   pair is one file, and two hosts each read one file of the other pair.
#
# With --codex, Codex reads it in its place, with the same prompt, in its
# read-only sandbox and with the person's Codex config, as step 5 runs it.
#
# It calls the model, so it costs tokens and is not part of `make check`: run
# it by hand after a change to instructions-lens.md.
# It runs with this machine's other plugins and settings.
#
# Usage: tests/debt_lens_eval.sh [--codex] [runs, default 1]

# shellcheck disable=SC2016 # the backticks are Markdown's
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
reader=claude
[ "${1:-}" != --codex ] || { reader=codex; shift; }
runs=${1:-1}
# An argument too many, as `3 --codex`, must not start paid runs.
[ "$#" -le 1 ] && [ "$runs" -ge 1 ] 2>/dev/null || { echo "usage: $0 [--codex] [runs, at least 1]" >&2; exit 2; }
[ "$reader" = claude ] || codex login status >/dev/null 2>&1 || { echo "$0: codex is not installed or not logged in" >&2; exit 2; }
logs=$(mktemp -d)

fixture() {
  local d=$1
  mkdir -p "$d"/apps/{web,admin,api}/src "$d"/apps/web/src/{routes,components} "$d"/apps/api/src/routes "$d"/packages/ui/src "$d"/docs
  git -C "$d" init -q -b main
  git -C "$d" config user.name eval
  git -C "$d" config user.email eval@example.com
  echo '{"name":"shop","private":true,"workspaces":["apps/*","packages/*"]}' >"$d/package.json"
  echo "export default [{ rules: { 'no-console': 'error' } }];" >"$d/eslint.config.js"
  printf '%s\n' '// Do not import from apps/: see CLAUDE.md, "Imports".' \
    'export type ButtonProps = { label: string; onClick: () => void };' \
    'export const Button = (p: ButtonProps) => `<button>${p.label}</button>`;' >"$d/packages/ui/src/index.ts"
  printf '%s\n' "import { Button } from '@shop/ui';" \
    "export const home = () => Button({ label: 'Go', onClick: () => {} });" >"$d/apps/web/src/routes/home.ts"
  printf '%s\n' 'export type CardProps = { title: string };' \
    'export const Card = (p: CardProps) => `<div>${p.title}</div>`;' >"$d/apps/web/src/components/Card.ts"
  printf '%s\n' "import { Button } from '@shop/ui';" \
    "export const admin = () => Button({ label: 'Ban', onClick: () => {} });" >"$d/apps/admin/src/index.ts"
  echo 'export const db = { query: async (sql: string) => [sql] };' >"$d/apps/api/src/db.ts"
  printf '%s\n' "import { db } from '../db';" \
    "export const orders = () => db.query('select * from orders');" >"$d/apps/api/src/routes/orders.ts"
  cat >"$d/CLAUDE.md" <<'EOF'
# Shop

## Commands

- `npm test` runs every workspace's tests.
- `npm run lint` runs ESLint.

## Environment

Copy `.env.example` to `.env` and set `DATABASE_URL` before `npm run dev`.

## Workspaces

- `apps/web` — the shop for customers.
- `apps/api` — the HTTP API and the database.
- `packages/ui` — shared components.

## Imports

A package never imports from `apps/`. An app imports a package by its name,
as `@shop/ui`, never by a relative path.

## Types

Use `type`, never `interface`, for an object shape.

## Database

Only `apps/api` talks to the database. We added this rule after the incident
of 2026-03-14, when `apps/web` queried the orders table directly and a
migration broke the shop for three days (INC-42).

## Lint

Never call `console.log`: the `no-console` rule of ESLint fails the build with
its own message.
EOF
  ln -s CLAUDE.md "$d/AGENTS.md"
  cat >"$d/apps/web/CLAUDE.md" <<'EOF'
# apps/web

## Routes

Routes live in `src/routes/`, one file per route, named after its path.

## Props

Prefer `interface` for the props of a component, so that a consumer can
extend them.
EOF
  cp "$d/apps/web/CLAUDE.md" "$d/apps/web/AGENTS.md"
  cat >"$d/docs/ARCHITECTURE.md" <<'EOF'
# Architecture

This file holds what the code cannot tell. It does not repeat the
instruction files.

## Codemap

- `apps/web` — the shop for customers.
- `apps/admin` — the back office.
- `apps/api` — the HTTP API; it owns the database.
- `packages/ui` — shared components.

## Patterns

1. Each route of `apps/web` is one file in `src/routes/`, named after its
   path.
2. Each route of `apps/api` is one file in `src/routes/` that exports one
   handler.

## Invariants

- **I-1.** A package MUST NOT import from `apps/`.
  Check: grep `from ['"](\.\./)+apps/|from ['"]@shop/(web|admin|api)` in `packages`.
- **I-2.** Only `apps/api` talks to the database.
  Check: grep `db\.query` in `apps` except `apps/api`.
EOF
  git -C "$d" add -A
  git -C "$d" commit -qm "chore: the shop"
}

# The installed copy of the plugin is turned off, so the rules come from this
# checkout. run <run>: the report goes to <run>.txt.
run() {
  local work=$logs/$1 prompt
  fixture "$work"
  prompt="Read $root/skills/debt/instructions-lens.md and do what it says.
Tree: $work
You are one reviewer that another agent runs: start no skill, change no file, and file nothing."
  if [ "$reader" = codex ]; then
    codex exec -s read-only --ephemeral -C "$work" -o "$work.txt" - <<<"$prompt" >"$work.log" 2>&1 || true
    return
  fi
  (cd "$work" && claude -p --model fable --output-format json \
    --settings '{"enabledPlugins":{"kalinichenko@kalinichenko":false}}' \
    --plugin-dir "$root" --dangerously-skip-permissions "$prompt") >"$work.json" 2>&1 || true
  # The text of a session that ends in an error is no report.
  jq -r 'select(.is_error != true) | .result // empty' "$work.json" >"$work.txt" 2>/dev/null || true
}

for i in $(seq "$runs"); do run "$i" & done
wait

# A finding is a line whose kind comes before the first |, as the lens
# returns it, in a list, a table or a code block. Only spaces, * or : stand
# between the kind and the |.
kind='^[[:space:]]*[|]?[^|]*'
# found <kinds> <text>: the count of the report's lines of one of the kinds
# that have the text after the first |.
found() { grep -ciE "${kind}($1)[[:space:]*:]*[|].*($2)" <<<"$report" || true; }
# pair <place> <place>: the count of repeats whose first two places are the
# two, in either order.
pair() {
  local f='[|][[:space:]`*]*(\./)?' r="${kind}repeat[[:space:]*:]*"
  grep -ciE "$r$f$1[^|]*$f$2|$r$f$2[^|]*$f$1" <<<"$report" || true
}
# want and none <kinds> <text> <name>: the report has such a line, or has
# none; else the name joins the misses.
want() { [ "$(found "$1" "$2")" -ge 1 ] || missed="$missed; $3"; }
none() { [ "$(found "$1" "$2")" -eq 0 ] || missed="$missed; $3"; }
failed=0
for i in $(seq "$runs"); do
  report=$(cat "$logs/$i.txt" 2>/dev/null || true)
  missed=
  want 'repeat|contradiction' 'CLAUDE\.md § Workspaces' 'Workspaces'
  want 'repeat' 'CLAUDE\.md § Imports' 'Imports'
  want 'repeat' 'CLAUDE\.md § Database' 'Database repeat'
  want 'repeat' '§ Routes' 'Routes'
  want 'contradiction' '§ (Types|Props)' 'Types'
  want 'contradiction' 'ARCHITECTURE\.md( § Architecture[^|]*)?[[:space:]`*]*[|][^|]*(CLAUDE|AGENTS)\.md' 'the intro'
  want 'redundancy' 'CLAUDE\.md § Database' 'Database history'
  want 'redundancy' 'CLAUDE\.md § Lint' 'Lint'
  want 'citation' 'packages/ui/src/index\.ts' 'citation'
  none 'repeat|contradiction|redundancy' '§ Environment' 'Environment'
  [ "$(pair 'AGENTS\.md' 'CLAUDE\.md')" -eq 0 ] || missed="$missed; the symlink"
  [ "$(pair 'apps/web/AGENTS\.md' 'apps/web/CLAUDE\.md')" -eq 0 ] || missed="$missed; AGENTS.md beside CLAUDE.md"
  if [ -z "$missed" ]; then verdict=pass; else verdict="FAIL${missed}"; failed=1; fi
  echo "== $i: $verdict"
  echo "${report:-no report}"
done
echo "Logs: $logs"
exit "$failed"
