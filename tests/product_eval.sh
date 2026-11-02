#!/usr/bin/env bash
# Measures what kalinichenko:product changes, for #200. Its fixture,
# tests/fixtures/product, is a site that lists 1000 brands, each with a logo
# through /logo, which redirects to an icon service. The page's CSP allows only
# that service. 69 brands have only the service's placeholder, and 7 more have
# an icon of their own. The branch feature redirects a placeholder brand to the
# icon of its own site, with a HEAD call to the service on each request: the
# CSP blocks every icon that it finds.
#
# The shapes. A narrated run asks the session what an agent would do, with the
# tools Read, Grep, Glob, Skill and Bash; a real run does the task.
#
#   worth    narrated  the review of the branch: the skill loads, and its
#                      verdict is not "do it"
#   stop     narrated  round 1 proved that the fallback shows no icon: a
#                      verdict line, the light re-check. Its texts are printed,
#                      for the count of the runs that rebuild the feature
#   fork     narrated  a fork in brainstorming: the skill loads, and its
#                      options reach the question
#   foreign  narrated  the review of a teammate's branch whose spec holds a
#                      report: the skill loads, and the answer names Fable,
#                      the full depth. Codex is no sign of it: review-loop
#                      sends Codex at xhigh
#   start    real      the feature, before any code: the skill, a Fable
#                      subagent and a codex exec call before the first write,
#                      and a verdict line that is not "do it"
#   bug      real      a bug fix with no business logic: no Fable or Codex
#                      before the first write
#   traced   narrated  the review of the person's own branch whose spec holds
#                      a report: no new verdict other than "do it", and no
#                      Fable named
#   plain    narrated  a brainstorming question that asks the person to
#                      describe: no verdict line, and no Fable named
#   store    narrated  a decision in a project with docs/decisions.md: the
#                      answer names that file and writes D4, its next entry.
#                      With no skill it passes: it guards against a second
#                      store
#
# bug, traced, plain and store guard against a skill that runs too often. A
# run of the skill is its report or its panel; a load that reads its table
# and stops is no run. A verdict line is a line that starts with the label,
# after `>`, `-` or spaces: a sentence that quotes the label is none.
#
# worth and stop are the prompts of the baseline in the spec,
# docs/superpowers/specs/2026-11-02-product-skill-design.md, word for word.
# Each run is one opus session, in English, with this machine's other plugins
# and settings, and the plugin of PLUGIN_DIR, by default this checkout; the
# installed copy of the plugin is turned off. A run that does not end, or ends
# in an error, fails. Its runs call the model, so they cost tokens and are not
# part of `make check`: run it by hand after a change to skills/product, to the
# start of a feature in skills/architecture or to the worth step of
# skills/review-loop. A failing count is a result, not an error: it exits 0.
#
# With --check, it runs only the checks, on the logs folder of an earlier run.
# `make check` runs them so on tests/fixtures/product/logs, through
# tests/product_checks_test.sh.
#
# Usage: tests/product_eval.sh [runs per shape, default 5] [shape ...]
#        tests/product_eval.sh --check <logs folder>

# shellcheck disable=SC2016 # the backticks are Markdown's
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
fixture=$root/tests/fixtures/product
plugin=${PLUGIN_DIR:-$root}
shapes='worth stop fork foreign start bug traced plain store'
usage() { echo "usage: $0 [runs per shape, at least 1] [shape ...] | --check <logs folder>" >&2; exit 2; }

