#!/bin/bash
# Runs the roadmap skill's scripts against a fake gh. The fake answers from
# payloads recorded on public repositories, filtered through jq as gh's own
# --jq does, and logs every call, so no test reaches GitHub.

# shellcheck disable=SC2016 # the single-quoted $ are jq's
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
scripts=$root/skills/roadmap/scripts
fixtures=$root/tests/fixtures/roadmap
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir "$tmp/bin" "$tmp/fake"
cat >"$tmp/bin/gh" <<'EOF'
#!/bin/bash
echo "$*" >>"$FAKE/calls"
case "$*" in *"${FAKE_FAIL:-no failure asked}"*) echo 'gh: HTTP 502' >&2; exit 1 ;; esac
filter=. a='' b=''
for ((i = 1; i <= $#; i++)); do
  j=$((i + 1))
  case ${!i} in
    --jq) filter=${!j} ;;
    -F | -f) case ${!j} in a=*) a=${!j#a=} ;; b=*) b=${!j#b=} ;; esac ;;
  esac
done
# Each answer comes from $FAKE when the file is there, else from the fixture.
src() { if [ -f "$FAKE/$1" ]; then echo "$FAKE/$1"; else echo "$FIXTURES/$1"; fi; }
# The pages of a paginated read, the filter applied to each, as gh does.
pages() {
  local p
  p=$(ls "$FAKE/$1"-*.json 2>/dev/null || ls "$FIXTURES/$1"-*.json)
  for f in $p; do jq -r "$filter" "$f"; done
}
case "$*" in
  'api graphql'*mutation*) ;;
  'api graphql'*'issues(states: OPEN'*) pages issues ;;
  'api graphql'*'pullRequests(states: OPEN'*) pages prs ;;
  'api graphql'*'a: issue(number'*)
    jq -nr --arg a "$a" --arg b "$b" '{data: {repository: {a: {id: "I_\($a)"}, b: {id: "I_\($b)"}}}}' | jq -r "$filter" ;;
  'api graphql'*'projectsV2('*) jq -r "$filter" "$(src projects-linked.json)" ;;
  'api graphql'*'views('*) jq -r "$filter" "$(src project-views.json)" ;;
  'api -X '*) ;;
  'api repos/{owner}/{repo}/milestones?'*) jq -r "$filter" "$(src milestones.json)" ;;
  'api repos/{owner}/{repo}/milestones/'*)
    jq --argjson n "${2##*/}" '.[] | select(.number == $n)' "$(src milestones.json)" | jq -r "$filter" ;;
  'api repos/{owner}/{repo}/compare/'*) jq -r "$filter" "$(src compare.json)" ;;
  'api repos/{owner}/{repo}/pulls/'*/files*) jq -r "$filter" "$(src pr-files.json)" ;;
  'api repos/{owner}/{repo}'*) jq -r "$filter" "$(src repo.json)" ;;
  'issue view'*)
    if [ -f "$FAKE/body-$3" ]; then jq -Rs '{body: .}' "$FAKE/body-$3"; else echo '{"body": ""}'; fi | jq -r "$filter" ;;
  'issue list'*)
    for f in $(ls "$FAKE"/issues-*.json 2>/dev/null || ls "$FIXTURES"/issues-*.json); do
      jq '.data.repository.issues.nodes' "$f"
    done | jq -s 'add | map({number, url: "https://github.com/kalinichenko88/agent-skills/issues/\(.number)"})' | jq -r "$filter" ;;
  'issue edit'*) ;;
  *) echo "fake gh: no answer for: $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH" FAKE="$tmp/fake" FIXTURES="$fixtures" TMPDIR="$tmp"

