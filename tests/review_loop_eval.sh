#!/usr/bin/env bash
# Gives the main model a branch with one defect and two nits, and asks it to
# review and fix at level high, one review subagent a round, with no one to
# answer its questions. It prints, for each run, the counts, then each review
# subagent's prompt after its kind: W reads the whole branch, C one commit, T
# is the review of the tests, A the review of the architecture, S the security
# review. It exits 1 when a run has fewer than two rounds, read the whole
# branch more than once after round 1, ran more than three rounds in one
# count, sent the review of the tests other than once next to the last pass,
# or sent one with no last pass, sent the review of the architecture other
# than once before round 2, ran no security review after its last read of the
# whole branch, ran /security-review in the session or in no subagent, did
# not invoke the skill, or ended on a report that names no
# docs, no review of the tests or no review of the architecture. It calls the
# model, so it costs tokens and is not part of `make check`: run it by hand
# after a change to skills/review-loop or to its section in rules.md.
# It runs with this machine's other plugins and settings.
#
# Usage: tests/review_loop_eval.sh [runs, default 3]

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
runs=${1:-3}
[ "$runs" -ge 1 ] 2>/dev/null || { echo "usage: $0 [runs, at least 1]" >&2; exit 2; }
logs=$(mktemp -d)

task='This repository is on the branch feature. Review what the branch changes against main at level high: dispatch one review subagent for each review round. Fix what the review finds, and commit each round of fixes. No one can answer questions in this run. Then stop, and list each round: what it read and what it found.'

# A repository whose feature branch adds slugify. The defect: the last
# replace has no g flag, so "-a-" keeps its trailing dash. The nits: var, and
# a comment that names the wrong return. Its architecture file makes the
# skill send the review of the architecture.
fixture() {
  local work=$1
  mkdir -p "$work/src"
  git -C "$work" init -q -b main
  git -C "$work" config user.name eval
  git -C "$work" config user.email eval@example.com
  echo '{"type":"module","scripts":{"test":"node --test"}}' >"$work/package.json"
  mkdir -p "$work/docs"
  cat >"$work/docs/ARCHITECTURE.md" <<'EOF'
# Architecture

`src/` holds one string helper a file, with its test beside it.

## Invariants

- **I-1.** A helper MUST NOT call `require`: the package is an ES module.
  Check: grep `require\(` in `src`.
EOF
  git -C "$work" add .
  git -C "$work" commit -qm "chore: start"
  # A local origin, so /security-review has a default branch to read against.
  git init -q --bare -b main "$work.git"
  git -C "$work" remote add origin "$work.git"
  git -C "$work" push -q origin main
  git -C "$work" remote set-head origin main
  git -C "$work" checkout -qb feature
  cat >"$work/src/slug.js" <<'EOF'
// Returns the title in lower case.
export function slugify(title) {
  var slug = title.toLowerCase().trim();
  slug = slug.replace(/[^a-z0-9]+/g, '-');
  return slug.replace(/^-|-$/, '');
}
EOF
  cat >"$work/src/slug.test.js" <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { slugify } from './slug.js';

test('joins words with a dash', () => {
  assert.equal(slugify('Hello World'), 'hello-world');
});
EOF
  git -C "$work" add .
  git -C "$work" commit -qm "feat: add slugify"
}

# The installed copy of the plugin is turned off, so the rules come from this
# checkout.
run() {
  local work=${1%.jsonl}
  fixture "$work"
  (cd "$work" && claude -p --output-format stream-json --verbose \
    --settings '{"enabledPlugins":{"kalinichenko@kalinichenko":false}}' \
    --plugin-dir "$root" --dangerously-skip-permissions "$task") >"$1" 2>&1
}

for i in $(seq "$runs"); do
  run "$logs/run-$i.jsonl" &
done
wait

