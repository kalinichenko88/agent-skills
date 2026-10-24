#!/usr/bin/env bash
# Gives two TypeScript tasks and two React tasks to Haiku subagents and counts
# the runs that invoke the conventions skills before their first write, then
# the written files with an implicit return in a method callback, then the
# order runs with a file that does not open with its primary export, then the
# feature runs that put a sub-component's own hook at the feature root or in
# `shared`. It calls the model, so it costs tokens and is not part of
# `make check`: run it by hand after a change to rules.md or to a skill's
# description. It runs with this machine's other plugins and settings, the
# setup the rules must work in.
#
# Usage: tests/skill_load_eval.sh [runs per task, default 5]

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
runs=${1:-5}
[ "$runs" -ge 1 ] 2>/dev/null || { echo "usage: $0 [runs per task, at least 1]" >&2; exit 2; }
logs=$(mktemp -d)

ts_task='Add src/cart-total.ts to this project. A cart item has an id, a name, a unit price in cents and a quantity. Export a function that returns the cart total in cents, skipping items with quantity 0, and a function that returns the names of the items whose unit price is over a given limit. Write the file, then reply with its contents.'
order_task='Add an order feature to this project, in src/. An order has an id, a customer and a list of lines. A line has a product id, a quantity and a unit price in cents. A customer has an id, a name and a discount, which is either a percent or a fixed amount in cents. Add a function that returns the order total in cents after the customer discount, and a function that returns a text summary of the order, one row per line and the total at the end, each in its own file. Both functions use the same order, line, customer and discount types. Write the files, then reply with the path and the contents of every file you wrote.'
react_task='Add src/search-panel.tsx to this project: a React component with a text input and a Search button. On submit it fetches /api/search?q=<the text>, which returns a JSON array of { id, title, url }. While the request runs it shows "Loading…", on failure it shows the error message, and on success it shows the results as a list of links. Write the file, then reply with its contents.'
feature_task='Add a products feature to this project, in src/features/products/. Its page shows a filter panel and a grid of products. The filter panel keeps the values the user is typing in a hook that only the panel uses, and it waits 300 ms after the last keystroke before it applies them: keep that number in a constant. The page loads the products once from GET /api/products, which returns a JSON array of { id, name, price, category }, and the grid shows the products that match the applied filters. Write the files, then reply with the path and the contents of every file you wrote.'
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

# first <dir>...: the order runs whose every written file opens with an export
# after its imports, as typescript-conventions asks of the primary export. It
# prints the first line of each file that opens with something else. The
# recorded runs that broke the rule put a helper or an Intl constant there.
first() {
  local ok=0 dir list file line bad
  for dir; do
    list=$(find "$dir/src" -name '*.ts')
    [ -n "$list" ] || { echo "no file written: $dir/src" && continue; }
    bad=0
    while IFS= read -r file; do
      # The first line past the imports, blank lines and comments.
      line=$(awk '/^import/ { open = !/;[[:space:]]*$/; next }
        open { if (/;[[:space:]]*$/) open = 0; next }
        /^[[:space:]]*$/ || /^[[:space:]]*(\/\/|\/\*|\*)/ { next }
        { print; exit }' "$file")
      case $line in export*) ;; *) echo "$file: $line" && bad=1 ;; esac
    done <<<"$list"
    [ "$bad" -eq 1 ] || ok=$((ok + 1))
  done
  echo "export first: $ok of $# order runs open every file with an export"
  [ "$ok" -eq "$#" ] || failed=1
}

# nested <dir>...: the feature runs that keep the filter panel's own hook out
# of the feature root and out of `shared`, as react-conventions asks. It prints
# each hook it finds there. The recorded runs without the rule wrote it as
# src/features/products/use-filter-draft.ts.
# ponytail: it checks only that shape, a `use-*` file found by its name. Each
# of these passes: a feature-level hooks/ folder, a hook in the grid's folder,
# a hook in src/hooks or another folder outside the feature, a camelCase name,
# a hook folder with an index.ts, a hook in a folder named shared inside the
# feature, a constant file at the feature root. A `use-*` file inside a `use-*`
# folder at the feature root counts as a hook at the root. Each of these
# fails, though the skill allows it: a page's own `use-*` hook at the feature
# root, a generic `use-*` hook in src/shared. No recorded run wrote any of
# these, so add a case when a run does.
nested() {
  local ok=0 dir found
  for dir; do
    [ -d "$dir/src/features/products" ] || { echo "no feature written: $dir" && continue; }
    found=$(find "$dir/src" -type f -name 'use-*' \( -path "$dir/src/features/products/use-*" -o -path "$dir/src/shared/*" \))
    if [ -n "$found" ]; then echo "$found"; else ok=$((ok + 1)); fi
  done
  echo "own folder: $ok of $# feature runs keep the panel's hook out of the feature root and shared"
  [ "$ok" -eq "$#" ] || failed=1
}

for i in $(seq "$runs"); do
  run "$ts_task" "$logs/ts-$i.jsonl" &
  run "$react_task" "$logs/react-$i.jsonl" &
  run "$order_task" "$logs/order-$i.jsonl" &
  run "$feature_task" "$logs/feature-$i.jsonl" &
done
wait

failed=0
count typescript-conventions "$logs"/ts-*.jsonl "$logs"/react-*.jsonl "$logs"/order-*.jsonl "$logs"/feature-*.jsonl
count react-conventions "$logs"/react-*.jsonl "$logs"/feature-*.jsonl
files=()
for i in $(seq "$runs"); do
  files+=("$logs/ts-$i/src/cart-total.ts" "$logs/react-$i/src/search-panel.tsx")
done
braced "${files[@]}"
first "$logs"/order-*/
nested "$logs"/feature-*/
echo "logs: $logs"
exit "$failed"
