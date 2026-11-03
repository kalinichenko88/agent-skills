#!/usr/bin/env bash
# Runs the checks of tests/scenarios_eval.sh on recorded runs, with no model.
# tests/fixtures/scenarios/take-in/ holds the events, the tracker and the
# branches of one probe run of each case, 2026-11-03. In the run of the free
# task, no text with the title of #91 comes before the branch, but think lines
# do: the log cannot show whether a message told the gist (#206), so that
# item gives SKIP, and every other item passes. A copy with one change to a
# recorded run flips the item that the change breaks or fixes. Each scenario
# that the checks name is a heading of scenarios/github/take-in.md.

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
[ "$(grep -v '^PASS ' <<<"$out")" = 'SKIP A free task: the first message about #91 tells its gist, before any change: only a think line comes before the change' ] ||
  fail 'the recorded runs do not skip only the gist of the free task' "$out"

while IFS= read -r scenario; do
  grep -qxF "## $scenario" "$root/scenarios/github/take-in.md" || fail "no scenario named $scenario" "$out"
done < <(sed -E 's/^(PASS|FAIL|SKIP) ([^:]*):.*/\2/' <<<"$out" | sort -u)

# flips <case> <the item, as the checks print it>: the copy in $tmp/<n>
# changes the verdict of that item, and of no other item.
n=0
copy() {
  n=$((n + 1))
  cp -R "$fixtures" "$tmp/$n"
}
flips() {
  local was now
  was=$(grep -F ": $2" <<<"$out" | grep -F "$(scenario "$1")")
  now=$(checks "$tmp/$n" | grep -F ": $2" | grep -F "$(scenario "$1")")
  [ "${was%% *}" != "${now%% *}" ] || fail "the change of copy $n does not flip: $2" "$now"
  [ "$(checks "$tmp/$n" | grep -vxF "$now" | sort)" = "$(grep -vxF "$was" <<<"$out" | sort)" ] ||
    fail "the change of copy $n flips another item too" "$(checks "$tmp/$n")"
}
scenario() { case $1 in free) echo 'A free task' ;; other) echo 'A task that another person is assigned to' ;; down) echo 'The tracker does not answer' ;; esac; }
state() { jq "$2" "$tmp/$n/$1.state.json" >"$tmp/state" && mv "$tmp/state" "$tmp/$n/$1.state.json"; }

# The gist told first, before the branch: PASS.
copy
{ printf 'text\t#91: README: the install command says npm instal. The README has a wrong command.\n'
  cat "$fixtures/free.events"; } >"$tmp/$n/free.events"
flips free 'the first message about #91 tells its gist, before any change'

# No gist and no think line before the branch: FAIL.
copy
grep -v '^think' "$fixtures/free.events" >"$tmp/$n/free.events"
flips free 'the first message about #91 tells its gist, before any change'

# The person added to another person's task.
copy
state other '.issues[0].assignees += ["kim"]'
flips other 'never: the assignees of #91 change'

# A write to the tracker on another person's task.
copy
printf 'Bash\tgh issue edit 91 --add-assignee @me\n' >>"$tmp/$n/other.events"
flips other 'the run waits: no change'

# An edit in the shell on another person's task.
copy
printf "Bash\tsed -i '' s/instal/install/ README.md\n" >>"$tmp/$n/other.events"
flips other 'the run waits: no change'

# A changed file in the workspace, by a call that the log does not show.
copy
{ echo ' M README.md'; cat "$fixtures/other.workspace"; } >"$tmp/$n/other.workspace"
flips other 'the run waits: no change'

# A message about #91 before its gist, on another person's task.
copy
{ head -n 4 "$fixtures/other.events"
  printf 'text\t#91 belongs to rivera, so I stop.\n'
  tail -n +5 "$fixtures/other.events"; } >"$tmp/$n/other.events"
flips other 'the first message about #91 tells its gist'

# A branch of the free task that is not made from main.
copy
sed -i.bak 's#^docs/91-fix-install-command$#&, not from main#' "$tmp/$n/free.branches"
flips free 'that branch is made from the default branch'

# A second linked branch on the free task.
copy
state free '.issues[0].linked += ["fix/91-other"]'
flips free 'never: #91 gets a second linked branch'

# No branch linked to the free task.
copy
state free '.issues[0].linked = []'
flips free 'that branch is linked to #91'

# A title that the run could not read, told when the tracker is down.
copy
printf 'text\tREADME: the install command says npm instal\n' >>"$tmp/$n/down.events"
flips down 'never: a gist of #91 that the run did not read'

# No error of the tracker told.
copy
sed -i.bak 's/502/5xx/g' "$tmp/$n/down.events"
flips down 'the person is told the error of the tracker'

echo 'scenarios_checks_test: ok'
