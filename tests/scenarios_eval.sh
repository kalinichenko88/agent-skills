#!/usr/bin/env bash
# Probes a conformance run of craft against scenarios/github/take-in.md, for
# #231. Each case builds a tracker as JSON and a workspace with a bare origin,
# puts a fake gh first on PATH that reads and writes that JSON, and runs one
# opus session of `claude -p` on the person's message. Then it checks the Then
# and Never items of the case's scenario against the end state of the JSON,
# the branches of the origin, and the session's messages and tool calls:
#
#   free   A free task
#   other  A task that another person is assigned to
#   down   The tracker does not answer
#
# The session loads this checkout as the plugin, with --setting-sources
# project, so no other plugin and no setting of this machine reaches it. Each
# run costs tokens, so the eval is not part of `make check`, and
# --max-budget-usd caps each run. A failing check is a result, not an error:
# it exits 0. The run folder keeps each case's log, events, tracker and
# branches.
#
# With --check, it runs only the checks, on the folder of an earlier run.
# `make check` runs them so on tests/fixtures/scenarios, through
# tests/scenarios_checks_test.sh.
#
# Usage: tests/scenarios_eval.sh [case ...]
#        tests/scenarios_eval.sh --check <runs folder>

# shellcheck disable=SC2016 # Markdown's backticks, and jq and checks run later
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
usage() { echo "usage: $0 [free|other|down ...] | --check <runs folder>" >&2; exit 2; }

title='README: the install command says npm instal'
body='The README tells the reader to run `npm instal shop`. npm has no instal command, so the command fails. Done when the README says `npm install shop`.'
me=kim other=rivera

# setup <dir> <case>: the workspace <dir>, its origin <dir>.origin, the
# tracker <dir>.state.json, and the fake gh in <dir>.bin.
setup() {
  local w=$1
  git init -q --bare -b main "$w.origin"
  git init -q -b main "$w"
  git -C "$w" config user.name "$me"
  git -C "$w" config user.email "$me@example.com"
  printf '# shop\n\nInstall it with `npm instal shop`.\n' >"$w/README.md"
  git -C "$w" add README.md
  git -C "$w" commit -qm 'docs: add the README'
  git -C "$w" remote add origin "$w.origin"
  git -C "$w" push -q -u origin main
  jq -n --arg case "$2" --arg me "$me" --arg other "$other" --arg origin "$w.origin" \
    --arg title "$title" --arg body "$body" '{me: $me, repo: "acme/shop", origin: $origin,
      down: ($case == "down"), prs: [],
      issues: [{number: 91, title: $title, body: $body, state: "OPEN", stateReason: null,
        assignees: (if $case == "other" then [$other] else [] end),
        labels: [], comments: [], linked: [], duplicateOf: null}]}' >"$w.state.json"
  mkdir "$w.bin"
  printf '#!/usr/bin/env bash\nstate=%q\n' "$w.state.json" >"$w.bin/gh"
  cat >>"$w.bin/gh" <<'EOF'
# A fake gh over one JSON tracker: it answers the reads that the take-in
# makes, applies its writes to the JSON, and logs each call.
printf '%s\n' "$*" >>"${state%.state.json}.calls"
args=("$@") jqf='' fields='' search='' list_state=open num='' n=''
for ((i = 0; i < $#; i++)); do
  a=${args[i]}
  case $a in
    --jq | -q) jqf=${args[i + 1]} ;;
    --json) fields=${args[i + 1]} ;;
    --search | -S) search=${args[i + 1]} ;;
    --state | -s) list_state=${args[i + 1]} ;;
    n=*) n=${a#n=} ;;
  esac
done
for a in "${args[@]:2}"; do
  case $a in
    */issues/*) num=${a##*/issues/} num=${num%%[!0-9]*} && break ;;
    \#[0-9]* | [0-9]*) num=${a#\#} && break ;;
  esac
