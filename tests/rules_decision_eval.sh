#!/usr/bin/env bash
# Probes #253: a decision that the person makes in a conversation, with no
# pull request, and that makes an open issue false. Does it reach the issue
# in the same session? Each run builds a workspace with a letter from a
# client, a tracker as JSON with three open issues, and a fake gh first on
# PATH that reads and writes that JSON. #12 states default A for a partner's
# new rate; the letter asks for default B. One opus session of `claude -p`
# takes two turns: the person asks to check the letter against the open
# issues, then decides default B and asks for the paragraph of the reply.
# The checks read the end state of the JSON and the session's messages and
# tool calls.
#
#   decide  the person decides default B: the decision reaches #12
#   think   the person is not sure yet: #12 stays as it is
#   busy    the person decides default B, and another person works on #12:
#           a comment on #12 carries the decision, and its body stays
#
# The session loads this checkout as the plugin, with --setting-sources
# project, so no other plugin and no setting of this machine reaches it. Each
# run costs tokens, so the eval is not part of `make check`, and
# --max-budget-usd caps each turn. A failing check is a result, not an error:
# it exits 0. The run folder keeps each run's log, events and tracker.
#
# With --check, it runs only the checks, on the folder of an earlier run.
#
# Usage: tests/rules_decision_eval.sh [runs] [decide|think|busy]
#        tests/rules_decision_eval.sh --check <runs folder>

# shellcheck disable=SC2016 # Markdown's backticks, and jq and checks run later
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
usage() { echo "usage: $0 [runs] [decide|think|busy] | --check <runs folder>" >&2; exit 2; }
me=kim
default_a='**All customers** (selected by default)'
# shellcheck disable=SC2034 # the checks read it through eval
default_b='new customers only[^.]*default|default[^.]*new customers only' # in one sentence
ask1='Read the client'"'"'s letter of 30 Oct in docs/letters/2026-10-30-client.md and check it against our open issues. Where do they differ?'
decide='We decided: a new partner rate applies only to new customers by default, and "All customers" stays a choice in the dialog. Write me the paragraph of our reply to the client about the rate change.'
think='Maybe a new partner rate should apply only to new customers by default. I am not sure yet: I will talk it over with the team tomorrow. Write me a draft of the paragraph of our reply about the rate change, so that I can show it to them.'

# setup <dir>: the workspace <dir>, the tracker <dir>.state.json, and the
# fake gh in <dir>.bin.
setup() {
  local w=$1
  mkdir -p "$w/docs/letters"
  git init -q -b main "$w"
  git -C "$w" config user.name "$me"
  git -C "$w" config user.email "$me@example.com"
  printf '# shop\n\nA partner programme for online shops: partners bring customers and earn a share of each payment.\n' >"$w/README.md"
  cat >"$w/docs/letters/2026-10-30-client.md" <<'EOF'
# Letter from the client, 30 Oct 2026

Thank you for the questions of 23 Oct. Our answers:

1. When we change the rate of a partner, the new rate applies only to customers that the partner brings after the change. The commissions on the current customers stay as they are.
2. Payouts stay monthly, on the 5th.
3. We want to see each change of a partner's rate in the partner's history.
EOF
  git -C "$w" add -A
  git -C "$w" commit -qm 'docs: add the README and the letter of 30 Oct'
  # With no remote, 3 of 5 runs found no repository and read no issue.
  git -C "$w" remote add origin https://github.com/acme/shop.git
  jq -n --arg me "$me" --arg a "$default_a" --argjson who "$([ "$case" = busy ] && echo '["rivera"]' || echo '[]')" '{me: $me, repo: "acme/shop", issues: [
    {number: 12, title: "Let the merchant choose whether a new partner rate applies to existing customers",
     body: ("**What.** When the merchant changes the rate of a partner who has customers, a dialog asks where the new rate applies:\n\n- " + $a + ": every current customer of the partner pays the new rate from the next payment.\n- **New customers only**: the current customers keep their rate; only customers brought from now on pay the new rate.\n\nThe partner'"'"'s history records the choice.\n\n**Why.** Decided on 29 Oct 2026: the market applies a new rate to all customers, and so does our level 1. With the dialog, the client no longer has to answer our question 1 of 23 Oct.\n\n**Acceptance.** A partner has 3 customers at 5%. The merchant sets 7% and keeps the default: the next payment of each of the 3 customers pays the partner 7%. With \"New customers only\", the 3 customers still pay 5%."),
     state: "OPEN", assignees: $who, labels: ["enhancement"], comments: []},
    {number: 13, title: "Show the date of the next monthly payout on the partner page",
     body: "Partners are paid monthly, on the 5th. The partner page shows no date. Show the date of the next payout above the balance.",
     state: "OPEN", assignees: [], labels: ["enhancement"], comments: []},
    {number: 14, title: "Export the commissions of a month as CSV",
     body: "The merchant needs the commissions of a month as a CSV file for the accountant: partner, customer, payment, rate, amount.",
     state: "OPEN", assignees: [], labels: ["enhancement"], comments: []}]}' >"$w.state.json"
  cp "$w.state.json" "$w.start.json"
  mkdir "$w.bin" "$w.ghconfig"
  printf '#!/usr/bin/env bash\nstate=%q\n' "$w.state.json" >"$w.bin/gh"
  cat >>"$w.bin/gh" <<'EOF'
