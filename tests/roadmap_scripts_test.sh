#!/usr/bin/env bash
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
#!/usr/bin/env bash
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
  'api graphql'*'milestones(states: OPEN'*) pages milestone-counts ;;
  'api graphql'*'issues(states: OPEN'*) pages issues ;;
  'api graphql'*'pullRequests(states: OPEN'*) pages prs ;;
  'api graphql'*'a: issue(number'*)
    jq -nr --arg a "$a" --arg b "$b" '{data: {repository: {a: {id: "I_\($a)"}, b: {id: "I_\($b)"}}}}' | jq -r "$filter" ;;
  'api graphql'*'projectsV2('*) jq -r "$filter" "$(src projects-linked.json)" ;;
  'api graphql'*'views('*) jq -r "$filter" "$(src project-views.json)" ;;
  'api -X '*) ;;
  'api repos/{owner}/{repo}/milestones?state=closed'*) jq -r "$filter" "$(src milestones-closed.json)" ;;
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
  'project list'*) jq -r "$filter" "$(src project-list.json)" ;;
  'project view'* | 'project create'*) jq -r "$filter" "$(src project-view.json)" ;;
  'project item-list'*) jq -r "$filter" "$(src project-items.json)" ;;
  'project link'* | 'project item-add'*) ;;
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

# A title keeps its backslashes: golang/go#82205's.
reset
put '19'
edit 19 '.title = "strconv: Unquote(`'"'"'\\xff'"'"'`) returns \"\\xff\" (invalid UTF-8) instead of the encoding of U+00FF"'
check 'a title with backslashes' $'- #19 strconv: Unquote(`\'\\xff\'`) returns "\\xff" (invalid UTF-8) instead of the encoding of U+00FF: free' \
  "$(bash "$scripts/roadmap.sh" | grep '^- #19 ')"

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
  "$(bash "$scripts/read.sh" milestones | awk -F'\t' '$1=="ms" {print $6}')"
check 'the first is current when none is marked' 'M0 · Stage 0' \
  "$(bash "$scripts/read.sh" milestones | awk -F'\t' '$1=="ms" && $4==1 {print $6}')"
mark M0
ms '(.[] | select(.title | startswith("M1 ")) | .description) += "\r\n Current. \r\n"'
out=$(bash "$scripts/read.sh" milestones)
check 'marked milestones are current' "$(printf 'M0 · Stage 0\nM1 · Stage 1')" "$(awk -F'\t' '$1=="ms" && $4==1 {print $6}' <<<"$out")"
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
# Two open titles that start with M1, as one made by hand on GitHub gives: M1
# names neither, in read.sh and in each script that reads through it.
reset
ms '. + [.[] | select(.title == "M1 · Stage 1") | .number = 999 | .title = "M1 · Other"]'
bash "$scripts/read.sh" milestone M1 >"$tmp/out" 2>&1 && fail 'M1 of two milestones exits 0'
check 'M1 of two milestones names both' \
  "$(printf 'read.sh: M1 matches more than one open milestone; name it by its whole title:\n  M1 · Stage 1\n  M1 · Other')" "$(cat "$tmp/out")"
check 'a whole title of the two resolves' 999 "$(bash "$scripts/read.sh" milestone 'm1 · other' | cut -f1)"
bash "$scripts/roadmap.sh" M1 >/dev/null 2>&1 && fail 'roadmap.sh M1 of two milestones exits 0'
out=$(DRY_RUN=1 bash "$scripts/plan.sh" current M1 2>&1) && fail 'plan.sh current M1 of two milestones exits 0'
check 'plan.sh current M1 of two milestones gives the reason' 1 "$(grep -c '^read.sh: M1 matches more than one' <<<"$out" || true)"
check 'plan.sh current M1 of two milestones writes nothing' 0 "$(grep -c '^dry run' <<<"$out" || true)"
# A title that is M1 alone is its own whole title, so M1 names it.
ms '. + [.[] | select(.title == "M1 · Stage 1") | .number = 998 | .title = "M1"]'
check 'the whole title M1 resolves next to M1 · ...' 998 "$(bash "$scripts/read.sh" milestone M1 | cut -f1)"

