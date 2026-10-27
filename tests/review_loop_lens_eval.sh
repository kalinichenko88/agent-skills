#!/usr/bin/env bash
# Sends the review of the architecture, skills/review-loop/architecture-lens.md,
# to four branches of one fixture, with the prompt that the review loop gives
# it, at model opus and effort high. The fixture's main has one HTTP wrapper,
# and its I-1 says that only the wrapper calls fetch. It prints each report,
# and exits 1 when a report misses the check of its case:
#
# - second-client adds axios beside the wrapper: a Second structure finding;
# - direct-fetch calls fetch in a feature: an Invariant finding that cites I-1;
# - amended is direct-fetch with an ADR that amends I-1 and its Check: line:
#   no Invariant finding that cites I-1;
# - legacy adds a feature that uses the wrapper, on a base whose own code
#   breaks I-1 already: no Invariant finding that cites I-1.
#
# It calls the model, so it costs tokens and is not part of `make check`: run
# it by hand after a change to architecture-lens.md, or to the parts of
# skills/architecture/SKILL.md that the lens reads.
# It runs with this machine's other plugins and settings.
#
# Usage: tests/review_loop_lens_eval.sh [runs of each case, default 1]

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
runs=${1:-1}
[ "$runs" -ge 1 ] 2>/dev/null || { echo "usage: $0 [runs of each case, at least 1]" >&2; exit 2; }
logs=$(mktemp -d)
cases='second-client direct-fetch amended legacy'

commit() {
  git -C "$1" add .
  git -C "$1" commit -qm "$2"
}

# The architecture file of main: I-1 with no exception, and no ADR.
architecture() {
  cat >"$1/docs/ARCHITECTURE.md" <<'EOF'
# Architecture

A small web client of a shop. `src/api/` talks to the server, and each
folder of `src/features/` holds one screen.

## Modules

| Module | Folder | Public API |
| --- | --- | --- |
| api | `src/api/` | `request()` in `src/api/client.ts` |
| a feature | `src/features/<name>/` | its `index.ts` |

A feature uses `api`. `api` uses no feature.

## Invariants

- **I-1.** Only `src/api/client.ts` calls `fetch`: every request goes through
  `request()`, which sets the base URL, the token and the retry.
  Check: grep `fetch\(` in `src` except `src/api/client.ts`.

## ADRs

None yet.
EOF
}

reports_by_fetch() {
  mkdir -p "$1/src/features/reports"
  cat >"$1/src/features/reports/index.ts" <<'EOF'
export async function exportReport(month: string): Promise<string> {
  const res = await fetch(`/api/reports/${month}.csv`, {
    headers: { Authorization: `Bearer ${localStorage.getItem('token') ?? ''}` },
  });
  if (!res.ok) throw new Error(`${res.status} report ${month}`);
  return res.text();
}
EOF
}

# fixture <dir>: main, and a branch for each case. legacy-base is main with
# a call to fetch outside the wrapper.
fixture() {
  local work=$1
  mkdir -p "$work/src/api" "$work/src/features/orders" "$work/docs"
  git -C "$work" init -q -b main
  git -C "$work" config user.name eval
  git -C "$work" config user.email eval@example.com
  echo '{"name":"shop","private":true,"type":"module"}' >"$work/package.json"
  cat >"$work/src/api/client.ts" <<'EOF'
const BASE = '/api';

export async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = { ...init.headers, Authorization: `Bearer ${token()}` };
  for (let attempt = 0; ; attempt++) {
    const res = await fetch(BASE + path, { ...init, headers });
    if (res.ok) return res.json() as Promise<T>;
    if (res.status < 500 || attempt === 2) throw new Error(`${res.status} ${path}`);
  }
}

function token(): string {
  return localStorage.getItem('token') ?? '';
}
EOF
  cat >"$work/src/features/orders/index.ts" <<'EOF'
import { request } from '../../api/client';

export type Order = { id: string; total: number };

export function listOrders(): Promise<Order[]> {
  return request<Order[]>('/orders');
}
EOF
  architecture "$work"
  commit "$work" "feat: list the orders"

  git -C "$work" checkout -qb second-client main
  mkdir -p "$work/src/features/reports"
  echo '{"name":"shop","private":true,"type":"module","dependencies":{"axios":"^1.7.0"}}' >"$work/package.json"
  cat >"$work/src/features/reports/index.ts" <<'EOF'
import axios from 'axios';

const http = axios.create({ baseURL: '/api' });

http.interceptors.request.use((config) => {
  config.headers.Authorization = `Bearer ${localStorage.getItem('token') ?? ''}`;
  return config;
});

export type Report = { month: string; total: number };

export async function listReports(): Promise<Report[]> {
  const res = await http.get<Report[]>('/reports');
  return res.data;
}
EOF
  commit "$work" "feat: list the reports"

  git -C "$work" checkout -qb direct-fetch main
  reports_by_fetch "$work"
  commit "$work" "feat: export a report as CSV"

  git -C "$work" checkout -qb amended direct-fetch
  mkdir -p "$work/docs/adr"
  cat >"$work/docs/adr/0001-reports-call-fetch.md" <<'EOF'