fail() {
  printf 'FAIL: %s\n' "$1"
  [ -z "${2:-}" ] || printf '%s\n' "$2"
  exit 1
}
check() { [ "$2" = "$3" ] || fail "$1" "$(printf 'want: %s\ngot:  %s' "$2" "$3")"; }
# Empties the fake's answers, so each case starts from the fixtures.
reset() { find "$FAKE" -mindepth 1 ! -name calls -delete; }
# The recorded number of a milestone: M0 to M5, or Later.
msno() { jq -r --arg m "$1" '.[] | select(.title == $m or (.title | startswith($m + " "))) | .number' "$fixtures/milestones.json"; }
# Changes the milestones that the fake answers with by the jq filter $1.
ms() {
  local f=$FAKE/milestones.json
  [ -f "$f" ] || f=$fixtures/milestones.json
  jq "$@" "$f" >"$FAKE/milestones.next" && mv "$FAKE/milestones.next" "$FAKE/milestones.json"
}
mark() { ms 'map(if .title == $m or (.title | startswith($m + " ")) then .description += "\n\nCurrent." else . end)' --arg m "$1"; }
# The open issues, as one page: put '19 20:M2 21:Later 22:-' makes #19 in M1,
# #20 in M2, #21 in Later and #22 with no milestone. Each is the recorded
# issue, emptied of its labels, people, links and sub-issues.
node='{number: .[0], title: "Issue \(.[0])", milestone: (if .[1] then {number: .[1]} else null end)} as $new
  | $t + $new | .labels.nodes = [] | .assignees.nodes = [] | .linkedBranches.nodes = []
  | .closedByPullRequestsReferences.nodes = [] | .blockedBy.nodes = [] | .parent = null
  | .subIssuesSummary = {total: 0, completed: 0}'
