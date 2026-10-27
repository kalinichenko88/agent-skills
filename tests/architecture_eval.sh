#!/usr/bin/env bash
# Measures what kalinichenko:architecture changes, for #87. Its fixture,
# tests/fixtures/architecture/repo, is a shop: src/api/client.ts wraps every
# HTTP call, src/lib/money.ts formats a price, and docs/ARCHITECTURE.md names
# both and keeps a code file at 40 lines, with src/features/cart/index.ts on
# its debt list. Three tasks run in four arms:
#
#   none   no docs/ARCHITECTURE.md, no CLAUDE.md, no architecture skill
#   files  docs/ARCHITECTURE.md and a link to it in CLAUDE.md, no skill
#   skill  the same, and the skill, which loads by its description only
#   line   the same, and the CLAUDE.md line of this repository
#
# In each arm it counts:
# - call, a screen with a new request: the runs that import src/api/client
#   and call no fetch, axios or XMLHttpRequest outside it, and the runs that
#   write the block of *The start of a feature* before their first write;
# - store, recently viewed orders, which need a data store: the runs that
#   write one ADR in docs/adr/, with two options and a Confirmation section;
# - split, discount codes in the cart, a file past the limit: the runs whose
#   first commit moves code out of src/features/cart/index.ts into a new file,
#   with a commit after it;
# - in the arms skill and line, the runs of the three tasks that invoke the
#   skill before their first write.
# It also gives the skill's search for existing code to haiku and to sonnet,
# on the call task in the arm none, and counts the answers that name both
# src/api/client.ts and src/lib/money.ts.
#
# Each run is one opus session, as the main session that meets the moment of a
# decision, with this machine's other plugins and settings. The installed copy
# of the plugin is turned off; the arms none and files load a copy of this
# checkout without skills/architecture. Its runs call the model, so they cost
# tokens and are not part of `make check`: run it by hand after a change to the
# skill's description or to the CLAUDE.md line. A failing count is a result,
# not an error: it exits 0.
#
# With --check, it runs only the checks, on the logs folder of an earlier run.
# `make check` runs them so on tests/fixtures/architecture, through
# tests/architecture_checks_test.sh.
#
# Usage: tests/architecture_eval.sh [runs per arm and task, default 5]
#        tests/architecture_eval.sh --check <logs folder>

# shellcheck disable=SC2016 # the backticks are Markdown's
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
usage() { echo "usage: $0 [runs per arm and task, at least 1] | --check <logs folder>" >&2; exit 2; }

arms='none files skill line'
call_task='Add a reports screen to this project, in src/features/reports/: it lists the monthly reports from GET /api/reports, which returns a JSON array of { month, totalCents }, and shows each total as a price.'
store_task='Add recently viewed orders to this project: remember the last 10 orders the user opened, also after the browser restarts, and export a function that lists them, newest first.'
split_task='Add discount codes to the cart in src/features/cart/: a code takes a percent off the cart total, and the server checks it at POST /api/discounts/check with { code }, which returns { percent }.'
ask='Do not ask questions: decide yourself. Write the files and commit them with git, then reply with the path of every file you wrote.'
link='The architecture of this project: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).'
line='Before a spec, a plan or the first edit of a new feature, read [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). At the start of a new feature, and for a decision, load `kalinichenko:architecture`.'

# setup <dir> <arm>: the fixture as a git repository, its first commit tagged
# base.
setup() {
  mkdir -p "$1"
  cp -R "$root/tests/fixtures/architecture/repo/." "$1"
  case $2 in
    none) rm -r "$1/docs" ;;
    line) printf '# shop\n\n%s\n' "$line" >"$1/CLAUDE.md" ;;
    *) printf '# shop\n\n%s\n' "$link" >"$1/CLAUDE.md" ;;
  esac
  git -C "$1" init -q -b main
  git -C "$1" config user.name eval
  git -C "$1" config user.email eval@example.com
  git -C "$1" add .
  git -C "$1" commit -qm 'feat: list the orders and keep a cart'
  git -C "$1" tag base
}

# run <arm> <task> <log>: the tree stays next to the log, and its commits after
# base go to <log without .jsonl>.commits.
run() {
  local work=${3%.jsonl} plugin=$root
  case $1 in none | files) plugin=$logs/no-skill ;; esac
  setup "$work" "$1"
  (cd "$work" && claude -p --model opus --output-format stream-json --verbose \
    --settings '{"enabledPlugins":{"kalinichenko@kalinichenko":false}}' \
    --plugin-dir "$plugin" --dangerously-skip-permissions "$2 $ask") >"$3" 2>&1 || true
  git -C "$work" log --reverse --format='> %s' --numstat --summary base..HEAD >"$work.commits"
}

# search <model> <json>: the prompt goes on stdin, since --tools takes each
# argument after it as a tool.
search() {
  setup "${2%.json}" none
  (cd "${2%.json}" && claude -p --model "$1" --output-format json \
    --settings '{"enabledPlugins":{"kalinichenko@kalinichenko":false}}' \
    --tools Read Grep Glob --dangerously-skip-permissions) >"$2" 2>&1 <<EOF || true
Find the code in this project that already does each kind of work that the task below needs, and name each place with path:line. Change no file.
The task: $call_task
EOF
}

