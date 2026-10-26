#!/usr/bin/env bash
# Runs one Codex review of git diff <base>...HEAD in the current repository,
# in Codex's read-only sandbox and with the person's Codex config, and prints
# its findings as JSON:
# {"findings": [{"file", "line", "summary", "failure_scenario"}]}.
#
#   codex-review.sh <base>
#
# When the Codex CLI is not installed or not logged in, it prints
# "skipped: <why>" and exits 0: the review goes on without Codex. When codex
# fails or writes no findings file, it prints the end of Codex's log on stderr
# and exits 1. It exits 2 and runs no Codex for a wrong call, as a base that is
# not a commit or a working directory outside a repository, and for a range
# that git cannot diff or that changes nothing.
#
# Needs bash, git and the Codex CLI.

set -euo pipefail

[ $# -eq 1 ] || {
  echo 'usage: codex-review.sh <base>' >&2
  exit 2
}
git rev-parse --git-dir >/dev/null || {
  echo "codex-review.sh: no git repository at $PWD" >&2
  exit 2
}
# Both ends of the range as SHAs, so a later commit or fetch does not move it.
# Codex still reads the files around the diff from the working tree.
base=$(git rev-parse -q --verify "$1^{commit}") || {
  echo "codex-review.sh: $1 is not a commit" >&2
  exit 2
}
head=$(git rev-parse HEAD)
# A range that is empty, as from another working tree, or that git cannot
# diff would read as a clean review.
status=0
git diff --quiet "$base...$head" || status=$?
case $status in
  1) ;;
  0)
    echo "codex-review.sh: $base...$head changes nothing: is this the working tree of the branch under review?" >&2
    exit 2
    ;;
  *)
    echo "codex-review.sh: git cannot diff $base...$head" >&2
    exit 2
    ;;
esac

command -v codex >/dev/null || {
  echo 'skipped: the codex CLI is not installed'
  exit 0
}
codex login status >/dev/null 2>&1 || {
  echo 'skipped: codex is not logged in'
  exit 0
}

tmp=$(mktemp -d)
# bash 3.2 runs this trap with $? at 0 when set -u stops the script, so a run
# passes only when it set finished at its end.
clean() {
  local code=$?
  [ "$code" != 0 ] || [ -n "${finished:-}" ] || code=1
  rm -rf "$tmp"
  exit "$code"
}
finished=
trap clean EXIT
cat >"$tmp/schema.json" <<'EOF'
{
  "type": "object",
  "additionalProperties": false,
  "required": ["findings"],
  "properties": {
    "findings": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["file", "line", "summary", "failure_scenario"],
        "properties": {
          "file": { "type": "string" },
          "line": { "type": "integer" },
          "summary": { "type": "string" },
          "failure_scenario": { "type": "string" }
        }
      }
    }
  }
}
EOF

# The prompt that found three defects no /code-review round had reported, on
# three finished branches of this plugin (#59). Its second sentence came after
# that measurement: it keeps a person's Codex rules, as this plugin's rules.md,
# from starting a review loop inside this one review, or filing an issue.
prompt="You review a change in this git repository: \`git diff $base...$head\`. You are one reviewer inside a review that another agent runs: start no review loop and no review skill, and file nothing. Read the diff, and read the code around it as you need. Find defects: code that gives a wrong result, crashes, loses or corrupts data, opens a security hole, races, or breaks a contract that other code depends on. Look hardest at trust boundaries, partial failure and retries, concurrency and ordering, and empty, missing and timeout cases. Do not report style, names or cleanup. Report a finding only when you can name the input or the state that makes it fail, from the code. Do not change files. For each finding give the file, the line, a one-sentence summary and the failure scenario. Return no findings when the change has none."

if ! codex exec -s read-only --ephemeral --output-schema "$tmp/schema.json" \
  -o "$tmp/findings.json" "$prompt" </dev/null >"$tmp/log" 2>&1 ||
  [ ! -s "$tmp/findings.json" ]; then
  tail -n 20 "$tmp/log" >&2
  exit 1
fi
cat "$tmp/findings.json"
finished=1