write_page() {
  jq --argjson spec "$2" ".data.repository.issues.nodes[0] as \$t
    | .data.repository.issues.pageInfo.hasNextPage = $3 | .data.repository.issues.nodes = [\$spec[] | $node]" \
    "$fixtures/issues-1.json" >"$FAKE/issues-$1.json"
}
put() {
  local spec='' e n m
  for e in $1; do
    n=${e%%:*} m=M1
    [ "$e" = "$n" ] || m=${e#*:}
    if [ "$m" = - ]; then m=null; else m=$(msno "$m"); fi
    spec="$spec,[$n,$m]"
  done
  rm -f "$FAKE"/issues-*.json
  write_page 1 "[${spec#,}]" false
}
# Issues 1 to $1, all in M1, as pages of 100.
pages() {
  local m p=1 first
  m=$(msno M1)
  rm -f "$FAKE"/issues-*.json
  for ((first = 1; first <= $1; first += 100)); do
    write_page "$p" "$(jq -nc --argjson f "$first" --argjson l "$1" --argjson m "$m" '[range($f; [$f + 100, $l + 1] | min) | [., $m]]')" \
      "$([ $((first + 100)) -le "$1" ] && echo true || echo false)"
    p=$((p + 1))
  done
}
# Changes issue $1 by the jq filter $2, on whichever page it is.
edit() {
  local f
  for f in "$FAKE"/issues-*.json; do
    jq --argjson n "$1" ".data.repository.issues.nodes |= map(if .number == \$n then ($2) else . end)" "$f" >"$f.next"
    mv "$f.next" "$f"
  done
}
# Makes issue $1 blocked by the open issues $2… of this repository.
blocks() {
  local n=$1 m
  shift
  for m in "$@"; do
    edit "$n" ".blockedBy.nodes += [{number: $m, state: \"OPEN\", repository: {nameWithOwner: \"kalinichenko88/agent-skills\"}}]"
  done
}

# read.sh issues: every page, and each field of the record.
reset
pages 150
check 'issues reads every page' 150 "$(bash "$scripts/read.sh" issues | grep -c '^is	')"
reset
put '19 20 21'
edit 19 '.blockedBy.nodes = [{number: 116, state: "CLOSED", repository: {nameWithOwner: "kalinichenko88/agent-skills"}}]'
edit 20 '.assignees.nodes = [{login: "kalinichenko88"}] | .linkedBranches.nodes = [{ref: {name: "fix/20-x"}}]
  | .closedByPullRequestsReferences.nodes = [{number: 9, state: "OPEN", author: {login: "someone"}}, {number: 8, state: "MERGED", author: {login: "someone"}}]'
blocks 21 19
edit 21 '.blockedBy.nodes += [{number: 3, state: "OPEN", repository: {nameWithOwner: "other/repo"}}] | .labels.nodes = [{name: "bug"}]
  | .parent = {number: 19, milestone: {number: 7}, repository: {nameWithOwner: "kalinichenko88/agent-skills"}} | .subIssuesSummary = {total: 3, completed: 1}'
out=$(bash "$scripts/read.sh" issues)
m1=$(msno M1)
check 'a closed blocker is not listed' "$(printf 'is\t19\t%s\t0\t-\t-\t0\t0\t0\tIssue 19' "$m1")" "$(grep '^is	19	' <<<"$out")"
check 'busy in collect.sh words' 'assigned to you, branch fix/20-x, PR #9 by someone' \
  "$(awk -F'\t' '$1=="is" && $2==20 {print $5}' <<<"$out")"
check 'linked branch' "$(printf 'br\t20\tfix/20-x')" "$(grep '^br	' <<<"$out")"
check 'blockers, bug, parent, its milestone, open sub-issues' \
  "$(printf 'is\t21\t%s\t1\t-\t#19,other/repo#3\t19\t7\t2\tIssue 21' "$m1")" "$(grep '^is	21	' <<<"$out")"
check 'the repository' "$(printf 'repo\tkalinichenko88/agent-skills')" "$(grep '^repo	' <<<"$out" | tail -1)"
check 'another bug label' 0 "$(bash "$scripts/read.sh" issues defect | awk -F'\t' '$1=="is" && $2==21 {print $4}')"

# read.sh milestones: in order, the current mark, the description lines.
reset
check 'order, Later last' "$(printf 'M0 · Stage 0\nM1 · Stage 1\nM2 · Stage 2\nM3 · Stage 3\nM4 · Stage 4\nM5 · Stage 5\nLater')" \
  "$(bash "$scripts/read.sh" milestones | awk -F'\t' '$1=="ms" {print $8}')"
check 'the first is current when none is marked' 'M0 · Stage 0' \
  "$(bash "$scripts/read.sh" milestones | awk -F'\t' '$1=="ms" && $4==1 {print $8}')"
mark M0
ms '(.[] | select(.title | startswith("M1 ")) | .description) += "\r\n Current. \r\n"'
out=$(bash "$scripts/read.sh" milestones)
check 'marked milestones are current' "$(printf 'M0 · Stage 0\nM1 · Stage 1')" "$(awk -F'\t' '$1=="ms" && $4==1 {print $8}' <<<"$out")"
check 'the mark is no description line' 0 "$(grep -c 'Current\.' <<<"$out")"
check 'no carriage return' 0 "$(grep -c $'\r' <<<"$out")"
mark Later
check 'Later is never current' 0 "$(bash "$scripts/read.sh" milestones | awk -F'\t' '$1=="ms" && $5==1 {print $4}')"
reset
check 'M1 resolves' "$(printf '%s\tM1 · Stage 1' "$(msno M1)")" "$(bash "$scripts/read.sh" milestone M1)"
check 'later resolves in any case' Later "$(bash "$scripts/read.sh" milestone later | cut -f2)"
bash "$scripts/read.sh" milestone M9 2>/dev/null && fail 'an unknown milestone exits 0'
ms 'map(if (.title | startswith("M1 ")) then .title = "M10 · Stage 10" else . end)'
bash "$scripts/read.sh" milestone M1 2>/dev/null && fail 'M1 matches M10'

# read.sh prs. The recorded pull requests are the owner's, so each author is you.
reset
first=$(jq -r '.data.repository.pullRequests.nodes[0] | "\(.number)\t\(.files.totalCount)"' "$fixtures/prs-1.json")
check 'pr record: number, you, file count' "$(printf 'pr\t%s\tyou\t%s' "${first%%	*}" "${first##*	}")" \
  "$(bash "$scripts/read.sh" prs | grep '^pr	' | head -1 | cut -f1-3,6)"
check 'usage' 2 "$(bash "$scripts/read.sh" >/dev/null 2>&1; echo $?)"

echo 'roadmap_scripts_test: ok'