feat="feat: show the brand's own icon when the icon service has only its placeholder"
ask='An agent works in this repository, on the branch feature. The person asked it: "Review the branch before the pull request, and fix what the review finds." The agent has the kalinichenko plugin.'
worth="$ask"' Load the skills that the agent would load at this moment, and read the branch. Then say what the agent does, step by step, up to and including the start of its first /code-review round, and give every message that it sends to the person before that round. Do not run a review, and change no file.'
stop="$ask"' It follows kalinichenko:review-loop. Round 1, /code-review high on the whole branch, returned one finding, and the agent verified it in the code: public/index.html sets the CSP img-src to '"'self'"' and https://icons.example.com, and the new fallback in src/server.js redirects the browser to the brand'"'"'s own site, so the browser blocks every icon that the fallback finds. The fallback never shows an icon to a user. Load the skills that the agent follows at this moment. Then say what the agent does next with this finding, and give every message that it sends to the person before its next review round. Do not run a review, and change no file.'
foreign=${worth/on the branch feature./on the branch feature, which a teammate wrote.}
fork='An agent runs superpowers:brainstorming with the person in this repository, on the branch main. The person wants each brand that has only the icon service'"'"'s placeholder to show its own icon. The agent'"'"'s next question chooses between two ways: fetch the brand'"'"'s own icon on each /logo request, or download those icons once into public/. The agent has the kalinichenko plugin. Load the skills that the agent would load at this moment, and read the repository. Then give the message that the agent sends to the person. Change no file.'
start='Add a fallback to /logo in this project: when the icon service has only its placeholder for a brand, redirect to the icon that the brand'"'"'s own site declares in its <link rel="icon">. Do not ask questions: decide yourself. Write the files and commit them with git, then reply with the path of every file you wrote.'
bug='/logo in src/server.js answers 302 to https://icons.example.com/null.png when the request has no domain parameter. Make it answer 400 instead. Do not ask questions: decide yourself. Write the files and commit them with git, then reply with the path of every file you wrote.'
plain='An agent runs superpowers:brainstorming with the person in this repository, on the branch main. The person said: "I want the brands with no icon to look better." The agent has the kalinichenko plugin. Its first question asks the person to describe the moment they see such a brand. Load the skills that the agent would load before that question. Then give the message that the agent sends. Change no file.'
store='An agent works in this repository, on the branch main, with the kalinichenko plugin. At a fork, the person chose to download the 7 brands'"'"' own icons once into public/, instead of a fallback on each request. Load the skills that the agent would load at this moment, and read the repository. Then say where and in which form the agent records this decision, and give the text it writes. Change no file.'

# prompt <shape>
prompt() {
  case $1 in
    worth | traced) printf '%s' "$worth" ;;
    stop) printf '%s' "$stop" ;;
    foreign) printf '%s' "$foreign" ;;
    fork) printf '%s' "$fork" ;;
    start) printf '%s' "$start" ;;
    bug) printf '%s' "$bug" ;;
    plain) printf '%s' "$plain" ;;
    store) printf '%s' "$store" ;;
  esac
}

# setup <dir> <shape>: the fixture as a git repository. main is its first
# commit; worth, stop, foreign and traced are on the branch feature, a second
# commit, by a teammate for foreign.
setup() {
  mkdir -p "$1"
  cp -R "$fixture/main/." "$1"
  if [ "$2" = store ]; then
    mkdir -p "$1/docs"
    cp "$fixture/decisions.md" "$1/docs/decisions.md"
  fi
  git -C "$1" init -q -b main
  git -C "$1" config user.name eval
  git -C "$1" config user.email eval@example.com
  git -C "$1" add .
  git -C "$1" commit -qm "chore: start"
  case $2 in worth | stop | foreign | traced) ;; *) return 0 ;; esac
  git -C "$1" checkout -qb feature
  cp -R "$fixture/feature/." "$1"
  case $2 in
    foreign | traced)
      mkdir -p "$1/docs/specs"
      cp "$fixture/spec.md" "$1/docs/specs/own-icon.md"
      ;;
  esac
  git -C "$1" add .
  if [ "$2" = foreign ]; then
    git -C "$1" commit -qm "$feat" --author 'Teammate <other@example.com>'
  else
    git -C "$1" commit -qm "$feat"
  fi
}

# run <shape> <n>: the prompt goes on stdin, since --tools takes each argument
# after it as a tool.
run() {
  local work=$logs/$1-$2 tools=
  setup "$work" "$1"
  case $1 in start | bug) ;; *) tools='Read Grep Glob Skill Bash' ;; esac
  # shellcheck disable=SC2086 # $tools is a list of words, or none
  (cd "$work" && claude -p --model opus --output-format stream-json --verbose \
    --settings '{"enabledPlugins":{"kalinichenko@kalinichenko":false},"language":"English"}' \
    --plugin-dir "$plugin" ${tools:+--tools $tools} --dangerously-skip-permissions) \
    >"$work.jsonl" 2>&1 <<<"$(prompt "$1")" || true
}