done
case $* in --version | *' --help' | *' -h') echo 'gh version 2.98.0'; exit 0 ;; esac
if [ "$(jq -r .down "$state")" = true ]; then
  echo 'HTTP 502: Bad Gateway (https://api.github.com/graphql)' >&2
  exit 1
fi
me=$(jq -r .me "$state") repo=$(jq -r .repo "$state") origin=$(jq -r .origin "$state")
out() { if [ -n "$jqf" ]; then jq -r "$jqf" <<<"$1"; else printf '%s\n' "$1"; fi; }
pick() { jq -c --arg f "$fields" "$1"' | . as $i | if $f == "" then . else reduce ($f | split(","))[] as $k ({}; .[$k] = $i[$k]) end'; }
save() { local t; t=$(jq "$@" "$state") && printf '%s\n' "$t" >"$state"; }
issues() {
  jq --arg repo "$repo" '[.issues[] | {number, title, body, state, stateReason,
    url: "https://github.com/\($repo)/issues/\(.number)", assignees: [.assignees[] | {login: .}],
    labels: [.labels[] | {name: .}], comments: [.comments[] | {author: {login: .author}, body}]}]' "$state"
}
value() { # value <flag>: the argument after <flag>
  for ((i = 0; i < ${#args[@]}; i++)); do [ "${args[i]}" != "$1" ] || { echo "${args[i + 1]}"; return; }; done
}
case "$1 $2" in
  'api repos/{owner}/{repo}') out "$(jq -c '{full_name: .repo, default_branch: "main", visibility: "public"}' "$state")" ;;
  'api user') out "$(jq -c '{login: .me}' "$state")" ;;
  'api graphql')
    if [[ $* == *'issue(number:'* ]]; then
      linked=$(jq -r --argjson n "$n" '.issues[] | select(.number == $n) | .linked[]' "$state" |
        while read -r b; do
          oid=$(git -C "$origin" rev-parse "refs/heads/$b")
          jq -nc --arg b "$b" --arg oid "$oid" --arg repo "$repo" '{ref: {name: $b, repository: {nameWithOwner: $repo},
            target: {oid: $oid, committedDate: "2026-11-03T00:00:00Z"}, compare: {behindBy: 0}}}'
        done | jq -sc .)
      out "$(jq -c --argjson n "$n" --argjson linked "$linked" '. as $s | ($s.issues[] | select(.number == $n)) as $i
        | {data: {viewer: {login: $s.me}, repository: {nameWithOwner: $s.repo, defaultBranchRef: {name: "main"},
          issue: {state: $i.state, assignees: {nodes: [$i.assignees[] | {login: .}]}, linkedBranches: {nodes: $linked},
            closedByPullRequestsReferences: {nodes: []}}}}}' "$state")"
    else # the entries of collect.sh: none
      out "$(jq -c '{data: {viewer: {login: .me}, repository: {}}}' "$state")"
    fi
    ;;
  'issue view')
    if [ -n "$fields" ]; then
      out "$(issues | jq -c --argjson n "$num" '.[] | select(.number == $n)' | pick .)"
    else
      issues | jq -r --argjson n "$num" '.[] | select(.number == $n)
        | "title:\t\(.title)\nstate:\t\(.state)\nassignees:\t\([.assignees[].login] | join(", "))\n--\n\(.body)"'
    fi
    ;;
  'issue list')
    out "$(issues | jq -c --arg s "$list_state" --arg q "$search" '[.[] | select($s == "all" or (.state | ascii_downcase) == $s)
      | select($q == "" or ((.title + " " + .body) | ascii_downcase | contains($q | ascii_downcase)))]' | pick '.[]' | jq -sc .)"
    ;;
  'issue edit')
    who=$(value --add-assignee)
    [ "$who" != @me ] || who=$me
    [ -z "$who" ] || save --argjson n "$num" --arg who "$who" '(.issues[] | select(.number == $n) | .assignees) |= (. + [$who] | unique)'
    ;;
  'issue develop')
    if [[ $* == *--list* ]]; then
      jq -r --argjson n "$num" --arg repo "$repo" '.issues[] | select(.number == $n) | .linked[] | "\(.)\thttps://github.com/\($repo)/tree/\(.)"' "$state"
    else
      b=$(value --name)
      git -C "$origin" branch "$b" main
      save --argjson n "$num" --arg b "$b" '(.issues[] | select(.number == $n) | .linked) += [$b]'
      echo "github.com/$repo/tree/$b"
      [[ $* != *--checkout* ]] || { git fetch -q origin "$b" && git checkout -q -b "$b" "origin/$b"; }
    fi
    ;;
  'pr list') out "$(jq -c .prs "$state")" ;;
  'repo view') out "$(jq -c '{nameWithOwner: .repo, visibility: "PUBLIC", defaultBranchRef: {name: "main"}}' "$state")" ;;
  'label list') out '[{"name":"bug"},{"name":"debt"},{"name":"enhancement"}]' ;;
  'auth status') echo "github.com: Logged in to github.com account $me" ;;
  *) echo "fake gh: no answer for: $*" >&2; exit 1 ;;
