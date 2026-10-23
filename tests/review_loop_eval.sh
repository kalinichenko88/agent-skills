#!/usr/bin/env bash
# Gives the main model a branch with one defect and two nits, and asks it to
# review and fix until the review is clean, one review subagent a round. It
# prints, for each run, the rounds and what each round after the first was
# given to read. It exits 1 when a run has fewer than two rounds, read the
# whole branch more than once after round 1, or did not invoke the skill. It
# calls the model, so it costs tokens and is not part of `make check`: run it
# by hand after a change to skills/review-loop or to its section in rules.md.
# It runs with this machine's other plugins and settings.
#
# Usage: tests/review_loop_eval.sh [runs, default 3]

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
runs=${1:-3}
[ "$runs" -ge 1 ] 2>/dev/null || { echo "usage: $0 [runs, at least 1]" >&2; exit 2; }
logs=$(mktemp -d)

task='This repository is on the branch feature. Review what the branch changes against main: dispatch one review subagent for each review round. Fix what the review finds, commit each round of fixes, and go on until the review is clean. Then stop, and list each round: what it read and what it found.'

# A repository whose feature branch adds slugify. The defect: the last
# replace has no g flag, so "-a-" keeps its trailing dash. The nits: var, and
# a comment that names the wrong return.
fixture() {
  local work=$1
  mkdir -p "$work/src"
  git -C "$work" init -q -b main
  git -C "$work" config user.name eval
  git -C "$work" config user.email eval@example.com
  echo '{"type":"module","scripts":{"test":"node --test"}}' >"$work/package.json"
  git -C "$work" add .
  git -C "$work" commit -qm "chore: start"
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

# report <log>: each review round is a top-level Agent call that is not an
# Explore subagent, the kind rules.md sends to count payloads and sweep docs. A
# round after the first that names no single commit — `git show <sha>`,
# `git show HEAD` or `<sha>^..<sha>` — was sent to the whole branch again. The
# fixture always has a defect, so a run that follows the skill has two rounds
# or more. At most one of them after round 1 reads the whole branch: the last
# pass, which a stop after three rounds skips.
# ponytail: the count reads prompt text, so a security review subagent counts
# as a whole-branch read, and a commit named another way counts as the whole
# branch; whether the last pass ran is left to the printed prompts.
failed=0
for log in "$logs"/run-*.jsonl; do
  prompts=$(jq -rR 'fromjson? | select(.type == "assistant" and .parent_tool_use_id == null)
    | .message.content[] | select(.type == "tool_use" and .name == "Agent")
    | select(.input.subagent_type != "Explore") | .input.prompt | gsub("\n"; " ")' "$log")
  rounds=$(grep -c . <<<"$prompts" || true)
  whole=$(tail -n +2 <<<"$prompts" |
    grep -cvE 'git( -C [^ ]+)? show( --?[a-z-]+)* ([0-9a-f]{7,}|HEAD)\.?([^.~^0-9A-Za-z]|$)|[0-9a-f]{7,}\^\.\.[0-9a-f]{7,}' || true)
  skill=$(jq -rR 'fromjson? | select(.type == "assistant" and .parent_tool_use_id == null)
    | .message.content[] | select(.type == "tool_use" and .name == "Skill")
    | .input.skill' "$log" | grep -cx 'kalinichenko:review-loop' || true)
  echo "== $(basename "$log" .jsonl): $rounds rounds, $whole later rounds sent to the whole branch, review-loop invoked $skill times"
  cut -c1-300 <<<"${prompts:-no review subagent ran}"
  [ "$rounds" -ge 2 ] && [ "$whole" -le 1 ] && [ "$skill" -ge 1 ] || failed=1
done
echo "Logs: $logs"
exit "$failed"
