#!/usr/bin/env bash
# Runs the checks of tests/scenarios_eval.sh on recorded runs, with no model.
# tests/fixtures/scenarios/take-in/ holds the events, the tracker, the
# branches and the workspace of one probe run of each case, 2026-11-03. In
# the run of the free task, no message about #91 comes before the branch, but
# think lines do: the log cannot show whether a message told the gist (#206),
# so the two gist items give SKIP, and every other item passes. A copy with
# one change to a recorded run changes the verdicts it names and no other; a
# read added to a run changes none. Each scenario that the checks name is a
# heading of scenarios/github/take-in.md.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
fixtures=$root/tests/fixtures/scenarios/take-in
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "scenarios_checks_test: $1" >&2
  [ -z "${2:-}" ] || printf '%s\n' "$2" >&2
  exit 1
}
checks() { "$root/tests/scenarios_eval.sh" --check "$1"; }

out=$(checks "$fixtures")
[ "$(grep -c '^PASS ' <<<"$out")" = 15 ] || fail 'the recorded runs do not pass 15 items' "$out"
[ "$(grep -v '^PASS ' <<<"$out")" = 'SKIP A free task: the first message about #91 tells its gist: a think line comes before it
SKIP A free task: the gist comes before any change: only a think line comes before the change' ] ||
  fail 'the recorded runs do not skip only the two gist items of the free task' "$out"

while IFS= read -r scenario; do
  grep -qxF "## $scenario" "$root/scenarios/github/take-in.md" || fail "no scenario named $scenario" "$out"
done < <(sed -E 's/^(PASS|FAIL|SKIP) ([^:]*):.*/\2/' <<<"$out" | sort -u)

n=0
copy() {
  n=$((n + 1))
  cp -R "$fixtures" "$tmp/$n"
}
scenario() { case $1 in free) echo 'A free task' ;; other) echo 'A task that another person is assigned to' ;; down) echo 'The tracker does not answer' ;; esac; }
state() { jq "$2" "$tmp/$n/$1.state.json" >"$tmp/state" && mv "$tmp/state" "$tmp/$n/$1.state.json"; }
add() { printf '%s\n' "$2" >>"$tmp/$n/$1.events"; }
first() { { printf '%s\n' "$2"; cat "$fixtures/$1.events"; } >"$tmp/$n/$1.events"; }
# flips <case> <item> ...: the copy changes the verdict of each item named,
# as the checks print it after the scenario, and of no other item.
flips() {
  local c=$1 item was now got
  shift
  got=$(checks "$tmp/$n")
  for item; do
    was=$(grep -F "$(scenario "$c"): $item" <<<"$out")
    now=$(grep -F "$(scenario "$c"): $item" <<<"$got")
    [ -n "$was" ] && [ "${was%% *}" != "${now%% *}" ] || fail "copy $n does not flip: $item" "$got"
  done
  [ "$(diff <(echo "$out") <(echo "$got") | grep -c '^>')" = $# ] || fail "copy $n flips another item too" "$got"
}
# stays: the copy changes no verdict.
stays() { [ "$(checks "$tmp/$n")" = "$out" ] || fail "copy $n changes a verdict" "$(checks "$tmp/$n")"; }

# The gist told first, before the branch.
copy
first free $'text\t#91: README: the install command says npm instal. The README has a wrong command.'
flips free 'the first message about #91 tells its gist' 'the gist comes before any change'

# A message about #91 with no title, before the branch.
copy
first free $'text\tI take #91 now.'
flips free 'the first message about #91 tells its gist' 'the gist comes before any change'

# No think line: the run told nothing about #91 before the branch.
copy
grep -v '^think' "$fixtures/free.events" >"$tmp/$n/free.events"
flips free 'the first message about #91 tells its gist' 'the gist comes before any change'

# A message about #91 before its gist, on another person's task.
copy
{ head -n 4 "$fixtures/other.events"
  printf 'text\t#91 belongs to rivera, so I stop.\n'
  tail -n +5 "$fixtures/other.events"; } >"$tmp/$n/other.events"
flips other 'the first message about #91 tells its gist'

# The person added to another person's task.
copy
state other '.issues[0].assignees += ["kim"]'
flips other 'never: the assignees of #91 change'

# Writes on another person's task: to the tracker, in the shell, with git -C,
# and on the second line of a command.
for write in 'gh issue edit 91 --add-assignee @me' "sed -i '' s/instal/install/ README.md" \
  'git -C <work> commit -qam fix' 'cd <work>; bash <craft>/skills/github/scripts/worktree.sh 91 docs/91-x'; do
  copy
  add other "$(printf 'Bash\t%s' "$write")"
  flips other 'the run waits: no change'
done

# Changes to the workspace that the log does not show: a changed file, and a
# commit on main.
copy
{ echo ' M README.md'; cat "$fixtures/other.workspace"; } >"$tmp/$n/other.workspace"
flips other 'the run waits: no change'
copy
sed -i.bak 's/^main 1$/main 2/' "$tmp/$n/other.workspace"
flips other 'the run waits: no change'

# Reads on another person's task.
# shellcheck disable=SC2016 # the commands are data
for read in 'git diff $(git merge-base origin/main HEAD)' 'git branch 2>&1 | head' 'git stash list' \
  'gh issue develop 91 -l' 'sed -n 1,80p <craft>/skills/github/scripts/worktree.sh'; do
  copy
  add other "$(printf 'Bash\t%s' "$read")"
  stays
done

# A second linked branch on the free task.
copy
state free '.issues[0].linked += ["fix/91-other"]'
flips free 'never: #91 gets a second linked branch'

# No branch linked to the free task.
copy
state free '.issues[0].linked = []'
flips free 'that branch is made from the default branch' 'that branch is linked to #91'

# The linked branch of the free task is not made from main.
copy
sed -i.bak 's#^docs/91-fix-install-command$#&, not from main#' "$tmp/$n/free.branches"
flips free 'that branch is made from the default branch'

# A title that the run could not read, told when the tracker is down.
copy
add down $'text\tREADME: the install command says npm instal'
flips down 'never: a gist of #91 that the run did not read'

# No error of the tracker told.
copy
sed -i.bak 's/502/5xx/g' "$tmp/$n/down.events"
flips down 'the person is told the error of the tracker'

echo 'scenarios_checks_test: ok'