esac
EOF
  chmod +x "$w.bin/gh"
}

# record <dir>: <dir>.events holds the messages to the person, as text lines,
# the session's thinking that has words, as think lines, and each tool call of
# the session and its subagents, as its tool's name, or sub and the name, and
# its command, path or skill. A message that comes before a tool call can
# reach the log only as a think line, in other words, without the task's id
# and title (#206), with --include-partial-messages too. Paths of this machine
# become <craft>, <work> and <tmp>. <dir>.branches holds the origin's
# branches.
record() {
  jq -r 'select(.type == "assistant") | (if .parent_tool_use_id then "sub" else "" end) as $sub
    | .message.content[]
    | if .type == "text" and $sub == "" then "text\t" + (.text | gsub("\n"; " "))
      elif .type == "thinking" and $sub == "" and (.thinking // "" | test("[a-z]")) then "think\t" + (.thinking | gsub("\n"; " "))
      elif .type == "tool_use" then $sub + .name + "\t"
        + ((.input.command // .input.file_path // .input.skill // .input.description // "") | tostring | gsub("\n"; " "))
      else empty end' "$1.jsonl" |
    awk -v r="$root" -v w="$1" -v t="${TMPDIR:-/tmp}" '{ gsub(r, "<craft>"); gsub("(/private)?" w, "<work>")
      gsub("(/private)?" t, "<tmp>/"); gsub("<tmp>//", "<tmp>/"); print }' >"$1.events"
  git -C "$1.origin" for-each-ref --format='%(refname:short)' refs/heads >"$1.branches"
}

# check <dir> <case>: one line for each item, PASS, FAIL or SKIP, with the scenario.
# A message before the first change that the log can hold only as a think line
# gives SKIP: the log cannot show whether it told the gist.
# shellcheck disable=SC2034 # the items read the values through eval
check() {
  local d=$1 s writes first_write gist think assignees linked branch
  # A write: an edit of a file, a commit, a new branch, or a write to the
  # tracker. A read of a script, as `sed -n 1p worktree.sh`, is none.
  writes=$'^(sub)?(Edit|Write|NotebookEdit)\t|^(sub)?Bash\t.*(bash [^ ]*(worktree|add-finding)\\.sh|gh issue (edit|close|comment|develop +[#0-9])|git (commit|push|checkout -b|switch -c|worktree add))'
  first_write=$(grep -nE "$writes" "$d.events" | head -n 1 | cut -d: -f1)
  gist=$(grep -n "^text" "$d.events" | grep -F "$title" | head -n 1 | cut -d: -f1)
  think=$(grep -n "^think" "$d.events" | head -n 1 | cut -d: -f1)
  assignees=$(jq -c '.issues[] | select(.number == 91) | .assignees' "$d.state.json")
  linked=$(jq -c '.issues[] | select(.number == 91) | .linked' "$d.state.json")
  branch=$(jq -r '.[0] // empty' <<<"$linked")
  item() { if eval "$2"; then echo "PASS $s: $1"; else echo "FAIL $s: $1"; fi; }
  told() { grep "^text" "$d.events" | grep -qiF "$1"; }
  case $2 in
    free) s='A free task'
      before() { [ -n "$1" ] && { [ -z "$first_write" ] || [ "$1" -lt "$first_write" ]; }; }
      if ! before "$gist" && before "$think"; then
        echo "SKIP $s: the gist of #91 comes before any change: only a think line comes before it"
      else
        item 'the gist of #91 comes before any change' 'before "$gist"'
      fi
      item '#91 is assigned to the person' '[ "$assignees" = "[\"$me\"]" ]'
      item 'a branch <type>/91-<two to four words> exists' 'grep -qE "^(feat|fix|refactor|docs|test|ci|chore)/91-[a-z0-9]+(-[a-z0-9]+){1,3}\$" "$d.branches"'
      item 'that branch is linked to #91' '[ -n "$branch" ] && grep -qxF "$branch" "$d.branches"'
      item 'never: #91 gets a second linked branch' '[ "$(jq length <<<"$linked")" -le 1 ]'
      ;;
    other) s='A task that another person is assigned to'
      item 'the gist of #91 comes first' '[ -n "$gist" ]'
      item 'the person is told that #91 is assigned to another person' 'told "$other"'
      item 'the run waits: no change' '[ -z "$first_write" ]'
      item 'never: the assignees of #91 change' '[ "$assignees" = "[\"$other\"]" ]'
      item 'never: a branch for #91 is created' '[ "$(cat "$d.branches")" = main ] && [ "$linked" = "[]" ]'
      ;;
    down) s='The tracker does not answer'
      item 'the person is told the error of the tracker' 'told 502'
      item 'the run stops: no change' '[ -z "$first_write" ]'
      item 'never: a gist of #91 that the run did not read' '[ -z "$gist" ]'
      item 'never: the assignees of #91 change' '[ "$assignees" = "[]" ]'
      item 'never: a branch for #91 is created' '[ "$(cat "$d.branches")" = main ] && [ "$linked" = "[]" ]'
      ;;
    *) echo "$0: no case $2" >&2; return 2 ;;
  esac
}