# report <log>: each top-level Agent call that is not an Explore subagent, the
# kind rules.md sends to count payloads and sweep docs, is a review round or a
# part of the security review. The security review is a prompt that says
# "security review" or "/security-review": the skill sends one subagent that
# runs the command, and a run fails when no subagent makes a Skill call of
# security-review. A top-level one is the command run in the
# session, where its prompt can end the turn on its report (#183), so the run
# fails. There the command sends one subagent to find defects, and one with
# the "HARD EXCLUSIONS" of /security-review for each finding. A round after the
# first that names no single commit — `git show <sha>`, `git show HEAD` or
# `<sha>^..<sha>` — was sent to the whole branch again. The fixture always has
# a defect, so a run that follows the skill has two rounds or more. At most one
# of them after round 1 reads the whole branch: the last pass, which a stop
# after three rounds skips. A security review follows the last read of the
# whole branch. The review of the tests is an Agent call, of any kind, whose
# prompt names tests-lens.md. It is not a round. The skill sends it once, next
# to the last pass, as round 1 always has a defect here; a stop after three
# rounds skips both. The review of the architecture is an Agent call with
# model opus whose prompt names architecture-lens.md. It is not a round
# either. The skill sends it once, beside round 1, so before the first round
# that reads one commit. A round whose prompt names that file too is still a
# round, so a run that folds the review into round 1 has none.
# Round 1, the last pass, the review of the tests and the security review each
# start a count of rounds. Step 4 stops a count at its third round when no one
# can answer: round 1 and two more, or three after the others.
# ponytail: the count reads prompt text. A prompt that names one commit and
# the whole branch counts as one commit. A commit named another way counts as
# the whole branch. So does a part of the security review without those words,
# and a review of the tests that does not name tests-lens.md. A round that
# says "security review" is taken for one: it can pass a run that ran none,
# and it can hide a second read of the whole branch. A round taken for the
# whole branch, the review of the tests or the security review starts a new
# count, so it can hide a count past three rounds. Whether the last pass ran
# is left to the printed prompts.
commit='git( -C [^ ]+)? show( --?[a-z-]+)* ([0-9a-f]{7,}|HEAD)\.?([^.~^0-9A-Za-z]|$)|[0-9a-f]{7,}\^\.\.[0-9a-f]{7,}'
secrev='security[ -]review|hard exclusions'
failed=0
for log in "$logs"/run-*.jsonl; do
  # One line a prompt: W when it reads the whole branch, C one commit, T the
  # review of the tests, S the security review, then a tab and the prompt.
  prompts=$(jq -rR --arg commit "$commit" --arg secrev "$secrev" 'fromjson?
    | select(.type == "assistant" and .parent_tool_use_id == null)
    | .message.content[] | select(.type == "tool_use")
    | if .name == "Skill" and .input.skill == "security-review" then "S\tSkill: /security-review"
      elif .name == "Agent" and (.input.subagent_type != "Explore" or (.input.prompt | test("(tests|architecture)-lens\\.md"))) then (.input.model // "") as $model | .input.prompt | gsub("\n"; " ")
        | (if test("tests-lens\\.md") then "T" elif test("architecture-lens\\.md") and $model == "opus" then "A" elif test($secrev; "i") then "S" elif test($commit) then "C" else "W" end) + "\t" + .
      else empty end' "$log")
  arch=$(cut -f1 <<<"$prompts" | grep -c A || true)
  early=$(cut -f1 <<<"$prompts" | tr -d '\n' | grep -cE '^[^C]*A' || true)
  # The counts of rounds below leave the review of the architecture out.
  kinds=$(cut -f1 <<<"$prompts" | grep -v A || true)
  rounds=$(grep -c '[CW]' <<<"$kinds" || true)
  whole=$(grep '[CW]' <<<"$kinds" | tail -n +2 | grep -c W || true)
  last=$(grep -n W <<<"$kinds" | tail -n 1 | cut -d: -f1)
  security=$(tail -n +"$((${last:-0} + 1))" <<<"$kinds" | grep -c S || true)
  inline=$(grep -c 'Skill: /security-review' <<<"$prompts" || true)
  nested=$(jq -rR 'fromjson? | select(.type == "assistant" and .parent_tool_use_id != null)
    | .message.content[] | select(.type == "tool_use" and .name == "Skill")
    | .input.skill' "$log" | grep -cx 'security-review' || true)
  long=$(tr -d '\n' <<<"$kinds" | grep -oE '^WCCC|[WST]CCCC' | grep -c . || true)
  tests=$(grep -c T <<<"$kinds" || true)
  paired=$(tr -d '\n' <<<"$kinds" | grep -cE '(WT|TW)[^W]*$' || true)
  skill=$(jq -rR 'fromjson? | select(.type == "assistant" and .parent_tool_use_id == null)
    | .message.content[] | select(.type == "tool_use" and .name == "Skill")
    | .input.skill' "$log" | grep -cx 'kalinichenko:review-loop' || true)
  # The last report is the summary, and rules.md wants the docs named in it:
  # a Docs item, or "docs impact: none".
  # The skill wants the review of the tests named there too, at level high.
  result=$(jq -rR 'fromjson? | select(.type == "result") | .result' "$log")
  docs=$(grep -ciE 'docs( impact)?:' <<<"$result" || true)
  named=$(grep -ciE '(^|[^a-z])tests?[ -]review|review of the tests|tests-lens' <<<"$result" || true)
  archnamed=$(grep -ciE 'architecture[ -](review|lens)|review of the architecture' <<<"$result" || true)
  echo "== $(basename "$log" .jsonl): $rounds rounds, $whole later rounds sent to the whole branch, $long counts past three rounds, $tests reviews of the tests ($paired next to the last whole-branch read), $arch reviews of the architecture ($early before round 2), $security security review calls after the last whole-branch read ($inline run in the session, $nested in a subagent), review-loop invoked $skill times, $docs docs lines, $named lines on the review of the tests and $archnamed on the review of the architecture in the last report"
  cut -c1-300 <<<"${prompts:-no review subagent ran}"
  [ "$rounds" -ge 2 ] && [ "$whole" -le 1 ] && [ "$long" -eq 0 ] && [ "$tests" -eq "$whole" ] && [ "$paired" -eq "$tests" ] && [ "$arch" -eq 1 ] && [ "$early" -eq 1 ] && [ "$security" -ge 1 ] && [ "$inline" -eq 0 ] && [ "$nested" -ge 1 ] && [ "$skill" -ge 1 ] && [ "$docs" -ge 1 ] && [ "$named" -ge 1 ] && [ "$archnamed" -ge 1 ] || failed=1
done
echo "Logs: $logs"
exit "$failed"
