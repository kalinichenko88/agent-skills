#!/bin/bash
# Writes the plan to GitHub: milestones, the current mark, blocked-by links
# and sub-issues.
#
#   plan.sh create <title> <description-file>
#   plan.sh describe <milestone> <description-file>
#   plan.sh close <milestone>
#   plan.sh current <milestone>
#   plan.sh not-current <milestone>
#   plan.sh block <issue> <blocker>
#   plan.sh unblock <issue> <blocker>
#   plan.sh sub <parent> <child>
#   plan.sh later <issue>
#
# A milestone is M1, Later or a whole title. A milestone is current when a
# line of its description reads Current.; describe keeps that line. It refuses
# what would break the plan, prints why and exits 1, and writes nothing: a
# second milestone of one title, closing a milestone with open issues, Later
# as current, and a link that makes a cycle, also through the blockers that a
# sub-issue takes from its parent. later puts a task off into the Later
# milestone, and makes that milestone when there is none; it refuses when an
# open issue outside Later waits on the task, because a task in Later is never
# offered. Putting an issue into another milestone needs no check:
# gh issue edit <n> --milestone '<title>'.
#
# DRY_RUN=1 prints the commands that would write, and runs none. It keeps the
# new description in the file that the printed command names.
# Needs only bash, gh and awk.

# shellcheck disable=SC2016 # the single-quoted $ are GraphQL's
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: plan.sh create <title> <description-file>
       plan.sh describe <milestone> <description-file>
       plan.sh close <milestone>
       plan.sh current <milestone>
       plan.sh not-current <milestone>
       plan.sh block <issue> <blocker>
       plan.sh unblock <issue> <blocker>
       plan.sh sub <parent> <child>
       plan.sh later <issue>
EOF
  exit 2
}
run() { if [ "${DRY_RUN:-}" = 1 ]; then echo "dry run:$(printf ' %q' "$@")"; else "$@"; fi; }
say() { [ "${DRY_RUN:-}" = 1 ] || echo "$1"; }
refuse() {
  echo "refused: $1"
  exit 1
}
dir=$(dirname "$0")