# read.sh prs. The recorded pull requests are the owner's, so each author is you.
reset
first=$(jq -r '.data.repository.pullRequests.nodes[0] | "\(.number)\t\(.files.totalCount)"' "$fixtures/prs-1.json")
check 'pr record: number, you, file count' "$(printf 'pr\t%s\tyou\t%s' "${first%%	*}" "${first##*	}")" \
  "$(bash "$scripts/read.sh" prs | grep '^pr	' | head -1 | cut -f1-3,6)"
check 'usage' 2 "$(bash "$scripts/read.sh" >/dev/null 2>&1; echo $?)"

# roadmap.sh: each milestone in order, its issues in dependency order with
# their state.
reset
mark M1
put '19 20 21 22 23 42:Later 50:M2'
blocks 20 21
edit 22 '.assignees.nodes = [{login: "kalinichenko88"}]'
edit 23 '.blockedBy.nodes = [{number: 3, state: "OPEN", repository: {nameWithOwner: "other/repo"}}]'
out=$(bash "$scripts/roadmap.sh")
check 'dependency order and states' \
  "$(printf -- '- #19 Issue 19: free\n- #21 Issue 21: free\n- #20 Issue 20: blocked by #21\n- #22 Issue 22: assigned to you\n- #23 Issue 23: blocked by other/repo#3')" \
  "$(sed -n '/^## M1 /,/^## /p' <<<"$out" | grep '^- ')"
progress() {
  jq -r --argjson n "$(msno "$1")" '.data.repository.milestones.nodes[] | select(.number == $n)
    | "\(.closedIssues.totalCount) of \(.openIssues.totalCount + .closedIssues.totalCount) closed"' "$fixtures/milestone-counts-1.json"
}
check 'a current milestone' "current, $(progress M1)" "$(sed -n '/^## M1 /{n;p;}' <<<"$out")"
# REST's counts of a milestone take in its pull requests: recorded at one
# moment, M2 has 1057 open and 3748 closed in REST, and 1056 open and 3710
# closed issues. The line counts issues only.
check 'a milestone that is not current, without its pull requests' "$(progress M2)" "$(sed -n '/^## M2 /{n;p;}' <<<"$out")"
check 'Later shows titles only' '- #42 Issue 42' "$(sed -n '/^## Later/,/^## /p' <<<"$out" | grep '^- ')"
check 'Later by name shows states' '- #42 Issue 42: free' "$(bash "$scripts/roadmap.sh" Later | grep '^- ')"
# A cycle made by hand in GitHub ends, and both issues show.
blocks 21 20
check 'a cycle prints each issue once' 2 "$(bash "$scripts/roadmap.sh" | grep -cE '^- #2[01] ')"
# A due date shows as its day: golang/go's Unplanned is due 2099-12-31T05:00:00Z.
ms 'map(if (.title | startswith("M1 ")) then .due_on = "2099-12-31T05:00:00Z" else . end)'
check 'a due date' "current, $(progress M1), due 2099-12-31" "$(bash "$scripts/roadmap.sh" | sed -n '/^## M1 /{n;p;}')"
# A milestone closed between the list read and the count read has no count.
ms '. + [{number: 998, title: "M9 · Stage 9", description: "", state: "open", open_issues: 0, closed_issues: 0}]'
check 'a milestone with no count' 'not counted' "$(bash "$scripts/roadmap.sh" | sed -n '/^## M9 /{n;p;}')"

# A sub-issue takes its parent's milestone and blockers; a parent waits on its
# open sub-issues, also those in another repository.
reset
put '19 30:- 31:M2'
edit 30 ".parent = {number: 19, milestone: {number: $(msno M1)}, repository: {nameWithOwner: \"kalinichenko88/agent-skills\"}}"
blocks 19 31
edit 19 '.subIssuesSummary = {total: 2, completed: 0}'
out=$(bash "$scripts/roadmap.sh")
check 'a sub-issue under its parent milestone, blocked through it' '- #30 Issue 30: blocked by #31' \
  "$(sed -n '/^## M1 /,/^## /p' <<<"$out" | grep '^- #30 ')"
check 'a parent waits on all its open sub-issues' '- #19 Issue 19: blocked by #31; open sub-issues: 2' "$(grep '^- #19 ' <<<"$out")"
check 'one milestone with a blocker elsewhere' '- #31 Issue 31 (M2 · Stage 2): free' "$(bash "$scripts/roadmap.sh" M1 | grep '^- #31 ')"
check 'one milestone has one section' 1 "$(bash "$scripts/roadmap.sh" M1 | grep -c '^## ')"

# A closed milestone counts as none.
reset
put '19 24'
edit 24 '.milestone = {number: 999999}'
check 'an issue in a closed milestone' '1 open: #24' "$(bash "$scripts/roadmap.sh" | sed -n '/^## No milestone/{n;p;}')"

# No milestones at all, as in a new project.
reset
ms '[]'
put '19:-'
check 'no milestones' "$(printf '# Roadmap of kalinichenko88/agent-skills\n\nNo open milestones.')" "$(bash "$scripts/roadmap.sh" | sed -n '1,3p')"

# next.sh: the tracks, ranked.
section() { sed -n "/^== $1/,/^== /p" | grep -E '^(#|and |none)' || true; }
reset
mark M1
put '19 20 21 22 40:M2 41:-'
blocks 20 21
blocks 19 20
edit 22 '.labels.nodes = [{name: "bug"}]'
out=$(bash "$scripts/next.sh")
check 'current line' 'current: M1 · Stage 1' "$(head -1 <<<"$out")"
check 'main path: a chain counts every step' '#21 Issue 21 (M1 · Stage 1), unblocks 2' "$(section 'main path' <<<"$out")"
check 'bugs' '#22 Issue 22 (M1 · Stage 1), unblocks 0' "$(section bugs <<<"$out")"
check 'secondary: next milestone, then none' \
  "$(printf '#40 Issue 40 (M2 · Stage 2), unblocks 0\n#41 Issue 41 (no milestone), unblocks 0')" "$(section secondary <<<"$out")"
# A blocker in M3 of an M1 task is on the main path and ranks with M1.
reset
mark M1
put '19 20 21 40:M3'
blocks 19 40
blocks 20 40 21
check 'an M3 blocker ranks with M1 by its unblock count' \
  "$(printf '#40 Issue 40 (M3 · Stage 3), unblocks 2\n#21 Issue 21 (M1 · Stage 1), unblocks 1')" "$(bash "$scripts/next.sh" | section 'main path')"
# A sub-issue in a later milestone of an M1 parent is on the main path.
reset
mark M1
put '19 30:M3'
edit 30 ".parent = {number: 19, milestone: {number: $(msno M1)}, repository: {nameWithOwner: \"kalinichenko88/agent-skills\"}}"
edit 19 '.subIssuesSummary = {total: 1, completed: 0}'
check 'a sub-issue of an M1 parent' '#30 Issue 30 (M3 · Stage 3), unblocks 1' "$(bash "$scripts/next.sh" | section 'main path')"
# A cycle made by hand: neither is free, and the script ends.
reset
mark M1
put '20 21'
blocks 20 21
blocks 21 20
check 'a cycle ends, nothing offered' 'none' "$(bash "$scripts/next.sh" | section 'main path')"
# Nothing free in M1: the main path is from the next milestone.
reset
mark M1
put '19 40:M2'
edit 19 '.assignees.nodes = [{login: "someone"}]'
out=$(bash "$scripts/next.sh")
check 'fallback note' 'note: nothing on the main path of M1 · Stage 1 is free; it is from M2 · Stage 2' "$(sed -n 2p <<<"$out")"
check 'busy issue in progress' '#19 Issue 19: assigned to someone' "$(section 'in progress' <<<"$out")"
# A milestone between two current ones is the next one.
reset
mark M1
mark M3
put '19 30:M3 40:M2 50:M4'
edit 19 '.assignees.nodes = [{login: "someone"}]'
edit 30 '.assignees.nodes = [{login: "someone"}]'
out=$(bash "$scripts/next.sh")
check 'fallback between current milestones' 'note: nothing on the main path of M1 · Stage 1, M3 · Stage 3 is free; it is from M2 · Stage 2' "$(sed -n 2p <<<"$out")"
check 'fallback main path' '#40 Issue 40 (M2 · Stage 2), unblocks 0' "$(section 'main path' <<<"$out")"
# A task in Later that an issue outside Later waits on, through any chain, is
# offered; one that nothing outside Later waits on is not.
reset
mark M1
put '19 42:Later 43:Later 44:Later'
blocks 19 42
blocks 42 43
out=$(bash "$scripts/next.sh")
check 'a task in Later that M1 waits on' '#43 Issue 43 (Later), unblocks 2' "$(section 'main path' <<<"$out")"
check 'a task in Later that nothing waits on' 'none' "$(section secondary <<<"$out")"
# The top 5, the rest counted; Later never offered.
reset
put '1:- 2:- 3:- 4:- 5:- 6:- 7:- 8:Later'
check 'and k more' 'and 2 more' "$(bash "$scripts/next.sh" | section secondary | tail -1)"
check 'Later is not offered' 0 "$(bash "$scripts/next.sh" | grep -c '^#8 ' || true)"

# The main path shows its top 5 too; the overlap file takes all of it.
reset
put '1 2 3 4 5 6 7'
out=$(bash "$scripts/next.sh")
check 'the main path shows its top 5' 'and 2 more' "$(section 'main path' <<<"$out" | tail -1)"
check 'the overlap file takes the whole main path' 7 \
  "$(grep -c '^==> #.*\[main path, ' "$(sed -n 's/^overlap: \([^ ]*\) .*/\1/p' <<<"$out")")"

# The overlap file.
overlap() { bash "$scripts/next.sh" | sed -n 's/^overlap: \([^ ]*\) .*/\1/p'; }
reset
put '19 21'
edit 21 '.assignees.nodes = [{login: "someone"}] | .linkedBranches.nodes = [{ref: {name: "fix/21-x"}}]'
printf 'Fix `src/server/log.ts:12-14` and src/app/main.ts, see https://github.com/x/y/blob/main/z.ts and e.g. this.\n' >"$FAKE/body-19"
f=$(overlap)
check 'cites' 'cites: src/server/log.ts, src/app/main.ts' "$(grep '^cites: ' "$f")"
printf 'Plan\n====\nFix src/a/b.ts\n' >"$FAKE/body-19"
check 'a body line that starts with == stays in its entry' ' ====' "$(sed -n '/^==> #19 /,/^==> /p' "$(overlap)" | grep '=====*$')"
check 'branch files from compare' "files: $(jq -r '[.files[].filename] | join(", ")' "$fixtures/compare.json")" \
  "$(sed -n '/^==> #21 /,/^==> /p' "$f" | grep '^files: ')"
check 'a failed compare is no diff yet' 'no diff yet' "$(sed -n '/^==> #21 /{n;p;}' "$(FAKE_FAIL='compare/' overlap)")"
check 'PRs closing no issue' "$(jq '.data.repository.pullRequests.nodes | length' "$fixtures/prs-1.json")" \
  "$(bash "$scripts/next.sh" | grep -c '^PR #.*: closes no open issue$')"
# An open PR that closes only issues closed already is work in progress too.
jq '.data.repository.pullRequests.nodes[].closingIssuesReferences.nodes = [{number: 999, repository: {nameWithOwner: "kalinichenko88/agent-skills"}}]' \
  "$fixtures/prs-1.json" >"$FAKE/prs-1.json"
check 'PRs closing only closed issues' "$(jq '.data.repository.pullRequests.nodes | length' "$fixtures/prs-1.json")" \
  "$(bash "$scripts/next.sh" | grep -c '^PR #.*: closes no open issue$')"
echo '{"files": []}' >"$FAKE/compare.json"
check 'no diff yet' 'no diff yet' "$(sed -n '/^==> #21 /{n;p;}' "$(overlap)")"
# The files of an open PR that closes the issue win over the branch, and past
# 100 they come from REST.
jq '.data.repository.pullRequests.nodes[0].closingIssuesReferences.nodes = [{number: 21, repository: {nameWithOwner: "kalinichenko88/agent-skills"}}]
  | .data.repository.pullRequests.nodes[0].files |= {totalCount: 150, nodes: .nodes[:1]}' "$fixtures/prs-1.json" >"$FAKE/prs-1.json"
check 'all the files of a large PR' "files: $(jq -r '[.[].filename] | join(", ")' "$fixtures/pr-files.json")" \
  "$(sed -n '/^==> #21 /,/^==> /p' "$(overlap)" | grep '^files: ')"
jq '.[0].filename = "docs/a\\new.md"' "$fixtures/pr-files.json" >"$FAKE/pr-files.json"
check 'a file name with a backslash' 'docs/a\new.md' "$(sed -n '/^==> #21 /,/^==> /p' "$(overlap)" | sed -n 's/^files: \([^,]*\),.*/\1/p')"
# GitHub can give no file list for a PR.
jq '.data.repository.pullRequests.nodes[0].files = null' "$fixtures/prs-1.json" >"$FAKE/prs-1.json"
bash "$scripts/next.sh" >/dev/null 2>&1 || fail 'next.sh stops on a PR without a file list'
# No milestones at all.
reset
ms '[]'
put '19:-'
check 'no milestones' 'current: none' "$(bash "$scripts/next.sh" | head -1)"
# A failed read stops the script.
FAKE_FAIL='pullRequests(' bash "$scripts/next.sh" >/dev/null 2>&1 && fail 'next.sh exits 0 when a read fails'
check 'next.sh prints nothing when a read fails' '' "$(FAKE_FAIL='milestones?' bash "$scripts/next.sh" 2>/dev/null || true)"
FAKE_FAIL='milestones(states' bash "$scripts/next.sh" >/dev/null 2>&1 || fail 'next.sh reads the counts it does not print'

check 'roadmap.sh prints nothing when a read fails' '' "$(FAKE_FAIL='milestones?' bash "$scripts/roadmap.sh" 2>/dev/null || true)"
check 'roadmap.sh prints nothing when the count read fails' '' "$(FAKE_FAIL='milestones(states' bash "$scripts/roadmap.sh" 2>/dev/null || true)"

# plan.sh refuses a link that makes a cycle, and sends nothing.
reset
put '19 20 21'
blocks 20 21
: >"$FAKE/calls"
check 'block refuses a cycle' 'refused: it makes a cycle: #21 → #20 → #21' "$(bash "$scripts/plan.sh" block 21 20 2>&1 || true)"
check 'a refused block sends no mutation' 0 "$(grep -c mutation "$FAKE/calls" || true)"
out=$(DRY_RUN=1 bash "$scripts/plan.sh" block 19 21)
case $out in *'dry run: gh api graphql'*addBlockedBy*) ;; *) fail 'block prints its mutation in a dry run' "$out" ;; esac
out=$(DRY_RUN=1 bash "$scripts/plan.sh" unblock 20 21)
case $out in *'dry run: gh api graphql'*removeBlockedBy*) ;; *) fail 'unblock prints its mutation in a dry run' "$out" ;; esac
check 'a dry run sends no mutation' 0 "$(grep -c mutation "$FAKE/calls" || true)"
check 'block to itself' 'refused: an issue cannot wait on itself' "$(bash "$scripts/plan.sh" block 19 19 2>&1 || true)"
# A cycle through an inherited blocker: #11 is a sub-issue of #10, and #12
# waits on #11. Blocking #10 on #12 makes #11 wait on #12.
reset
put '10 11 12'
edit 11 '.parent = {number: 10, milestone: null, repository: {nameWithOwner: "kalinichenko88/agent-skills"}}'
blocks 12 11
check 'block refuses an inherited cycle' 'refused: it makes a cycle: #11 → #12 → #11' "$(bash "$scripts/plan.sh" block 10 12 2>&1 || true)"
check 'block refuses a parent blocked by its own sub-issue' 'refused: it makes a cycle: #11 would wait on itself through #10' \
  "$(bash "$scripts/plan.sh" block 10 11 2>&1 || true)"
