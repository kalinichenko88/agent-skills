#!/usr/bin/env bash
# Gives a TypeScript task and a React task to Haiku subagents and counts the
# runs that invoke the conventions skills before their first write, then the
# written files with an implicit return in a method callback. It calls
# the model, so it costs tokens and is not part of `make check`: run it by hand
# after a change to rules.md or to a skill's description. It runs with this
# machine's other plugins and settings, the setup the rules must work in.
#
# Usage: tests/skill_load_eval.sh [runs per task, default 5]

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
runs=${1:-5}
[ "$runs" -ge 1 ] 2>/dev/null || { echo "usage: $0 [runs per task, at least 1]" >&2; exit 2; }
logs=$(mktemp -d)

ts_task='Add src/cart-total.ts to this project. A cart item has an id, a name, a unit price in cents and a quantity. Export a function that returns the cart total in cents, skipping items with quantity 0, and a function that returns the names of the items whose unit price is over a given limit. Write the file, then reply with its contents.'
react_task='Add src/search-panel.tsx to this project: a React component with a text input and a Search button. On submit it fetches /api/search?q=<the text>, which returns a JSON array of { id, title, url }. While the request runs it shows "Loading…", on failure it shows the error message, and on success it shows the results as a list of links. Write the file, then reply with its contents.'
# One Haiku session that hands the task to one Haiku subagent, as the main
# model does with routine work. The installed copy of the plugin is turned off,
# so the skill list and the rules come from this checkout. The files it writes
# stay next to its log.
run() {
  local work=${2%.jsonl}
  mkdir -p "$work/src"
  echo '{"type":"module","dependencies":{"react":"^19.2.0"},"devDependencies":{"typescript":"^5.9.0","@types/react":"^19.2.0"}}' >"$work/package.json"
  echo '{"compilerOptions":{"strict":true,"jsx":"react-jsx","noEmit":true},"include":["src"]}' >"$work/tsconfig.json"
  (cd "$work" && claude -p --model haiku --output-format stream-json --verbose \
    --settings '{"enabledPlugins":{"kalinichenko@kalinichenko":false}}' \
    --plugin-dir "$root" --dangerously-skip-permissions \
    "Make exactly one Agent tool call: subagent_type \"general-purpose\", model \"haiku\", and as its prompt the text between the lines below, copied verbatim. Do nothing else. Then reply with what the agent returned.
---
$1
---") >"$2" 2>&1
}

# count <skill> <log>...: the runs whose subagent invoked the skill before its
# first Write or Edit. A run with no write at all does not count.
count() {
  local skill=$1 loaded=0 log calls
  shift
  for log; do
    calls=$(jq -rR 'fromjson? | select(.type == "assistant" and .parent_tool_use_id != null)
      | .message.content[] | select(.type == "tool_use")
      | if .name == "Skill" then .input.skill else .name end' "$log")
    if [ -z "$calls" ]; then
      echo "no subagent ran, see $log"
    elif awk '/^(Write|Edit)$/ { printf "%s", seen; exit } { seen = seen $0 "\n" }' <<<"$calls" |
      grep -qx "kalinichenko:$skill"; then
      loaded=$((loaded + 1))
    fi
  done
  echo "$skill: $loaded of $# subagents invoked it before the first write"
  [ "$loaded" -eq "$#" ] || failed=1
}

# braced <file>...: the written files with no implicit arrow return, which the
# brace rule of typescript-conventions forbids. It prints each one it finds.
# It sees only an arrow that is a method's first argument, as `.map((x) => (`
# and `.filter((x) => x.done)`: the shape the recorded runs wrote.
braced() {
  local implicit='\.[[:alnum:]_]+\(\(?[^()]*\)? *=> *([^{ ]|$)' ok=0 file
  for file; do
    if [ ! -f "$file" ]; then
      echo "no file written: $file"
    elif ! grep -HnE "$implicit" "$file"; then
      ok=$((ok + 1))
    fi
  done
  echo "brace rule: $ok of $# written files have no implicit arrow return"
  [ "$ok" -eq "$#" ] || failed=1
}

for i in $(seq "$runs"); do
  run "$ts_task" "$logs/ts-$i.jsonl" &
  run "$react_task" "$logs/react-$i.jsonl" &
done
wait

failed=0
count typescript-conventions "$logs"/ts-*.jsonl "$logs"/react-*.jsonl
count react-conventions "$logs"/react-*.jsonl
files=()
for i in $(seq "$runs"); do
  files+=("$logs/ts-$i/src/cart-total.ts" "$logs/react-$i/src/search-panel.tsx")
done
braced "${files[@]}"
echo "logs: $logs"
exit "$failed"