# Sets n, title and old, the description, of an open milestone.
milestone() {
  local found
  found=$(bash "$dir/read.sh" milestone "$1")
  n=${found%%$'\t'*} title=${found#*$'\t'}
  old=$(gh api "repos/{owner}/{repo}/milestones/$n" --jq '.description // ""')
}
# A new description in a file of its own, without carriage returns and
# trailing blank lines.
newfile() {
  file=$(mktemp "${TMPDIR:-/tmp}/milestone.XXXXXX")
  [ "${DRY_RUN:-}" = 1 ] || trap 'rm -f "$file"' EXIT
}
trimmed() { awk '{ sub(/\r$/, ""); l[++n] = $0 } END { while (n && l[n] ~ /^[ \t]*$/) n--; for (i = 1; i <= n; i++) print l[i] }'; }
unmarked() { awk '{ s = $0; sub(/\r$/, "", s); gsub(/^[ \t]+|[ \t]+$/, "", s) } s != "Current."' | trimmed; }
marked() { awk '{ sub(/\r$/, ""); gsub(/^[ \t]+|[ \t]+$/, "") } $0 == "Current." { f = 1 } END { exit !f }' <<<"$old"; }
# Writes the file as the milestone's description.
describe() { run gh api -X PATCH "repos/{owner}/{repo}/milestones/$n" -F description=@"$file" --silent; }
issue() {
  [[ ${1#\#} =~ ^[0-9]+$ ]] || usage
  echo "${1#\#}"
}
# Sets ida and idb, the node ids of issues a and b.
ids() {
  local got
  got=$(gh api graphql -F owner='{owner}' -F name='{repo}' -F a="$a" -F b="$b" -f query='
    query($owner: String!, $name: String!, $a: Int!, $b: Int!) {
      repository(owner: $owner, name: $name) { a: issue(number: $a) { id } b: issue(number: $b) { id } }
    }' --jq '.data.repository | "\(.a.id) \(.b.id)"')
  ida=${got% *} idb=${got#* }
}
link() {
  a=$(issue "$1")
  b=$(issue "$2")
  [ "$a" != "$b" ] || refuse 'an issue cannot wait on itself'
  if [ "$act" != unblock ]; then
    cycle=$(bash "$dir/read.sh" issues | awk -F'\t' -v act="$act" -v a="$a" -v b="$b" -f "$dir/graph.awk" -f "$dir/cycle.awk")
    [ -z "$cycle" ] || refuse "it makes a cycle: $cycle"
  fi
  ids
}

[ $# -ge 1 ] || usage
act=$1
case $act in
  create)
    [ $# -eq 3 ] || usage
    title=$2
    list=$(bash "$dir/read.sh" milestones)
    if awk -F'\t' -v t="$title" '$1 == "ms" && tolower($8) == tolower(t) { f = 1 } END { exit !f }' <<<"$list"; then
      refuse "$title exists"
    fi
    newfile
    trimmed <"$3" >"$file"
    run gh api -X POST 'repos/{owner}/{repo}/milestones' -f title="$title" -F description=@"$file" --silent
    say "created $title"
    ;;
  describe)
    [ $# -eq 3 ] || usage
    milestone "$2"
    newfile
    if marked; then
      { unmarked <"$3"; echo; echo Current.; } | awk 'NR > 1 || $0 != ""' >"$file"
    else
      unmarked <"$3" >"$file"
    fi
    describe
    say "described $title"
    ;;
  close)
    [ $# -eq 2 ] || usage
    milestone "$2"
    open=$(bash "$dir/read.sh" issues | awk -F'\t' -v m="$n" '$1 == "is" && $3 == m { print $2 }' | sort -n | awk '{ s = s (NR > 1 ? ", " : "") "#" $0 } END { if (NR) print NR " open issues: " s }')
    [ -z "$open" ] || refuse "$title has $open"
    run gh api -X PATCH "repos/{owner}/{repo}/milestones/$n" -f state=closed --silent
    say "closed $title"
    ;;
  current)
    [ $# -eq 2 ] || usage
    milestone "$2"
    [ "$(tr '[:upper:]' '[:lower:]' <<<"$title")" != later ] || refuse 'Later is never current'
    if marked; then
      echo "$title is current already"
      exit 0
    fi
    newfile
    { trimmed <<<"$old"; echo; echo Current.; } | awk 'NR > 1 || $0 != ""' >"$file"
    describe
    say "marked $title current"
    ;;
  not-current)
    [ $# -eq 2 ] || usage
    milestone "$2"
    if ! marked; then
      echo "$title is not marked current"
      exit 0
    fi
    newfile
    unmarked <<<"$old" >"$file"
    describe
    say "unmarked $title"
    ;;
  block | unblock | sub)
    [ $# -eq 3 ] || usage
    link "$2" "$3"
    case $act in
      block)
        run gh api graphql --silent -f i="$ida" -f b="$idb" -f query='mutation($i: ID!, $b: ID!) {
          addBlockedBy(input: {issueId: $i, blockingIssueId: $b}) { issue { number } } }'
        say "#$a is blocked by #$b"
        ;;
      unblock)
        run gh api graphql --silent -f i="$ida" -f b="$idb" -f query='mutation($i: ID!, $b: ID!) {
          removeBlockedBy(input: {issueId: $i, blockingIssueId: $b}) { issue { number } } }'
        say "#$a is no longer blocked by #$b"
        ;;
      sub)
        run gh api graphql --silent -f i="$ida" -f b="$idb" -f query='mutation($i: ID!, $b: ID!) {
          addSubIssue(input: {issueId: $i, subIssueId: $b}) { issue { number } } }'
        say "#$b is a sub-issue of #$a"
        ;;
    esac
    ;;
  later)
    [ $# -eq 2 ] || usage
    a=$(issue "$2")
    list=$(bash "$dir/read.sh" milestones)
    issues=$(bash "$dir/read.sh" issues)
    later=$(awk -F'\t' '$1 == "ms" && $5 == 1 { print $2 "\t" $8; exit }' <<<"$list")
    own=$(awk -F'\t' -v n="$a" '$1 == "is" && $2 == n { print $3 }' <<<"$issues")
    [ -n "$own" ] || refuse "#$a is not an open issue"
    if [ -n "$later" ] && [ "$own" = "${later%%$'\t'*}" ]; then
      echo "#$a is in Later already"
      exit 0
    fi
    waiting=$(printf '%s\n%s\n' "$list" "$issues" | awk -F'\t' -v n="$a" -f "$dir/graph.awk" -f "$dir/later.awk" |
      sort -n | awk '{ s = s (NR > 1 ? ", " : "") "#" $0 } END { print s }')
    [ -z "$waiting" ] || refuse "these wait on it outside Later: $waiting"
    if [ -z "$later" ]; then
      run gh api -X POST 'repos/{owner}/{repo}/milestones' -f title=Later -f description='What is wanted but not planned.' --silent
      later=$'0\tLater'
    fi
    run gh issue edit "$a" --milestone "${later#*$'\t'}"
    say "#$a is in Later"
    ;;
  *) usage ;;
esac
