#!/usr/bin/env bash
# Sends the citations job of skills/github/scout.md to one recorded case, with
# the prompt that *Finishing* of skills/github/SKILL.md gives it, at model
# haiku. The case is PR #217 of this repository: its merge commit is the tree,
# and the `Decision` lines come from its description. The scout's file holds
# the bodies of two issues that were open at its merge, as they were then, in
# tests/fixtures/github/scout-<n>.md:
#
# - #117 says that rules.md "has 337 left, so the second option below fits
#   too". #217 added a section to rules.md and left 75. #117 cites no line of
#   rules.md, and nobody corrected it after the merge.
# - #179 cites docs/ARCHITECTURE.md:186, which #217 moved to :189. No decision
#   makes a sentence of it false.
#
# It prints each report, and exits 1 when a report gives no sentence of #117
# as false by a decision, or gives one of #179.
#
# It calls the model, so it costs tokens and is not part of `make check`: run
# it by hand after a change to the citations job of scout.md or to *Finishing*.
# It runs with this machine's other plugins and settings, and needs the history
# of this checkout down to #217.
#
# Usage: tests/github_scout_eval.sh [runs, default 3]

# shellcheck disable=SC2016 # the backticks are Markdown's
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
runs=${1:-3}
[ "$#" -le 1 ] && [ "$runs" -ge 1 ] 2>/dev/null || { echo "usage: $0 [runs, at least 1]" >&2; exit 2; }
merge=f8fa244a39aca5f1aeecfb85748b717c4ba6200c
git -C "$root" cat-file -e "$merge^{commit}" 2>/dev/null || { echo "$0: this checkout has no commit $merge (#217)" >&2; exit 2; }
logs=$(mktemp -d)
fixtures=$root/tests/fixtures/github

fixture() {
  local d=$1
  mkdir -p "$d/tree"
  git -C "$root" archive "$merge" | tar -x -C "$d/tree"
  git -C "$d/tree" init -q -b main
  git -C "$d/tree" config user.name eval
  git -C "$d/tree" config user.email eval@example.com
  git -C "$d/tree" add -A
  git -C "$d/tree" commit -qm "feat(product): add a skeptic that asks whether a task is worth doing before the work (#217)"
  {
    printf '%s\n' '# collect.sh filing in kalinichenko88/craft-skills' '' '== Open issues' ''
    printf '%s\n' "#179 $title179 [debt] open" "#117 $title117 [bug] open" ''
    printf '%s\n' '== Search: rules.md' '' "#117 $title117 [bug] open" ''
    printf '%s\n' '== Search: docs/ARCHITECTURE.md' '' "#179 $title179 [debt] open" ''
    printf '%s\n' '== Bodies' '' "==> #179 $title179 [debt] open" 'status: free' 'also: 0' ''
    cat "$fixtures/scout-179.md"
    printf '%s\n' '' "==> #117 $title117 [bug] open" 'status: free' 'also: 0' ''
    cat "$fixtures/scout-117.md"
    printf '%s\n' '' '== end: 2 entries'
  } >"$d/collect.txt"
}
title117="rules: review-loop replaces the final review of subagent-driven-development, but the deferred findings and finishing-a-development-branch around it have no place"
title179="tests: github_scripts_test.sh has 551 lines, past the I-8 limit of 330, and no issue covers its split"

# The installed copy of the plugin is turned off, so the rules come from this
# checkout. run <run>: the report goes to <run>.txt. The Decision lines are
# the ones *Finishing* takes from the description of #217.
run() {
  local work=$logs/$1 prompt
  fixture "$work"
  prompt="Read $root/skills/github/scout.md and do what it says.
Job: citations.
Tree: $work/tree
Decision 1: Add the product skill: a skeptic that checks whether a task is worth doing before the work, with a Fable and Codex panel and a store of product decisions in docs/PRODUCT.md and docs/pdr/.
Decision 2: The start of a feature in the architecture skill keeps Problem and Touches; whether to build is the product skill's report.
Decision 3: review-loop checks the worth before round 1 (Worth first), and a finding that shows a capability gives nothing goes to the person, not to a rebuild.
Decision 4: rules.md gets the section \"Worth before work\", and now has 9,931 of the 10,000 characters that tests/rules_test.sh allows.
Decision 5: tests/review_loop_eval.sh marks the product skill's reader as a prompt of kind P.
File: $work/collect.txt
Collector: bash $root/skills/github/scripts/collect.sh"
  (cd "$work/tree" && claude -p --model haiku --output-format json \
    --settings '{"enabledPlugins":{"craft@kalinichenko":false,"kalinichenko@kalinichenko":false}}' \
    --plugin-dir "$root" --dangerously-skip-permissions "$prompt") >"$work.json" 2>&1 || true
  # The text of a session that ends in an error is no report.
  jq -r 'select(.is_error != true) | .result // empty' "$work.json" >"$work.txt" 2>/dev/null || true
}

for i in $(seq "$runs"); do run "$i" & done
wait

# falsified <n>: the count of lines in the block of issue #<n> that give a
# quoted sentence as false by a numbered decision. A block starts at a line
# with the issue's number and words of its title, in any markup: runs wrote
# "PR-less issue #117 …", and the title without its "rules: ".
falsified() {
  awk -v n="$1" '
    index($0, "#117") && index($0, "review-loop replaces") { cur = 117 }
    index($0, "#179") && index($0, "has 551 lines") { cur = 179 }
    cur == n && tolower($0) ~ /false/ && tolower($0) ~ /decision[^0-9]*[0-9]/ && /"/ { c++ }
    END { print c + 0 }' <<<"$report"
}
failed=0
for i in $(seq "$runs"); do
  report=$(cat "$logs/$i.txt" 2>/dev/null || true)
  missed=
  [ "$(falsified 117)" -ge 1 ] || missed="$missed; no false sentence of #117"
  [ "$(falsified 179)" -eq 0 ] || missed="$missed; a false sentence of #179"
  if [ -z "$missed" ]; then verdict=pass; else verdict="FAIL${missed}"; failed=1; fi
  echo "== $i: $verdict"
  echo "${report:-no report}"
done
echo "Logs: $logs"
exit "$failed"
