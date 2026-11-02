#!/usr/bin/env bash
# Sends the citations job of skills/github/scout.md to one fixture, with the
# prompt that *Finishing* of skills/github/SKILL.md gives it, at model haiku.
# The fixture is a log server after a merged pull request that made the choice
# of #40: the server rotates its own log, and a logrotate entry was rejected.
# The scout's file holds two open issues on the changed src/server/main.ts:
#
# - #42 proposes a logrotate entry and waits on that choice. Its one citation
#   holds: no line it cites moved.
# - #43 asks for a timestamp. The decision leaves it true.
#
# It prints each report, and exits 1 when a report gives no sentence of #42 as
# false by decision 1, or gives one of #43.
#
# It calls the model, so it costs tokens and is not part of `make check`: run
# it by hand after a change to the citations job of scout.md or to *Finishing*.
# It runs with this machine's other plugins and settings.
#
# Usage: tests/github_scout_eval.sh [runs, default 3]

# shellcheck disable=SC2016 # the backticks are Markdown's
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
runs=${1:-3}
[ "$#" -le 1 ] && [ "$runs" -ge 1 ] 2>/dev/null || { echo "usage: $0 [runs, at least 1]" >&2; exit 2; }
logs=$(mktemp -d)

fixture() {
  local d=$1
  mkdir -p "$d/tree/src/server"
  git -C "$d/tree" init -q -b main
  git -C "$d/tree" config user.name eval
  git -C "$d/tree" config user.email eval@example.com
  printf '%s\n' "import { appendFileSync } from 'node:fs';" '' \
    'export const openLog = (path: string) => ({ path });' '' \
    'export const writeLine = (log: { path: string }, message: string) => {' \
    '  appendFileSync(log.path, `${message}\n`);' '};' >"$d/tree/src/server/log.ts"
  printf '%s\n' "import { openLog, writeLine } from './log';" "import { rotateAt } from './rotate';" '' \
    "const log = openLog('/var/log/server.log');" "writeLine(log, 'started');" \
    'rotateAt(log.path, 10 * 1024 * 1024);' >"$d/tree/src/server/main.ts"
  printf '%s\n' "import { renameSync, statSync } from 'node:fs';" '' \
    '// Rotates the log at a size limit: the server keeps one old file, server.log.1.' \
    'export const rotateAt = (path: string, limit: number) => {' \
    '  if (statSync(path).size >= limit) renameSync(path, `${path}.1`);' '};' >"$d/tree/src/server/rotate.ts"
  git -C "$d/tree" add -A
  git -C "$d/tree" commit -qm "feat(log): rotate the server's own log at 10 MB"
  cat >"$d/collect.txt" <<'EOF'
# collect.sh filing in acme/log-server

== Open issues

#43 Log lines have no timestamp [enhancement] open
#42 Rotated logs are not compressed, so the old files fill the disk [enhancement] open

== Search: src/server/main.ts

#43 Log lines have no timestamp [enhancement] open
#42 Rotated logs are not compressed, so the old files fill the disk [enhancement] open
#40 The server's log grows without bound [enhancement] closed

== Search: main.ts

#43 Log lines have no timestamp [enhancement] open
#42 Rotated logs are not compressed, so the old files fill the disk [enhancement] open
#40 The server's log grows without bound [enhancement] closed

== Search: src/server/rotate.ts

== Search: rotate.ts

== Bodies

==> #43 Log lines have no timestamp [enhancement] open
status: free
also: 0

**Where.** `src/server/main.ts:5` writes `started`, and `writeLine` (`src/server/log.ts:5-7`) appends the message as it is, with no time.

**Proposal.** Prefix each line with the ISO time in `writeLine`.

==> #42 Rotated logs are not compressed, so the old files fill the disk [enhancement] open
status: free
also: 0

**Where.** `src/server/main.ts:4` opens the log with `openLog`, and nothing rotates or compresses it.

**Waits on.** #40, which chooses between a logrotate entry in the package and the server's own rotation.

**Proposal.** Add `compress` and `rotate 7` to the logrotate entry that #40 adds to the package.

== end: 2 entries
EOF
}

# The installed copy of the plugin is turned off, so the rules come from this
# checkout. run <run>: the report goes to <run>.txt.
run() {
  local work=$logs/$1 prompt
  fixture "$work"
  prompt="Read $root/skills/github/scout.md and do what it says.
Job: citations.
Tree: $work/tree
Decision 1: The server rotates its own log at 10 MB, in src/server/rotate.ts. A logrotate entry in the package was rejected: it needs root on each host.
File: $work/collect.txt
Collector: bash $root/skills/github/scripts/collect.sh"
  (cd "$work/tree" && claude -p --model haiku --output-format json \
    --settings '{"enabledPlugins":{"craft@kalinichenko":false,"kalinichenko@kalinichenko":false}}' \
    --plugin-dir "$root" --dangerously-skip-permissions "$prompt") >"$work.json" 2>&1 || true
  # The text of a session that ends in an error is no report.
  jq -r 'select(.is_error != true) | .result // empty' "$work.json" >"$work.txt" 2>/dev/null || true
}

for i in $(seq "$runs"); do run "$i" & done
wait

# falsified <n>: the count of lines in the block of issue #<n> that give a
# quoted sentence as false by a numbered decision. A block starts at a line
# that opens with the issue's number, after spaces or Markdown marks.
falsified() {
  awk -v n="$1" '
    /^[[:space:]*`>|-]*#[0-9]+([^0-9]|$)/ { s = $0; sub(/^[^#]*#/, "", s); sub(/[^0-9].*/, "", s); cur = s }
    cur == n && tolower($0) ~ /false/ && tolower($0) ~ /decision[^0-9]*[0-9]/ && /"/ { c++ }
    END { print c + 0 }' <<<"$report"
}
failed=0
for i in $(seq "$runs"); do
  report=$(cat "$logs/$i.txt" 2>/dev/null || true)
  missed=
  [ "$(falsified 42)" -ge 1 ] || missed="$missed; no false sentence of #42"
  [ "$(falsified 43)" -eq 0 ] || missed="$missed; a false sentence of #43"
  if [ -z "$missed" ]; then verdict=pass; else verdict="FAIL${missed}"; failed=1; fi
  echo "== $i: $verdict"
  echo "${report:-no report}"
done
echo "Logs: $logs"
exit "$failed"