# 0001 The CSV export of a report calls fetch

- Status: accepted
- Date: 2026-10-27

## Context

The CSV export of a report is text. `request()` in `src/api/client.ts` reads
each answer with `res.json()`, and retries a failed request up to three times.

## Options considered

- A `text` flag on `request()`: a flag for one caller, and the retry would
  download a large export again.
- `exportReport()` calls `fetch` itself, with the token header.

## Decision

We will let `src/features/reports/index.ts` call `fetch` for the CSV export.

## Consequences

Good: `request()` keeps one type of answer and no flag.
Bad: the export sets the token header itself, and has no retry.

## Invariants

Amends I-1.

## Confirmation

The `Check:` line of I-1 leaves out `src/features/reports/index.ts`.
EOF
  architecture "$work"
  awk '
    /^  `request\(\)`, which sets/ { print; print "  The CSV export of `src/features/reports/index.ts` calls `fetch` too (ADR 0001)."; next }
    /^  Check: grep/ { sub(/`src\/api\/client.ts`\./, "`src/api/client.ts` `src/features/reports/index.ts`.") }
    /^None yet\.$/ { print "- [0001 The CSV export of a report calls fetch](adr/0001-reports-call-fetch.md)"; next }
    { print }
  ' "$work/docs/ARCHITECTURE.md" >"$work/docs/ARCHITECTURE.md.new"
  mv "$work/docs/ARCHITECTURE.md.new" "$work/docs/ARCHITECTURE.md"
  commit "$work" "feat: export a report as CSV, by ADR 0001"

  git -C "$work" checkout -qb legacy-base main
  mkdir -p "$work/src/legacy"
  cat >"$work/src/legacy/ping.ts" <<'EOF'
export async function ping(): Promise<boolean> {
  const res = await fetch('/api/ping');
  return res.ok;
}
EOF
  commit "$work" "feat: ping the server"

  git -C "$work" checkout -qb legacy legacy-base
  mkdir -p "$work/src/features/reports"
  cat >"$work/src/features/reports/index.ts" <<'EOF'
import { request } from '../../api/client';

export type Report = { month: string; total: number };

export function listReports(): Promise<Report[]> {
  return request<Report[]>('/reports');
}
EOF
  commit "$work" "feat: list the reports"
}

# The base of each case: the branch it starts from.
base() {
  case $1 in
    legacy) echo legacy-base ;;
    *) echo main ;;
  esac
}

# The installed copy of the plugin is turned off, so the rules come from this
# checkout. The last line of the prompt is the one that review-loop gives
# Codex as a reader: claude -p runs as a main session, not as a subagent.
run() {
  local name=$1 work=$logs/$1
  local kase=${name%-[0-9]*}
  fixture "$work"
  git -C "$work" checkout -q "$kase"
  local prompt
  prompt="Read $root/skills/review-loop/architecture-lens.md and do what it says.
Range: $(git -C "$work" rev-parse "$(base "$kase")")..$(git -C "$work" rev-parse HEAD)
Tree: $work
You are one reviewer that another agent runs: start no skill, change no file, and file nothing."
  (cd "$work" && claude -p --model opus --effort high --output-format json \
    --settings '{"enabledPlugins":{"kalinichenko@kalinichenko":false}}' \
    --plugin-dir "$root" --dangerously-skip-permissions "$prompt") >"$work.json" 2>&1
}

for i in $(seq "$runs"); do
  for kase in $cases; do
    run "$kase-$i" &
  done
done
wait

# A finding is a line whose kind comes before the first |, as the lens
# returns it, in a list or a table.
kind='^[[:space:]]*[|]?[^|]*'
failed=0
for i in $(seq "$runs"); do
  for kase in $cases; do
    report=$(jq -r '.result // empty' "$logs/$kase-$i.json" 2>/dev/null || true)
    invariant=$(grep -ciE "${kind}invariant[^|]*[|].*I-1([^0-9]|\$)" <<<"$report" || true)
    second=$(grep -ciE "${kind}second structure[^|]*[|]" <<<"$report" || true)
    case $kase in
      second-client) ok=$([ "$second" -ge 1 ] && echo 1 || echo 0) ;;
      direct-fetch) ok=$([ "$invariant" -ge 1 ] && echo 1 || echo 0) ;;
      *) ok=$([ "$invariant" -eq 0 ] && [ -n "$report" ] && echo 1 || echo 0) ;;
    esac
    echo "== $kase-$i: $second Second structure, $invariant Invariant on I-1: $([ "$ok" -eq 1 ] && echo pass || echo FAIL)"
    echo "${report:-no report}"
    [ "$ok" -eq 1 ] || failed=1
  done
done
echo "Logs: $logs"
exit "$failed"