# sub: the child would inherit #20, which waits on the child.
reset
put '19 20 21 22'
blocks 20 21
blocks 19 20
check 'sub refuses a cycle through the parent blockers' 'refused: it makes a cycle: #21 → #20 → #21' \
  "$(bash "$scripts/plan.sh" sub 19 21 2>&1 || true)"
out=$(DRY_RUN=1 bash "$scripts/plan.sh" sub 22 19)
case $out in *'dry run: gh api graphql'*addSubIssue*) ;; *) fail 'sub prints its mutation in a dry run' "$out" ;; esac

# plan.sh on milestones.
reset
put '19 20 21'
ms '(.[] | select(.title | startswith("M1 ")) | .description) = "Goal."'
out=$(DRY_RUN=1 bash "$scripts/plan.sh" current M1)
check 'current adds the mark after a blank line' "$(printf 'Goal.\n\nCurrent.')" "$(cat "$(sed -n 's/.*description=@\([^ ]*\).*/\1/p' <<<"$out")")"
mark M1
check 'current twice' 'M1 · Stage 1 is current already' "$(bash "$scripts/plan.sh" current M1)"
out=$(DRY_RUN=1 bash "$scripts/plan.sh" not-current M1)
check 'not-current removes the mark' 'Goal.' "$(cat "$(sed -n 's/.*description=@\([^ ]*\).*/\1/p' <<<"$out")")"
check 'Later is never current' 'refused: Later is never current' "$(bash "$scripts/plan.sh" current later 2>&1 || true)"
check 'create refuses an existing title in any case' 'refused: m1 · stage 1 exists' "$(bash "$scripts/plan.sh" create 'm1 · stage 1' /dev/null 2>&1 || true)"
ms '. + [{number: 999, title: "C:\\new", description: "", state: "open", open_issues: 0, closed_issues: 0}]'
check 'create refuses an existing title with a backslash' 'refused: C:\new exists' "$(bash "$scripts/plan.sh" create 'C:\new' /dev/null 2>&1 || true)"
check 'close refuses open issues' 'refused: M1 · Stage 1 has 3 open issues: #19, #20, #21' "$(bash "$scripts/plan.sh" close M1 2>&1 || true)"
printf 'New goal.\n' >"$tmp/goal"
out=$(DRY_RUN=1 bash "$scripts/plan.sh" describe M1 "$tmp/goal")
check 'describe keeps the mark' "$(printf 'New goal.\n\nCurrent.')" "$(cat "$(sed -n 's/.*description=@\([^ ]*\).*/\1/p' <<<"$out")")"
# rename sends the title alone, so the description and its mark stay.
out=$(DRY_RUN=1 bash "$scripts/plan.sh" rename M1 'M1 · First demo')
check 'rename sends the title alone' "dry run: gh api -X PATCH repos/\{owner\}/\{repo\}/milestones/$(msno M1) -f title=M1\ ·\ First\ demo --silent" "$out"
check 'rename refuses a title another milestone has, in any case' 'refused: m2 · stage 2 exists' \
  "$(bash "$scripts/plan.sh" rename M1 'm2 · stage 2' 2>&1 || true)"
