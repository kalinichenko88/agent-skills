#!/usr/bin/env bash
# Gives three TypeScript tasks and three React tasks to Haiku subagents, and
# runs the checks below on what they did: each check says what it counts. Its
# runs call the model, so they cost tokens and are not part of `make check`:
# run it by hand after a change to rules.md, to a skill's description or to the
# text of a conventions skill. It runs with this machine's other plugins and
# settings, the setup the rules must work in.
#
# With --check, it runs only the checks, on the logs folder of an earlier run.
# `make check` runs them so on tests/fixtures/skill_load, through
# tests/skill_load_checks_test.sh.
#
# Usage: tests/skill_load_eval.sh [runs per task, default 5]
#        tests/skill_load_eval.sh --check <logs folder>

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
usage() { echo "usage: $0 [runs per task, at least 1] | --check <logs folder>" >&2; exit 2; }

ts_task='Add src/cart-total.ts to this project. A cart item has an id, a name, a unit price in cents and a quantity. Export a function that returns the cart total in cents, skipping items with quantity 0, and a function that returns the names of the items whose unit price is over a given limit. Write the file, then reply with its contents.'
order_task='Add an order feature to this project, in src/. An order has an id, a customer and a list of lines. A line has a product id, a quantity and a unit price in cents. A customer has an id, a name and a discount, which is either a percent or a fixed amount in cents. Add a function that returns the order total in cents after the customer discount, and a function that returns a text summary of the order, one row per line and the total at the end, each in its own file. Both functions use the same order, line, customer and discount types. Write the files, then reply with the path and the contents of every file you wrote.'
react_task='Add src/search-panel.tsx to this project: a React component with a text input and a Search button. On submit it fetches /api/search?q=<the text>, which returns a JSON array of { id, title, url }. While the request runs it shows "Loading…", on failure it shows the error message, and on success it shows the results as a list of links. Write the file, then reply with its contents.'
feature_task='Add a products feature to this project, in src/features/products/. Its page shows a filter panel and a grid of products. The filter panel keeps the values the user is typing in a hook that only the panel uses, and it waits 300 ms after the last keystroke before it applies them: keep that number in a constant. The page loads the products once from GET /api/products, which returns a JSON array of { id, name, price, category }, checks the response with a zod schema, and the grid shows the products that match the applied filters. Write the files, then reply with the path and the contents of every file you wrote.'
decline_task='Add src/decline-message.ts to this project. Export a function that takes a decline code from the payment provider and returns the message to show the customer. These are the 30 codes and their messages, to use as they are: authentication_required: "The bank asks you to confirm this payment.", approve_with_id: "The bank could not approve this payment.", call_issuer: "Call your bank about this payment.", card_not_supported: "This card does not support this purchase.", card_velocity_exceeded: "This card is over its limit.", currency_not_supported: "This card does not support this currency.", do_not_honor: "Your bank declined this payment.", duplicate_transaction: "This payment was already made.", expired_card: "This card has expired.", fraudulent: "This payment was declined.", generic_decline: "The card was declined.", incorrect_cvc: "The security code is wrong.", incorrect_number: "The card number is wrong.", incorrect_zip: "The postal code is wrong.", insufficient_funds: "The card has too little money on it.", invalid_account: "This card account is not valid.", invalid_amount: "The amount is not valid for this card.", invalid_expiry_month: "The expiry month is wrong.", invalid_expiry_year: "The expiry year is wrong.", issuer_not_available: "Your bank did not answer. Try again.", lost_card: "This card was reported lost.", merchant_blacklist: "This card cannot be used here.", new_account_information_available: "Your bank has new details for this card.", no_action_taken: "Your bank took no action on this payment.", not_permitted: "This payment is not permitted.", pickup_card: "This card cannot be used. Call your bank.", processing_error: "An error occurred. Try again.", reenter_transaction: "Enter the payment again.", stolen_card: "This card was reported stolen.", try_again_later: "Try again later.". For any other code it returns "The payment failed. Try another card.": keep that message in a constant. Write the files, then reply with the path and the contents of every file you wrote.'
comments_task='Add a comments section to this project, in src/. It is a React component that takes a post id. When it mounts, it loads the comments from GET /api/posts/<the post id>/comments, which returns a JSON array of { id, author, text }, and shows them as a list. Below the list, a form with a text area and a Send button posts a new comment: POST /api/posts/<the post id>/comments with { text } returns the new comment, which joins the end of the list, and the text area is cleared. While the comments load, the section shows "Loading…"; while a comment is being sent, the form is disabled; a failed request shows its error message. Write the files, then reply with the path and the contents of every file you wrote.'
# One Haiku session that hands the task to one Haiku subagent, as the main
# model does with routine work. The installed copy of the plugin is turned off,
# so the skill list and the rules come from this checkout. The files it writes
# stay next to its log. A third argument adds dependencies to its package.json,
# so the other tasks keep the setup of their recorded runs.
run() {
  local work=${2%.jsonl} deps='"react":"^19.2.0"'
  [ -z "${3:-}" ] || deps="$deps,$3"
  mkdir -p "$work/src"
  printf '{"type":"module","dependencies":{%s},"devDependencies":{"typescript":"^5.9.0","@types/react":"^19.2.0"}}\n' "$deps" >"$work/package.json"
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
# first write: a Write, an Edit, or a Bash call that writes a TypeScript file
# with `>` or `tee`. A run with no write at all counts as one that did not
# invoke it.
# ponytail: it finds `>`, `tee` or `tee -a`, then spaces or none, then a path
# with `.ts`, `.tsx`, `.mts` or `.cts` in it, at any place in the command text.
# So `=> x.ts` in a here-document and `> a.ts.bak` are writes too, and `cp`,
# `sed -i`, `tee --append` or `tee a.log b.ts` is not. The one recorded run that
# wrote through Bash used `cat > <file> <<'EOF'`, and no recorded Bash call had
# a `=>`.
count() {
  local skill=$1 loaded=0 log calls
  shift
  for log; do
    # The logs of an older eval have no log of a later task.
    [ -f "$log" ] || { echo "no log: $log" && continue; }
    calls=$(jq -rR 'fromjson? | select(.type == "assistant" and .parent_tool_use_id != null)
      | .message.content[] | select(.type == "tool_use")
      | if .name == "Skill" then .input.skill
        elif .name == "Bash" and (.input.command | test("(>|\\btee( -a)?) *[^ ;&|<>]*\\.[cm]?tsx?\\b")) then "Write"
        else .name end' "$log")
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

# first <dir>...: the runs whose every written file opens with an export
# after its imports, as typescript-conventions asks of the primary export. It
# prints the first line of each file that opens with something else. The
# recorded runs that broke the rule put a helper or an Intl constant there.
first() {
  local ok=0 dir list file line bad
  for dir; do
    list=$(find "$dir/src" -name '*.ts' 2>/dev/null || true)
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
  echo "export first: $ok of $# order and decline runs open every file with an export"
  [ "$ok" -eq "$#" ] || failed=1
}

# constants <dir>...: the decline runs with the 30-line message table in a
# constants.ts and the short fallback message outside it. It prints each file
# that breaks it. It finds both by their text, as the task gives it.
constants() {
  local table='Your bank has new details for this card.' fallback='The payment failed. Try another card.' ok=0 dir found
  for dir; do
    if ! grep -rqsF "$table" "$dir/src" || ! grep -rqsF "$fallback" "$dir/src"; then
      echo "no table or no fallback written: $dir/src" && continue
    fi
    found=$({
      grep -rlF "$table" "$dir/src" | grep -v '/constants\.ts$'
      grep -rlF "$fallback" "$dir/src" | grep '/constants\.ts$'
    } || true)
    if [ -n "$found" ]; then echo "$found"; else ok=$((ok + 1)); fi
  done
  echo "constants: $ok of $# decline runs keep the table in constants.ts and the fallback beside its use"
  [ "$ok" -eq "$#" ] || failed=1
}

# nested <dir>...: the feature runs that keep the filter panel's own hook out
# of the feature root and out of `shared`, as react-conventions asks. It prints
# each hook it finds there. The recorded runs without the rule wrote it as
# src/features/products/use-filter-draft.ts. A hook at the root that a
# `*-page.tsx` at the root imports is the page's own, and passes: a recorded
# run with the rule on one hook per job wrote use-products.ts so.
# ponytail: it checks only that shape, a `use-*` file found by its name. Each
# of these passes: a feature-level hooks/ folder, a hook in the grid's folder,
# a hook in src/hooks or another folder outside the feature, a camelCase name,
# a hook folder with an index.ts, a hook in a folder named shared inside the
# feature, a constant file at the feature root. A `use-*` file inside a `use-*`
# folder at the feature root counts as a hook at the root. Each of these
# fails, though the skill allows it: the page's own hook when the page file is
# not named `*-page.tsx` or imports it in another form than `./use-products`,
# as `./use-products.js`, a generic `use-*` hook in src/shared. No recorded run
# wrote any of these, so add a case when a run does.
nested() {
  local ok=0 dir feature found
  for dir; do
    feature=$dir/src/features/products
    [ -d "$feature" ] || { echo "no feature written: $dir" && continue; }
    found=$(find "$dir/src" -type f -name 'use-*' \( -path "$feature/use-*" -o -path "$dir/src/shared/*" \) |
      while IFS= read -r file; do
        hook=$(basename "${file%.*}")
        if [ "$file" = "$feature/$(basename "$file")" ] && grep -qsE "from ['\"]\./${hook}['\"]" "$feature"/*-page.tsx; then
          continue
        fi
        echo "$file"
      done)
    if [ -n "$found" ]; then echo "$found"; else ok=$((ok + 1)); fi
  done
  echo "own folder: $ok of $# feature runs keep the panel's hook out of the feature root and shared"
  [ "$ok" -eq "$#" ] || failed=1
}

# models <dir>...: the order runs that declare Order, the line, Customer and
# Discount each in a file of its own under a models/ folder, as
# typescript-conventions asks. It prints each file that breaks it. The recorded
# runs without the rule declared all four in src/order.ts.
# ponytail: it knows the names Order, OrderLine, Line, Customer and Discount,
# as `export type`, `export enum` or `export interface` at a line's start.
# Another name or form passes unseen. A run that names all four this way is
# the only shape recorded so far.
models() {
  local ok=0 dir decl bad
  for dir; do
    decl=$(grep -rHoE '^export (type|enum|interface) (Order|OrderLine|Line|Customer|Discount)[ =<]' "$dir/src" || true)
    [ -n "$decl" ] || { echo "no model written: $dir/src" && continue; }
    bad=$(awk -F: '$1 !~ /\/models\// || ++seen[$1] > 1 { print $1 }' <<<"$decl" | sort -u)
    if [ -n "$bad" ]; then echo "$bad"; else ok=$((ok + 1)); fi
  done
  echo "models: $ok of $# order runs keep each model in a file of its own in models/"
  [ "$ok" -eq "$#" ] || failed=1
}

# names <dir>...: the runs that name a module-level const with a literal value
# in CONSTANT_CASE, and any other const in camelCase. It prints each line that
# breaks it: the recorded runs without the rule named the decline table and
# message in camelCase, and an Intl.NumberFormat PRICE_FORMAT.
# ponytail: a literal starts with a quote, a backtick, a digit, a minus, `[`,
# `{`, `true` or `false`: an object of functions or calls is one too. A const
# inside a function passes unseen: no recorded run named one in CONSTANT_CASE.
names() {
  local ok=0 dir found
  for dir; do
    [ -n "$(find "$dir/src" \( -name '*.ts' -o -name '*.tsx' \))" ] || { echo "no TypeScript file written: $dir/src" && continue; }
    found=$(find "$dir/src" \( -name '*.ts' -o -name '*.tsx' \) -exec awk 'BEGIN { literal = "^([-\"`[{0-9" sprintf("%c", 39) "]|true|false)" }
      /^(export )?const [A-Za-z_$]/ {
        rest = $0; sub(/^(export )?const /, "", rest); name = rest; sub(/[^A-Za-z0-9_$].*/, "", name)
        if (sub(/^[^=]*=[[:space:]]*/, "", rest) && (rest ~ literal) != (name ~ /^[A-Z][A-Z0-9_]*$/)) print FILENAME ": " $0
      }' {} +)
    if [ -n "$found" ]; then echo "$found"; else ok=$((ok + 1)); fi
  done
  echo "names: $ok of $# runs name a literal const in CONSTANT_CASE and any other const in camelCase"
  [ "$ok" -eq "$#" ] || failed=1
}

# union <dir>...: the order runs whose file of `export type Discount` declares
# it above its variants. It prints the first type line of each file that opens
# with something else: the recorded runs without the rule exported both
# variants above the union.
union() {
  local ok=0 dir file line
  for dir; do
    file=$(grep -rlE '^export type Discount( |=)' "$dir/src" | head -n 1)
    [ -n "$file" ] || { echo "no Discount written: $dir/src" && continue; }
    line=$(grep -m 1 -E '^(export )?type ' "$file")
    case $line in "export type Discount "* | "export type Discount="*) ok=$((ok + 1)) ;; *) echo "$file: $line" ;; esac
  done
  echo "union first: $ok of $# order runs declare Discount above its variants"
  [ "$ok" -eq "$#" ] || failed=1
}

