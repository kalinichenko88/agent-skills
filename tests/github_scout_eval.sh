#!/usr/bin/env bash
# Sends the citations job of skills/github/scout.md to one recorded case, with
# the prompt that *Finishing* of skills/github/SKILL.md gives it, at model
# haiku. The case is PR #217 of this repository: its merge commit is the tree,
# and the `Decision` lines come from its description. The scout's file holds
# the entries of two issues that were open at its merge, with the body and the
# comments they had then, in tests/fixtures/github/scout-<n>.md:
#
# - #117 says that rules.md "has 337 left, so the second option below fits
#   too". #217 added a section to rules.md, which then had 9,925 of the 10,000
#   characters: its description says 9,931, and *Finishing* counts again in
#   the merged code. #117 cites no line of rules.md, and nobody corrected it
#   after the merge.
# - #179 cites docs/ARCHITECTURE.md:186, which #217 moved to :189. No decision
#   makes a sentence of it false.
#
# It prints each report, and exits 1 when a report does not give the body's
# sentence "has 337 left" of #117 as false by a decision, gives a false
# sentence of #179, or does not give :186 of #179 as moved to :189.
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
title117="rules: review-loop replaces the final review of subagent-driven-development, but the deferred findings and finishing-a-development-branch around it have no place"
title179="tests: github_scripts_test.sh has 551 lines, past the I-8 limit of 330, and no issue covers its split"

# The runs only read the tree, so they share it. It is a repository of its own
# because the scout reads it with git ls-files and git grep.
tree=$logs/tree
mkdir -p "$tree"
git -C "$root" archive "$merge" | tar -x -C "$tree"
git -C "$tree" init -q -b main
git -C "$tree" config user.name eval
git -C "$tree" config user.email eval@example.com
git -C "$tree" add -A
git -C "$tree" commit -qm "feat(product): add a skeptic that asks whether a task is worth doing before the work (#217)"
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
} >"$logs/collect.txt"

# The installed copy of the plugin is turned off, so the rules come from this
# checkout. run <run>: the report goes to <run>.txt. The Decision lines are
# the ones *Finishing* takes from the description of #217, with the number of
# Decision 4 counted again in the merged code. Each run gets its own copy of
# the file, because the collector's bodies adds to the file that it gets.
run() {
  local prompt
  cp "$logs/collect.txt" "$logs/$1.collect.txt"
  prompt="Read $root/skills/github/scout.md and do what it says.
Job: citations.
Tree: $tree
Decision 1: Add the product skill: a skeptic that checks whether a task is worth doing before the work, with a Fable and Codex panel and a store of product decisions in docs/PRODUCT.md and docs/pdr/.
Decision 2: The start of a feature in the architecture skill keeps Problem and Touches; whether to build is the product skill's report.
Decision 3: review-loop checks the worth before round 1 (Worth first), and a finding that shows a capability gives nothing goes to the person, not to a rebuild.
Decision 4: rules.md gets the section \"Worth before work\", and now has 9,925 of the 10,000 characters that tests/rules_test.sh allows.
Decision 5: tests/review_loop_eval.sh marks the product skill's reader as a prompt of kind P.
File: $logs/$1.collect.txt
Collector: bash $root/skills/github/scripts/collect.sh"
  (cd "$tree" && claude -p --model haiku --output-format json \
    --settings '{"enabledPlugins":{"craft@kalinichenko":false,"kalinichenko@kalinichenko":false}}' \
    --plugin-dir "$root" --dangerously-skip-permissions "$prompt") >"$logs/$1.json" 2>&1 || true
  # The text of a session that ends in an error is no report.
  jq -r 'select(.is_error != true) | .result // empty' "$logs/$1.json" >"$logs/$1.txt" 2>/dev/null || true
}

for i in $(seq "$runs"); do run "$i" & done
wait

# block <n>: the lines of the report's block of issue #<n>. A block starts at
# a line with the issue's number and words of its title, in any markup: runs
# wrote "PR-less issue #117 …", and the title without its "rules: ".
block() {
  awk -v n="$1" '
    index($0, "#117") && index($0, "review-loop replaces") { cur = 117 }
    index($0, "#179") && index($0, "has 551 lines") { cur = 179 }
    cur == n' <<<"$report"
}
# falsified <n> [text]: the lines in the block of #<n> that give a quoted
# sentence as false by a numbered decision, with the text when it is given.
falsified() { block "$1" | grep -i false | grep -i 'decision[^0-9]*[0-9]' | grep '"' | grep -F "${2:-}"; }
failed=0
for i in $(seq "$runs"); do
  report=$(cat "$logs/$i.txt" 2>/dev/null || true)
  missed=
  falsified 117 'has 337 left' >/dev/null || missed="$missed; no false sentence of #117 with 337"
  ! falsified 179 >/dev/null || missed="$missed; a false sentence of #179"
  block 179 | grep -q ':186[^:]*moved to [^ ]*:189' || missed="$missed; :186 of #179 not moved to :189"
  if [ -z "$missed" ]; then verdict=pass; else verdict="FAIL${missed}"; failed=1; fi
  echo "== $i: $verdict"
  echo "${report:-no report}"
done
echo "Logs: $logs"
exit "$failed"
