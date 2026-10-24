#!/usr/bin/env bash
# Writes the plan to GitHub: milestones, the current mark, blocked-by links
# and sub-issues.
#
#   plan.sh create <title> <description-file>
#   plan.sh describe <milestone> <description-file>
#   plan.sh rename <milestone> <title>
#   plan.sh due <milestone> <YYYY-MM-DD|none>
#   plan.sh close <milestone>
#   plan.sh current <milestone>
#   plan.sh not-current <milestone>
#   plan.sh block <issue> <blocker>
#   plan.sh unblock <issue> <blocker>
#   plan.sh sub <parent> <child>
#   plan.sh later <issue>
#
# A milestone is M1, Later or a whole title. A milestone is current when a
# line of its description reads Current.; describe keeps that line, and rename
# keeps the description. due none clears the due date. It refuses what would
# break the plan, prints why and exits 1, and writes nothing: a second
# milestone of one title, a rename to Later, which would put off its tasks
# without the check of later, closing a milestone with open issues, Later as
# current, and a link that makes a cycle, also through the blockers that a
# sub-issue takes from its parent. later puts a task off into the Later
# milestone, and opens it again when it is closed, or makes it when there is
# none. It refuses when an open issue outside Later waits on the task through
# any chain, or on a sub-issue of it with no milestone of its own: a task in Later that an issue
# outside Later waits on is still offered, so it would not be put off. sub
# refuses the same for a child that goes into Later with its parent. Putting an issue into another milestone needs no check:
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
       plan.sh rename <milestone> <title>
       plan.sh due <milestone> <YYYY-MM-DD|none>
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
# Exits 0 when an open milestone in $list, other than number $2, has the
# title $1 in any case. Through ENVIRON, not -v, which would read a backslash
# in the title as an escape.
exists() { T=$1 N=${2:-} awk -F'\t' '$1 == "ms" && $2 != ENVIRON["N"] && tolower($6) == tolower(ENVIRON["T"]) { f = 1 } END { exit !f }' <<<"$list"; }
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
    issues=$(bash "$dir/read.sh" issues)
    cycle=$(awk -F'\t' -v act="$act" -v a="$a" -v b="$b" -f "$dir/graph.awk" -f "$dir/cycle.awk" <<<"$issues")
    [ -z "$cycle" ] || refuse "it makes a cycle: $cycle"
  fi
  if [ "$act" = sub ]; then
    list=$(bash "$dir/read.sh" milestones)
    waiting=$(waiting "$b" "$a")
    [ -z "$waiting" ] || refuse "#$b goes into Later with #$a, and these wait on it outside Later: $waiting"
  fi
  ids
}
# The open issues outside Later that would wait on issue $1 in Later, as
# #20, #21, from $list and $issues; $2 is its new parent.
waiting() {
  printf '%s\n%s\n' "$list" "$issues" | awk -F'\t' -v n="$1" -v parent="${2:-}" -f "$dir/graph.awk" -f "$dir/later.awk" |
    sort -n | awk '{ s = s (NR > 1 ? ", " : "") "#" $0 } END { print s }'
}

[ $# -ge 1 ] || usage
act=$1
case $act in
  create)
    [ $# -eq 3 ] || usage
    title=$2
    list=$(bash "$dir/read.sh" milestones)
    ! exists "$title" || refuse "$title exists"
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
  rename)
    [ $# -eq 3 ] || usage
    milestone "$2"
    [ "$(tr '[:upper:]' '[:lower:]' <<<"$3")" != later ] || refuse 'a milestone does not become Later: plan.sh later puts off one task at a time'
    list=$(bash "$dir/read.sh" milestones)
    ! exists "$3" "$n" || refuse "$3 exists"
    run gh api -X PATCH "repos/{owner}/{repo}/milestones/$n" -f title="$3" --silent
    say "renamed $title to $3"
    ;;
  due)
    [ $# -eq 3 ] || usage
    # GitHub keeps a due date as a midnight: in UTC now, in a US time zone in
    # older milestones. Noon UTC is the same day in each.
    case $3 in
      none) due=null ;;
      [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) due=${3}T12:00:00Z ;;
      *) usage ;;
    esac
    milestone "$2"
    run gh api -X PATCH "repos/{owner}/{repo}/milestones/$n" -F due_on="$due" --silent
    if [ "$3" = none ]; then say "$title has no due date"; else say "$title is due $3"; fi
    ;;
  close)
    [ $# -eq 2 ] || usage
    milestone "$2"
    list=$(bash "$dir/read.sh" milestones)
    issues=$(bash "$dir/read.sh" issues)
    # A sub-issue with no milestone counts in its parent's.
    open=$(printf '%s\n%s\n' "$list" "$issues" |
      awk -F'\t' -v m="$n" -f "$dir/graph.awk" -f <(echo 'END { for (i = 1; i <= isn; i++) if (ems(islist[i]) == m) print islist[i] }') |
      sort -n | awk '{ s = s (NR > 1 ? ", " : "") "#" $0 } END { if (NR) print NR " open issues: " s }')
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
      block) call='addBlockedBy(input: {issueId: $i, blockingIssueId: $b})' msg="#$a is blocked by #$b" ;;
      unblock) call='removeBlockedBy(input: {issueId: $i, blockingIssueId: $b})' msg="#$a is no longer blocked by #$b" ;;
      sub) call='addSubIssue(input: {issueId: $i, subIssueId: $b})' msg="#$b is a sub-issue of #$a" ;;
    esac
    run gh api graphql --silent -f i="$ida" -f b="$idb" -f query="mutation(\$i: ID!, \$b: ID!) { $call { issue { number } } }"
    say "$msg"
    ;;
  later)
    [ $# -eq 2 ] || usage
    a=$(issue "$2")
    list=$(bash "$dir/read.sh" milestones)
    issues=$(bash "$dir/read.sh" issues)
    later=$(awk -F'\t' '$1 == "ms" && $5 == 1 { print $2 "\t" $6; exit }' <<<"$list")
    # No open Later: a closed one opens again. Its open issues go back into
    # Later with it, so the check counts them as in Later.
    closed=''
    if [ -z "$later" ]; then
      closed=$(gh api 'repos/{owner}/{repo}/milestones?state=closed&per_page=100' --paginate \
        --jq '.[] | select(.title | ascii_downcase == "later") | "\(.number)\t\(.title)"' | awk 'NR == 1')
      later=$closed
      [ -z "$closed" ] || list=$list$'\n'"ms	${closed%%$'\t'*}	1000000000	0	1	${closed#*$'\t'}"
    fi
    own=$(awk -F'\t' -v n="$a" '$1 == "is" && $2 == n { print $3 }' <<<"$issues")
    [ -n "$own" ] || refuse "#$a is not an open issue"
    if [ -z "$closed" ] && [ -n "$later" ] && [ "$own" = "${later%%$'\t'*}" ]; then
      echo "#$a is in Later already"
      exit 0
    fi
    waiting=$(waiting "$a")
    [ -z "$waiting" ] || refuse "these wait on it outside Later: $waiting"
    if [ -n "$closed" ]; then
      run gh api -X PATCH "repos/{owner}/{repo}/milestones/${closed%%$'\t'*}" -f state=open --silent
    elif [ -z "$later" ]; then
      run gh api -X POST 'repos/{owner}/{repo}/milestones' -f title=Later -f description='What is wanted but not planned.' --silent
      later=$'0\tLater'
    fi
    run gh issue edit "$a" --milestone "${later#*$'\t'}"
    say "#$a is in Later"
    ;;
  *) usage ;;
esac