# schemas <dir>...: the feature runs that declare their zod object schemas
# only in the feature's schemas/ folder. It prints each other file that
# declares one. The recorded runs without the rule declared it beside the fetch
# or the type, in products-api.ts or product.ts. A schema wrapped at the parse
# call, as `z.array(productSchema).parse(data)`, is not a declaration.
# ponytail: it finds a schema by `z.object(`. `z.strictObject`, `z.looseObject`
# and an imported `object(` pass unseen; every recorded run used `z.object`.
schemas() {
  local ok=0 dir found
  for dir; do
    [ -d "$dir/src/features/products/schemas" ] || { echo "no schemas/ folder: $dir" && continue; }
    found=$(find "$dir/src" -type f ! -path "$dir/src/features/products/schemas/*" -exec grep -lE 'z\.object\(' {} + || true)
    if [ -n "$found" ]; then echo "$found"; else ok=$((ok + 1)); fi
  done
  echo "schemas: $ok of $# feature runs declare their zod schemas only in schemas/"
  [ "$ok" -eq "$#" ] || failed=1
}

# hooks <dir>...: the React runs whose every component and hook holds at most
# one async call, as react-conventions asks: two requests and their state go
# to a hook each. It prints the first line of each one that holds more. The
# recorded comments runs without the rule loaded the comments in an effect and
# sent a new one in a handler, both in the component body. The search panel
# and the products page have one request each, and keep it.
# ponytail: it finds a component or a hook by `export function` or `export
# default function`, then a capital letter or `use` and a capital letter, at a
# line's start. Its body ends at the first line that is `}`, with a `;` or a
# `//` comment or neither. The line `}: Props) {` or `} {` of a signature over
# several lines does not end it. It counts the lines in that body with `await`
# or `.then(`, except a line with `.json()` and no `fetch(`: `await fetch(…)`
# and then `await response.json()` is one request, and so are `fetch(…)`,
# `.then((r) => r.json())` and `.then(set)` on three lines. Each of these
# passes unseen: an arrow function, one that is not exported, two requests on
# one line, a request with no `await` or `.then(`, as `useQuery`, or a client
# that reads the body on the request line, as `ky.get(…).json()` or
# `api.get(…).then((r) => r.json())`. Each of these fails though it holds one
# request: a body read other than `.json()`, as `.text()`, a hook with two
# awaits that are not requests, and a `.then(` chain with two counted lines:
# in a braced body read, `.then((r) => {` counts and `return r.json();` on the
# next line does not, so `.then(set)` after them makes two, and so does
# `fetch(…).then((r) => r.json())` with `.then(set)` on the next line.
# Every recorded run wrote `export function`, `fetch` and `.json()`, one
# request per line. No recorded run put two requests in one hook, so no fixture
# fails through a hook: add one when a run does.
hooks() {
  local ok=0 dir found
  for dir; do
    [ -n "$(find "$dir/src" \( -name '*.ts' -o -name '*.tsx' \))" ] || { echo "no TypeScript file written: $dir/src" && continue; }
    found=$(find "$dir/src" \( -name '*.ts' -o -name '*.tsx' \) -exec awk '
      FNR == 1 { open = 0 }
      /^export (default )?function ([A-Z]|use[A-Z])/ { start = FILENAME ": " $0; calls = 0; open = 1; next }
      open && /(^|[^[:alnum:]_])await[[:space:]]|\.then\(/ && !(/\.json\(\)/ && !/(^|[^[:alnum:]_])fetch\(/) { calls++ }
      open && /^};?[[:space:]]*(\/\/.*)?$/ { if (calls > 1) print start; open = 0 }' {} +)
    if [ -n "$found" ]; then echo "$found"; else ok=$((ok + 1)); fi
  done
  echo "one job: $ok of $# React runs hold at most one async call in each component and hook"
  [ "$ok" -eq "$#" ] || failed=1
}

if [ "${1:-}" = --check ]; then
  [ "$#" -eq 2 ] || usage
  [ -d "$2" ] || usage
  logs=${2%/}
else
  # An argument too many, as `3 --check <folder>`, must not start paid runs.
  [ "$#" -le 1 ] || usage
  runs=${1:-5}
  [ "$runs" -ge 1 ] 2>/dev/null || usage
  logs=$(mktemp -d)
  for i in $(seq "$runs"); do
    run "$ts_task" "$logs/ts-$i.jsonl" &
    run "$react_task" "$logs/react-$i.jsonl" &
    run "$order_task" "$logs/order-$i.jsonl" &
    run "$decline_task" "$logs/decline-$i.jsonl" &
    run "$feature_task" "$logs/feature-$i.jsonl" '"zod":"^4.6.0"' &
    run "$comments_task" "$logs/comments-$i.jsonl" &
  done
  wait
fi

failed=0
count typescript-conventions "$logs"/ts-*.jsonl "$logs"/react-*.jsonl "$logs"/order-*.jsonl "$logs"/decline-*.jsonl "$logs"/feature-*.jsonl "$logs"/comments-*.jsonl
count react-conventions "$logs"/react-*.jsonl "$logs"/feature-*.jsonl "$logs"/comments-*.jsonl
# A run's folder ends in its number, as order-1. Its log, order-1.jsonl, does
# not.
files=()
for dir in "$logs"/ts-*[0-9]; do files+=("$dir/src/cart-total.ts"); done
for dir in "$logs"/react-*[0-9]; do files+=("$dir/src/search-panel.tsx"); done
braced "${files[@]}"
first "$logs"/order-*[0-9] "$logs"/decline-*[0-9]
models "$logs"/order-*[0-9]
union "$logs"/order-*[0-9]
constants "$logs"/decline-*[0-9]
names "$logs"/ts-*[0-9] "$logs"/react-*[0-9] "$logs"/order-*[0-9] "$logs"/decline-*[0-9] "$logs"/feature-*[0-9] "$logs"/comments-*[0-9]
nested "$logs"/feature-*[0-9]
schemas "$logs"/feature-*[0-9]
hooks "$logs"/react-*[0-9] "$logs"/feature-*[0-9] "$logs"/comments-*[0-9]
echo "logs: $logs"
exit "$failed"