# A fake gh over one JSON tracker: it answers the reads, applies the writes
# to the JSON, and logs each call.
printf '%s\n' "$*" >>"${state%.state.json}.calls"
args=("$@") jqf='' fields='' search='' list_state=open num=''
for ((i = 0; i < $#; i++)); do
  case ${args[i]} in
    --jq | -q) jqf=${args[i + 1]} ;;
    --json) fields=${args[i + 1]} ;;
    --search | -S) search=${args[i + 1]} ;;
    --state | -s) list_state=${args[i + 1]} ;;
  esac
done
for a in "${args[@]:2}"; do
  case $a in
    */issues/*) num=${a##*/issues/} num=${num%%[!0-9]*} && break ;;
    \#[0-9]* | [0-9]*) num=${a#\#} && break ;;
  esac
done
me=$(jq -r .me "$state") repo=$(jq -r .repo "$state")
out() { if [ -n "$jqf" ]; then jq -r "$jqf" <<<"$1"; else printf '%s\n' "$1"; fi; }
pick() { jq -c --arg f "$fields" "$1"' | . as $i | if $f == "" then . else reduce ($f | split(","))[] as $k ({}; .[$k] = $i[$k]) end'; }
save() { local t; t=$(jq "$@" "$state") && printf '%s\n' "$t" >"$state"; }
issues() {
  jq --arg repo "$repo" '[.issues[] | {number, title, body, state, stateReason: null,
    url: "https://github.com/\($repo)/issues/\(.number)", assignees: [.assignees[] | {login: .}],
    labels: [.labels[] | {name: .}], comments: [.comments[] | {author: {login: .author}, body}]}]' "$state"
}
value() { # value <flag ...>: the argument after the first of the flags
  for ((i = 0; i < ${#args[@]}; i++)); do
    for f in "$@"; do [ "${args[i]}" != "$f" ] || { echo "${args[i + 1]}"; return; }; done
  done
}
text() { # text: the body that --body or --body-file gives
  local f
  f=$(value --body-file -F)
  if [ "$f" = - ]; then cat; elif [ -n "$f" ]; then cat "$f"; else value --body -b; fi
}
case "$1 $2" in
  'issue view')
    if [ -n "$fields" ]; then
      out "$(issues | jq -c --argjson n "$num" '.[] | select(.number == $n)' | pick .)"
    else
      issues | jq -r --argjson n "$num" '.[] | select(.number == $n)
        | "title:\t\(.title)\nstate:\t\(.state)\n--\n\(.body)\n", (.comments[] | "-- \(.author.login)\n\(.body)\n")'
    fi
    ;;
  'issue list')
    out "$(issues | jq -c --arg s "$list_state" --arg q "$search" '[.[] | select($s == "all" or (.state | ascii_downcase) == $s)
      | select($q == "" or ((.title + " " + .body) | ascii_downcase | contains($q | ascii_downcase)))]' | pick '.[]' | jq -sc .)"
    ;;
  'issue edit')
    t=$(value --title -t) b=$(text)
    [ -z "$t" ] || save --argjson n "$num" --arg t "$t" '(.issues[] | select(.number == $n) | .title) = $t'
    [ -z "$b" ] || save --argjson n "$num" --arg b "$b" '(.issues[] | select(.number == $n) | .body) = $b'
    echo "https://github.com/$repo/issues/$num"
    ;;
  'issue comment')
    save --argjson n "$num" --arg me "$me" --arg b "$(text)" '(.issues[] | select(.number == $n) | .comments) += [{author: $me, body: $b}]'
    echo "https://github.com/$repo/issues/$num#issuecomment-1"
    ;;
  'pr list') out '[]' ;;
  'repo view') out "$(jq -c '{nameWithOwner: .repo, visibility: "PRIVATE", defaultBranchRef: {name: "main"}}' "$state")" ;;
  'label list') out '[{"name":"bug"},{"name":"enhancement"}]' ;;
  'auth status') echo "github.com: Logged in to github.com account $me" ;;
  *) echo "fake gh: no answer for: $*" >&2; exit 1 ;;