check 'rename refuses an existing title with a backslash' 'refused: C:\new exists' "$(bash "$scripts/plan.sh" rename M1 'C:\new' 2>&1 || true)"
check 'rename changes the case of its own title' 'renamed M1 · Stage 1 to M1 · STAGE 1' \
  "$(bash "$scripts/plan.sh" rename M1 'M1 · STAGE 1' 2>&1)"
check 'create refuses the M<n> of another milestone' 'refused: M1 · Stage 1 is M1 already' \
  "$(bash "$scripts/plan.sh" create 'M1 · Another' /dev/null 2>&1 || true)"
check 'create refuses the M<n> of another milestone in lower case' 'refused: M1 · Stage 1 is M1 already' \
  "$(bash "$scripts/plan.sh" create 'm1 · another' /dev/null 2>&1 || true)"
check 'rename refuses the M<n> of another milestone' 'refused: M1 · Stage 1 is M1 already' \
  "$(bash "$scripts/plan.sh" rename M2 'M01 · Third' 2>&1 || true)"
out=$(DRY_RUN=1 bash "$scripts/plan.sh" create 'M10 · Ten' /dev/null)
case $out in *'dry run: gh api -X POST'*) ;; *) fail 'create takes M10 next to M1' "$out" ;; esac
# bash 3.2 runs an EXIT trap with $? at 0 when set -u stops a script. A copy of
# plan.sh gets a stop after its trap and runs with a finished from the
# environment. Two stops: an unbound variable, the case itself, and an exit 0,
# which gives the trap the $? of 0 of bash 3.2 on any bash. Each must exit
# non-zero, show that it reached the stop, and leave nothing in TMPDIR.
cp -R "$scripts" "$tmp/stopped"
for stop in unbound exit; do
  awk -v stop="$stop" '{ print } !/^[ \t]*#/ && /trap .* EXIT/ {
    print (stop == "exit" ? "echo stop-after-trap; exit 0" : ": \"$unbound_after_trap\"") }' "$scripts/plan.sh" >"$tmp/stopped/plan.sh"
  mark='stop-after-trap'
  [ "$stop" = exit ] || mark='unbound_after_trap: unbound variable'
  before=$(ls -A "$tmp")
  out=$(finished=1 bash "$tmp/stopped/plan.sh" create 'M10 · Ten' /dev/null 2>&1) && fail "create exits 0 after its $stop stop" "$out"
  case $out in *"$mark"*) ;; *) fail "create stops before its $stop stop" "$out" ;; esac
  check "create leaves nothing in TMPDIR after its $stop stop" "$before" "$(ls -A "$tmp")"