# events <log>: the tool calls of the session and its subagents in order, one
# a line: the skill's name for a Skill call, Fable for a Fable subagent, Codex
# for a codex exec call, Write for a write, and the tool's name for the rest.
# ponytail: a Bash call is a write when its first line has `>`, `tee` or
# `tee -a`, then spaces or none, then a path with a dot and letters, as
# `cat > a.js <<'EOF'`. The lines after the first are a heredoc's text, as a
# brief that quotes `> src/a.js`. `cp`, `mv` and `sed -i` are not writes.
events() {
  jq -rR 'fromjson? | select(.type == "assistant") | .message.content[]
    | select(.type == "tool_use")
    | if .name == "Skill" then .input.skill
      elif (.name == "Agent" or .name == "Task") and ((.input.model // "") | test("fable")) then "Fable"
      elif .name == "Bash" and (.input.command | test("\\bcodex\\b.*\\bexec\\b")) then "Codex"
      elif (.name | test("^(Write|Edit|MultiEdit|NotebookEdit)$"))
        or (.name == "Bash" and (.input.command | split("\n")[0] | test("(>|\\btee( -a)?) *[^ ;&|<>]*\\.[a-z]+\\b"))) then "Write"
      else .name end' "$1"
}

# before <event> <log>: the event comes before the first write. A run with no
# write counts all its events.
before() {
  events "$2" | awk '/^Write$/ { exit } { print }' | grep -qx "$1"
}

# loads <skill> <log>: the session or a subagent invokes the skill.
loads() {
  events "$2" | grep -qx "$1"
}

# result <log>: the last text of the session.
result() {
  jq -rR 'fromjson? | select(.type == "result") | .result // empty' "$1"
}

# ended <log>: the session ended with no error.
ended() {
  jq -eR 'fromjson? | select(.type == "result" and .is_error == false)' "$1" >/dev/null
}

# verdicts <text>: the verdict lines of the text.
verdicts() {
  grep -iE '^[>* -]*\*\*Verdict:\*\*' <<<"$1" || true
}

# verdict <text>: a verdict line that is not "do it" alone.
verdict() {
  verdicts "$1" | grep -qviE '\*\*Verdict:\*\* *do it\.? *$'
}

# check <shape> <log>: the run passes.
check() {
  local text
  text=$(result "$2")
  case $1 in
    worth) loads kalinichenko:product "$2" && verdict "$text" ;;
    stop) verdicts "$text" | grep -q . ;;
    fork) loads kalinichenko:product "$2" && grep -qi '\*\*Options:\*\*' <<<"$text" ;;
    foreign) loads kalinichenko:product "$2" && grep -qi fable <<<"$text" ;;
    start)
      before kalinichenko:product "$2" && before Fable "$2" && before Codex "$2" && verdict "$text"
      ;;
    bug) ! before Fable "$2" && ! before Codex "$2" ;;
    traced) ! verdict "$text" && ! grep -qi fable <<<"$text" ;;
    plain) ! verdicts "$text" | grep -q . && ! grep -qi fable <<<"$text" ;;
    store) grep -q 'docs/decisions\.md' <<<"$text" && grep -qE '\bD4\b' <<<"$text" ;;
  esac
}

# report <shape>: the count of the runs that pass, each failing run, and for
# stop each run's last text. A shape with no log prints nothing.
report() {
  local ok=0 n=0 fails='' log name
  for log in "$logs/$1"-*.jsonl; do
    [ -e "$log" ] || continue
    n=$((n + 1))
    name=$(basename "$log" .jsonl)
    if ended "$log" && check "$1" "$log"; then
      ok=$((ok + 1))
    else
      fails="$fails  fail $name
"
    fi
  done
  [ "$n" -gt 0 ] || return 0
  echo "$1: $ok of $n runs pass"
  printf '%s' "$fails"
  [ "$1" = stop ] || return 0
  for log in "$logs/$1"-*.jsonl; do
    echo "--- $(basename "$log" .jsonl)"
    result "$log"
  done
}

if [ "${1:-}" = --check ]; then
  [ "$#" -eq 2 ] && [ -d "$2" ] || usage
  logs=${2%/}
else
  runs=${1:-5}
  [ "$runs" -ge 1 ] 2>/dev/null || usage
  [ "$#" -eq 0 ] || shift
  # An argument that is not a shape, as in `3 --check <folder>`, must not
  # start paid runs.
  for s; do
    case " $shapes " in *" $s "*) ;; *) usage ;; esac
  done
  # shellcheck disable=SC2086 # the list of shapes splits into words
  [ "$#" -gt 0 ] || set -- $shapes
  command -v claude >/dev/null || { echo "$0: no claude command" >&2; exit 2; }
  logs=$(mktemp -d)
  for i in $(seq "$runs"); do
    for s; do run "$s" "$i" & done
    wait
  done
  echo "logs: $logs"
fi

for s in $shapes; do report "$s"; done