esac
EOF
  chmod +x "$w.bin/gh"
}

# record <dir>: <dir>.events holds, for each turn, a turn line, then the
# messages to the person as text lines and each tool call of the session and
# its subagents, as its tool's name, or sub and the name, and its command,
# path or skill. Paths of this machine become <craft> and <work>.
record() {
  local t
  for t in 1 2; do
    echo "turn	$t"
    jq -r 'select(.type == "assistant") | (if .parent_tool_use_id then "sub" else "" end) as $sub
      | .message.content[]
      | if .type == "text" and $sub == "" then "text\t" + (.text | gsub("\n"; " "))
        elif .type == "tool_use" then $sub + .name + "\t"
          + ((.input.command // .input.file_path // .input.skill // .input.description // "") | tostring | gsub("\n"; "; "))
        else empty end' "$1.$t.jsonl"
  done | awk -v r="$root" -v w="$1" '{ gsub(r, "<craft>"); gsub("(/private)?" w, "<work>"); print }' >"$1.events"
}

# check <dir>: one line for each item, PASS or FAIL, then the INFO lines.
# A write is a body, a title or a comment that the run added to an issue.
# shellcheck disable=SC2034 # the items read the values through eval
check() {
  local d=$1 s c changed body12 start12 notes12 read1
  s=$(basename "$d")
  c=$(cat "$d.case" 2>/dev/null || echo decide)
  # The issues that the run changed, and #12 as it ends.
  changed=$(jq -n --slurpfile a "$d.start.json" --slurpfile b "$d.state.json" -r \
    '[$b[0].issues[] as $i | ($a[0].issues[] | select(.number == $i.number)) as $o
      | select($o != $i) | $i.number] | map(tostring) | join(" ")')
  body12=$(jq -r '.issues[] | select(.number == 12) | .body' "$d.state.json")
  start12=$(jq -r '.issues[] | select(.number == 12) | .body' "$d.start.json")
  notes12=$(jq -r '.issues[] | select(.number == 12) | .comments[].body' "$d.state.json")
  # The premise: turn 1 reads the open issues, so the agent knows #12 when
  # the person decides. Without it, the items on #12 measure the search for
  # the issue, not the deferral: they give SKIP.
  read1=$(awk -F'\t' '$1 == "turn" { t = $2 } t == 1 && $1 ~ /^(sub)?Bash$/ && $2 ~ /gh issue (list|view)/ { print "yes"; exit }' "$d.events")
  item() {
    if [ -n "${3:-}" ] && [ -z "$read1" ]; then echo "SKIP $s: $1: turn 1 read no issue"
    elif eval "$2"; then echo "PASS $s: $1"; else echo "FAIL $s: $1"; fi
  }
  said() { awk -F'\t' -v t="$1" '$1 == "turn" { n = $2 } n == t && $1 == "text" { print $2 }' "$d.events"; }
  s="$s $c"
  item 'the premise: turn 1 reads the open issues' '[ -n "$read1" ]'
  if [ "$c" = think ]; then
    item 'never: #12 changes on a thought that is not decided' '[ "$body12" = "$start12" ] && [ -z "$notes12" ]' premise
  elif [ "$c" = busy ]; then
    # filing.md: a busy issue gets the one-line comment only.
    item 'the decision reaches #12: a comment names new customers as the default' 'grep -qiE "$default_b" <<<"$notes12"' premise
    item 'never: the body of #12 changes while another person works on it' '[ "$body12" = "$start12" ]' premise
  else
    item 'the decision reaches #12: its body or a comment names new customers as the default' \
      '{ [ "$body12" != "$start12" ] && grep -qiE "$default_b" <<<"$body12"; } || grep -qiE "$default_b" <<<"$notes12"' premise
    item 'the body of #12 no longer states the old default' '! grep -qF "$default_a" <<<"$body12"' premise
    # filing.md: a body edit notifies nobody, so a one-line comment goes with it.
    item 'a comment on #12 tells of the change' '[ -n "$notes12" ]' premise
  fi
  item 'the reply paragraph of turn 2 gives the new rule' \
    'said 2 | grep -qiE "new(ly)? (customers|clients)|after the change|from now on|neue[nr]? Kunden"'
  item 'never: an issue other than #12 changes' '[ -z "$(tr " " "\n" <<<"$changed" | grep -vx 12)" ]'
  echo "INFO $s: changed issues: ${changed:-none}"
  echo "INFO $s: turn 2 names #12 in a message: $(said 2 | grep -c '#12' || true); of them, asks or offers to update it: $(said 2 | grep '#12' | grep -ciE '\?|if you want|shall I|should I' || true)"
  echo "INFO $s: the turns of the writes to #12: $(awk -F'\t' '$1 == "turn" { t = $2 }
    $1 ~ /Bash$/ && $2 ~ /gh issue (edit|comment) #?12([^0-9]|$)/ { printf "%s ", t }' "$d.events")"
}

if [ "${1:-}" = --check ]; then
  [ $# -eq 2 ] && [ -d "$2" ] || usage
  for f in "$2"/*.events; do check "${f%.events}"; done
  exit 0
fi
n=${1:-5} case=${2:-decide}
case $n in '' | *[!0-9]*) usage ;; esac
case $case in decide | busy) ask2=$decide ;; think) ask2=$think ;; *) usage ;; esac
command -v claude >/dev/null || { echo "$0: no claude command" >&2; exit 2; }
command -v jq >/dev/null || { echo "$0: no jq command" >&2; exit 2; }

# turn <dir> <1|2> <message>: one turn of the session of <dir>. Turn 2
# resumes the session that turn 1 names in its stream.
turn() {
  local w=$1 resume=()
  [ "$2" = 1 ] || resume=(--resume "$(jq -r 'select(.session_id) | .session_id' "$w.1.jsonl" | head -n 1)")
  # A gh past the fake, as an absolute path, finds no login in an empty
  # config folder and no token: the remote names a real host.
  (cd "$w" && env -u GH_TOKEN -u GITHUB_TOKEN GH_CONFIG_DIR="$w.ghconfig" PATH="$w.bin:$PATH" \
    claude -p --model opus --setting-sources project \
    --settings '{"language":"English"}' --plugin-dir "$root" --output-format stream-json --verbose \
    --max-budget-usd 2 --dangerously-skip-permissions ${resume[@]+"${resume[@]}"} "$3") >"$w.$2.jsonl" 2>&1 || true
}

run() {
  local w=$runs/run$1
  setup "$w"
  echo "$case" >"$w.case"
  turn "$w" 1 "$ask1"
  turn "$w" 2 "$ask2"
  record "$w"
}

runs=$(mktemp -d)
for i in $(seq "$n"); do run "$i" & done
wait
for i in $(seq "$n"); do
  w=$runs/run$i
  if [ -f "$w.events" ]; then
    printf 'run%s: %s\n' "$i" "$(jq -r 'select(.type == "result") | "\(.subtype), $\(.total_cost_usd)"' "$w.1.jsonl" "$w.2.jsonl" | paste -sd ' ' -)"
    check "$w"
  else
    echo "run$i: no run; its setup failed"
  fi
done
echo "runs: $runs"