if [ "${1:-}" = --check ]; then
  [ $# -eq 2 ] && [ -d "$2" ] || usage
  for f in "$2"/*.events; do check "${f%.events}" "$(basename "$f" .events)"; done
  exit 0
fi
cases=${*:-free other down}
for c in $cases; do case $c in free | other | down) ;; *) usage ;; esac; done
command -v claude >/dev/null || { echo "$0: no claude command" >&2; exit 2; }
command -v jq >/dev/null || { echo "$0: no jq command" >&2; exit 2; }

# run <case>: the free task goes on into the work after the take-in, so its
# cap is higher.
run() {
  local w=$runs/$1 budget=2
  [ "$1" != free ] || budget=4
  setup "$w" "$1"
  (cd "$w" && PATH="$w.bin:$PATH" claude -p --model opus --setting-sources project \
    --settings '{"language":"English"}' --plugin-dir "$root" --output-format stream-json --verbose \
    --max-budget-usd "$budget" --dangerously-skip-permissions '#91') >"$w.jsonl" 2>&1 || true
  record "$w"
}

runs=$(mktemp -d)
for c in $cases; do run "$c" & done
wait
for c in $cases; do
  printf '%s: $%s\n' "$c" "$(jq -r 'select(.type == "result") | .total_cost_usd' "$runs/$c.jsonl")"
  check "$runs/$c" "$c"
done
echo "runs: $runs"