done
check 'rename refuses Later before it reads' 'refused: a milestone does not become Later: plan.sh later puts off one task at a time' \
  "$(bash "$scripts/plan.sh" rename NoSuch later 2>&1 || true)"
# due sends noon UTC, the same day in UTC and in the US time zones that
# GitHub keeps due dates in; none clears it.
out=$(DRY_RUN=1 bash "$scripts/plan.sh" due M1 2026-12-01)
check 'due sends noon UTC' "dry run: gh api -X PATCH repos/\{owner\}/\{repo\}/milestones/$(msno M1) -F due_on=2026-12-01T12:00:00Z --silent" "$out"
out=$(DRY_RUN=1 bash "$scripts/plan.sh" due M1 none)
check 'due none clears it' "dry run: gh api -X PATCH repos/\{owner\}/\{repo\}/milestones/$(msno M1) -F due_on=null --silent" "$out"
check 'due takes a day only' 2 "$(bash "$scripts/plan.sh" due M1 12/01/2026 >/dev/null 2>&1; echo $?)"
check 'due refuses a day that does not exist' 'plan.sh: 2026-02-30 is not a day' "$(bash "$scripts/plan.sh" due M1 2026-02-30 2>&1)"
check 'due takes February 29 of a leap year' 0 "$(DRY_RUN=1 bash "$scripts/plan.sh" due M1 2028-02-29 >/dev/null 2>&1; echo $?)"
check 'due refuses February 29 of 2100' 2 "$(bash "$scripts/plan.sh" due M1 2100-02-29 >/dev/null 2>&1; echo $?)"
# An open sub-issue with no milestone takes it from its parent, closed or not.
reset
put '11:-'
edit 11 ".parent = {number: 10, milestone: {number: $(msno M1)}, repository: {nameWithOwner: \"kalinichenko88/agent-skills\"}}"
check 'close counts a sub-issue in the milestone of its parent' 'refused: M1 · Stage 1 has 1 open issues: #11' \
  "$(bash "$scripts/plan.sh" close M1 2>&1 || true)"