# events <log>: the tool calls of the session and its subagents in order, one
# a line, as the skill's name for a Skill call and Write for a write, and Block
# for a text of the main session that holds the block of *The start of a
# feature*.
# ponytail: a Bash call is a write when it has `>`, `tee` or `tee -a`, then
# spaces or none, then a path with a dot and letters, as `cat > a.ts <<'EOF'`.
# `cp`, `mv` and `sed -i` are not writes.
events() {
  jq -rR 'fromjson? | select(.type == "assistant") | .parent_tool_use_id as $parent
    | .message.content[]
    | if .type == "tool_use" then
        if .name == "Skill" then .input.skill
        elif (.name | test("^(Write|Edit|MultiEdit|NotebookEdit)$"))
          or (.name == "Bash" and (.input.command | test("(>|\\btee( -a)?) *[^ ;&|<>]*\\.[a-z]+\\b"))) then "Write"
        else .name end
      elif .type == "text" and $parent == null
        and (.text | contains("**Problem:**") and contains("**Touches:**")) then "Block"
      else empty end' "$1"
}

# before <label> <event> <log>...: the runs with <event> before their first
# write. A run with no write counts as one without it.
before() {
  local label=$1 event=$2 ok=0 log
  shift 2
  for log; do
    if events "$log" | awk '/^Write$/ { printf "%s", seen; exit } { seen = seen $0 "\n" }' | grep -qx "$event"; then
      ok=$((ok + 1))
    fi
  done
  echo "$label: $ok of $# runs before the first write"
}

# wrapper <label> <log>...: the call runs that import src/api/client in a file
# of src/features/reports/ and call no other client. It prints each file that
# calls one.
wrapper() {
  local label=$1 ok=0 log tree found
  shift
  for log; do
    tree=${log%.jsonl}
    found=$(grep -rlE 'fetch\(|axios|XMLHttpRequest' "$tree/src" 2>/dev/null | grep -v '/src/api/client\.ts$' || true)
    if [ -n "$found" ]; then
      echo "$found"
    elif grep -rqs 'api/client' "$tree/src/features/reports"; then
      ok=$((ok + 1))
    else
      echo "no import of api/client: $tree/src/features/reports"
    fi
  done
  echo "$label: $ok of $# runs use request() and no second client"
}

# adr <label> <log>...: the store runs with one ADR in docs/adr/, which has at
# least two list items under its Options heading and a line of text under its
# Confirmation heading.
adr() {
  local label=$1 ok=0 log files count
  shift
  for log; do
    files=$(find "${log%.jsonl}/docs/adr" -name '*.md' 2>/dev/null || true)
    count=$(grep -c . <<<"$files" || true)
    if [ "$count" -ne 1 ]; then
      echo "${log%.jsonl}: $count ADRs"
    elif awk '/^## / { options = /^## Options/; confirmation = /^## Confirmation/; next }
      options && /^[-*] / { n++ } confirmation && NF { c++ }
      END { exit !(n >= 2 && c >= 1) }' "$files"; then
      ok=$((ok + 1))
    else
      echo "$files: no two options or no Confirmation"
    fi
  done
  echo "$label: $ok of $# runs write one ADR with two options and a Confirmation"
}

# split <label> <log>...: the split runs whose first commit takes lines out of
# src/features/cart/index.ts and creates a file, and which have a later commit.
# ponytail: it does not check that the first commit only moves code, nor where
# the feature lands. Read the commits of a run that passes.
split() {
  local label=$1 ok=0 log
  shift
  for log; do
    if awk '/^> / { n++; next }
      n == 1 && $3 == "src/features/cart/index.ts" && $2 > 0 { cut = 1 }
      n == 1 && /^ create mode / { created = 1 }
      END { exit !(cut && created && n >= 2) }' "${log%.jsonl}.commits" 2>/dev/null; then
      ok=$((ok + 1))
    fi
  done
  echo "$label: $ok of $# runs split the file in a commit before the feature"
}

# found <model> <json>...: the search answers that name both files.
found() {
  local model=$1 ok=0 json answer
  shift
  for json; do
    answer=$(jq -r '.result // empty' "$json" 2>/dev/null || true)
    case $answer in *src/api/client.ts*) case $answer in *src/lib/money.ts*) ok=$((ok + 1)) ;; esac ;; esac
  done
  echo "search $model: $ok of $# answers name src/api/client.ts and src/lib/money.ts"
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
  mkdir "$logs/no-skill"
  cp -R "$root/.claude-plugin" "$root/hooks" "$root/skills" "$root/rules.md" "$logs/no-skill/"
  rm -r "$logs/no-skill/skills/architecture"
  for i in $(seq "$runs"); do
    for arm in $arms; do
      run "$arm" "$call_task" "$logs/call-$arm-$i.jsonl" &
      run "$arm" "$store_task" "$logs/store-$arm-$i.jsonl" &
      run "$arm" "$split_task" "$logs/split-$arm-$i.jsonl" &
    done
    search haiku "$logs/search-haiku-$i.json" &
    search sonnet "$logs/search-sonnet-$i.json" &
  done
  wait
  # A session that ends in an error, as at a rate limit, writes nothing and
  # counts as a run without each thing counted: name it.
  for log in "$logs"/*.jsonl "$logs"/*.json; do
    jq -eR 'fromjson? | select(.type == "result" and .is_error == false)' "$log" >/dev/null ||
      echo "no successful end: $log"
  done
fi

for arm in $arms; do
  wrapper "call $arm" "$logs"/call-"$arm"-*.jsonl
  before "block in call $arm" Block "$logs"/call-"$arm"-*.jsonl
  adr "store $arm" "$logs"/store-"$arm"-*.jsonl
  split "split $arm" "$logs"/split-"$arm"-*.jsonl
  case $arm in
    skill | line) before "skill in $arm" kalinichenko:architecture "$logs"/*-"$arm"-*.jsonl ;;
  esac
done
found haiku "$logs"/search-haiku-*.json
found sonnet "$logs"/search-sonnet-*.json
echo "logs: $logs"
