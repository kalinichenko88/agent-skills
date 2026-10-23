#!/usr/bin/env bash
# Gives a TypeScript task and a React task to Haiku subagents and counts the
# runs that invoke the conventions skill before their first write. It calls the
# model, so it costs tokens and is not part of `make check`: run it by hand
# after a change to rules.md or to a skill's description.
#
# Usage: tests/skill_load_eval.sh [runs per task, default 5]

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
runs=${1:-5}
logs=$(mktemp -d)

ts_task='Add src/cart-total.ts to this project. A cart item has an id, a name, a unit price in cents and a quantity. Export a function that returns the cart total in cents, skipping items with quantity 0, and a function that returns the names of the items whose unit price is over a given limit. Write the file, then reply with its contents.'
react_task='Add src/search-panel.tsx to this project: a React component with a text input and a Search button. On submit it fetches /api/search?q=<the text>, which returns a JSON array of { id, title, url }. While the request runs it shows "Loading…", on failure it shows the error message, and on success it shows the results as a list of links. Write the file, then reply with its contents.'

# One Haiku session that hands the task to one Haiku subagent, as the main
# model does with routine work. The installed copy of the plugin is turned off,
# so the skill list and the rules come from this checkout.
run() {
  local work
  work=$(mktemp -d)
  mkdir "$work/src"
  echo '{"type":"module","dependencies":{"react":"^19.2.0"},"devDependencies":{"typescript":"^5.9.0","@types/react":"^19.2.0"}}' >"$work/package.json"
  echo '{"compilerOptions":{"strict":true,"jsx":"react-jsx","noEmit":true},"include":["src"]}' >"$work/tsconfig.json"
  (cd "$work" && claude -p --model haiku --output-format stream-json --verbose \
    --settings '{"enabledPlugins":{"kalinichenko@kalinichenko":false}}' \
    --plugin-dir "$root" --dangerously-skip-permissions \
    "Make exactly one Agent tool call: subagent_type \"general-purpose\", model \"haiku\", and as its prompt the text between the lines below, copied verbatim. Do nothing else. Then reply with what the agent returned.
---
$1
---") >"$2" 2>&1 || true
}

# The skills the subagent invoked before its first Write, one per line.
before_write() {
  jq -r 'select(.type == "assistant" and .parent_tool_use_id != null)
    | .message.content[] | select(.type == "tool_use")
    | if .name == "Skill" then .input.skill else .name end' "$1" 2>/dev/null |
    sed '/^Write$/q' | grep conventions || true
}

for i in $(seq "$runs"); do
  run "$ts_task" "$logs/ts-$i.jsonl" &
  run "$react_task" "$logs/react-$i.jsonl" &
done
wait

failed=0
for check in ts:typescript-conventions react:react-conventions; do
  task=${check%%:*} skill=kalinichenko:${check#*:} loaded=0
  for log in "$logs/$task"-*.jsonl; do
    before_write "$log" | grep -qx "$skill" && loaded=$((loaded + 1))
  done
  echo "$task: $loaded of $runs subagents invoked $skill before the first write"
  [ "$loaded" -eq "$runs" ] || failed=1
done
echo "logs: $logs"
exit "$failed"