# plan.sh later puts a task off, unless an issue outside Later waits on it:
# a task in Later is never offered, so that issue would wait for good.
reset
put '19 20 21 42:Later'
blocks 20 21
blocks 42 19
check 'later refuses a task that a blocked issue waits on' 'refused: these wait on it outside Later: #20' \
  "$(bash "$scripts/plan.sh" later 21 2>&1 || true)"
out=$(DRY_RUN=1 bash "$scripts/plan.sh" later 19)
case $out in *'dry run: gh issue edit 19 --milestone Later'*) ;; *) fail 'later moves a task that only Later waits on' "$out" ;; esac
check 'later on a task in Later' '#42 is in Later already' "$(bash "$scripts/plan.sh" later 42)"
reset
put '10 11'
edit 11 '.parent = {number: 10, milestone: null, repository: {nameWithOwner: "kalinichenko88/agent-skills"}}'
check 'later refuses a sub-issue whose parent waits on it' 'refused: these wait on it outside Later: #10' \
  "$(bash "$scripts/plan.sh" later 11 2>&1 || true)"
# A sub-issue with no milestone goes into Later with its parent.
reset
put '10 11:- 20'
edit 11 ".parent = {number: 10, milestone: {number: $(msno M1)}, repository: {nameWithOwner: \"kalinichenko88/agent-skills\"}}"
blocks 20 11
check 'later refuses a task whose sub-issue an issue waits on' 'refused: these wait on it outside Later: #20' \
  "$(bash "$scripts/plan.sh" later 10 2>&1 || true)"
# A wait through a task in Later counts too: #19 waits on #42, which waits on #50.
reset
mark M1
put '19 42:Later 50:M2'
blocks 19 42
blocks 42 50
check 'later refuses a task that an issue waits on through Later' 'refused: these wait on it outside Later: #19' \
  "$(bash "$scripts/plan.sh" later 50 2>&1 || true)"
reset
put '10:Later 11:- 20'
blocks 20 11
check 'sub refuses a child that goes into Later' 'refused: #11 goes into Later with #10, and these wait on it outside Later: #20' \
  "$(bash "$scripts/plan.sh" sub 10 11 2>&1 || true)"
# No Later milestone yet: it is made first.
reset
ms 'map(select(.title != "Later"))'
put '19'
out=$(DRY_RUN=1 bash "$scripts/plan.sh" later 19)
case $out in *'dry run: gh api -X POST'*'title=Later'*'dry run: gh issue edit 19 --milestone Later'*) ;;
  *) fail 'later makes the Later milestone first' "$out" ;;
esac
# A closed Later is opened again.
reset
jq '[.[] | select(.title == "Later") | .state = "closed"]' "$fixtures/milestones.json" >"$FAKE/milestones-closed.json"
ms 'map(select(.title != "Later"))'
put '19'
out=$(DRY_RUN=1 bash "$scripts/plan.sh" later 19)
case $out in *'dry run: gh api -X PATCH'*"milestones/$(msno Later)"*'state=open'*'dry run: gh issue edit 19 --milestone Later'*) ;;
  *) fail 'later opens a closed Later again' "$out" ;;
esac
# The issues of a closed Later are in Later when it opens again.
reset
jq '[.[] | select(.title == "Later") | .state = "closed"]' "$fixtures/milestones.json" >"$FAKE/milestones-closed.json"
ms 'map(select(.title != "Later"))'
put '19 5:Later'
blocks 5 19
out=$(DRY_RUN=1 bash "$scripts/plan.sh" later 19 2>&1 || true)
case $out in *'state=open'*'dry run: gh issue edit 19 --milestone Later'*) ;; *) fail 'later counts the issues of a closed Later as in Later' "$out" ;; esac
check 'usage names every subcommand' 11 "$(bash "$scripts/plan.sh" 2>&1 | grep -c 'plan.sh ' || true)"

# board.sh: a project found by title among the owner's projects, not linked
# yet, is linked, not created again.
reset
pages 3
jq '.projects[0].title = "agent-skills roadmap"' "$fixtures/project-list.json" >"$FAKE/project-list.json"
jq '.items[0].content = {number: 1, repository: "kalinichenko88/agent-skills", type: "Issue"}' "$fixtures/project-items.json" >"$FAKE/project-items.json"
out=$(DRY_RUN=1 bash "$scripts/board.sh")
check 'no create' 0 "$(grep -c 'project create' <<<"$out" || true)"
check 'links a project found by title' 'linked kalinichenko88/agent-skills' "$(grep '^linked ' <<<"$out")"
check 'adds only the missing issues' 'issues to add: 2' "$(grep '^issues to add: ' <<<"$out")"
check 'both views missing' "$(printf 'view Unassigned: missing\nview By milestone: missing')" "$(grep '^view ' <<<"$out")"
check 'the filter of Unassigned' 1 "$(grep -c 'is:issue\\ is:open\\ no:assignee\\ -milestone:Later' <<<"$out" || true)"
check 'the manual steps' 1 "$(grep -c '^Two settings the API cannot make. Open ' <<<"$out" || true)"
# A linked project of that title is not linked again; views there are not
# made again.
jq '.data.repository.projectsV2.nodes = [{number: 6, title: "agent-skills roadmap", url: "https://github.com/users/kalinichenko88/projects/6", closed: false}]' \
  "$fixtures/projects-linked.json" >"$FAKE/projects-linked.json"
jq '.data.node.views.nodes = [{id: "PVV_1", name: "Unassigned", filter: "is:open"}, {id: "PVV_2", name: "By milestone", filter: "is:open"}]' \
  "$fixtures/project-views.json" >"$FAKE/project-views.json"
out=$(DRY_RUN=1 bash "$scripts/board.sh")
check 'a linked project is not linked again' 0 "$(grep -c '^linked ' <<<"$out" || true)"
check 'views there' "$(printf 'view Unassigned: there\nview By milestone: there')" "$(grep '^view ' <<<"$out")"
# A view whose filter was never set, as after a failed run, gets it.
jq '.data.node.views.nodes = [{id: "PVV_1", name: "Unassigned", filter: null}, {id: "PVV_2", name: "By milestone", filter: "is:open"}]' \
  "$fixtures/project-views.json" >"$FAKE/project-views.json"
out=$(DRY_RUN=1 bash "$scripts/board.sh")
check 'a view without its filter' "$(printf 'view Unassigned: no filter\nview By milestone: there')" "$(grep '^view ' <<<"$out")"
check 'the filter goes to that view' 1 "$(grep -c 'view=PVV_1.*no:assignee' <<<"$out" || true)"
# None: create and link it, in a dry run.
reset
out=$(DRY_RUN=1 bash "$scripts/board.sh")
case $out in *'dry run: gh project create --owner kalinichenko88 --title agent-skills\ roadmap'*'dry run: gh project link'*'no project yet'*) ;;
  *) fail 'creates and links the project' "$out" ;;
esac
# A failed create stops with the reason.
reset
FAKE_FAIL='project create' bash "$scripts/board.sh" >"$tmp/out" 2>&1 && fail 'board.sh exits 0 when create fails'
grep -q '^cannot create a project under kalinichenko88: ' "$tmp/out" || fail 'board.sh names the failed create' "$(cat "$tmp/out")"

# gh's --jq runs gojq, whose Go regexp takes (?<name>) only from Go 1.22.
grep -n '(?<' "$scripts"/*.sh && fail 'a named capture in a gh --jq filter'
echo 'roadmap_scripts_test: ok'
