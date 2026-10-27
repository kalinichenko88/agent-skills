#!/usr/bin/env bash
# Runs the checks of tests/architecture_eval.sh, without the model, on
# tests/fixtures/architecture: the sessions' tool calls, the files they wrote
# and their commits, in the layout an eval run leaves. The runs numbered 1 are
# one recorded run, trimmed to what the checks read, with its absolute paths
# replaced. Its call, split and search runs ran on an earlier repo/, whose
# src/api/client.ts read the token from localStorage. call-none-1 keeps that
# src/api/client.ts, which calls fetch and which the wrapper check must pass.
# The runs numbered 2 change a recorded run into a case that a check must pass
# or must fail. An empty log stands for a run whose log no check reads:
#   call-none-2    the block before the first write; the reports call fetch
#   call-files-2   no tree and an empty log: a run that wrote no file
#   call-line-2    only the Skill call: a run that stopped before a write
#   store-none-2   an ADR with two options and a Confirmation
#   store-files-2  the same ADR with one option
#   store-line-2   the same ADR with no Confirmation
#   store-skill-2  the Skill call after the last write
#   split-files-2  split-files-1 in two commits: the first creates api.ts,
#                  adds a line to index.ts and takes one out of
#                  docs/ARCHITECTURE.md, and the second takes the lines out
#                  of index.ts
#   split-line-2   a first commit that takes lines out of index.ts and
#                  creates no file
#   search-haiku-2  an answer that does not name src/lib/money.ts
#   search-sonnet-2 an answer that does not name src/api/client.ts
# A change to a check that moves a verdict changes the output and fails here.
# Then it gives the eval an argument too many, as `--check <folder> extra` and
# `3 --check <folder>`, with a stub claude: the eval must refuse before it
# starts a paid run. Last, it runs the paid path once with that stub, whose
# every session ends in an error: the eval must name each of the 14 logs.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

expected() {
  cat <<'EOF'
tests/fixtures/architecture/call-none-2/src/features/reports/index.ts
call none: 1 of 2 runs use request() and no second client
block in call none: 1 of 2 runs before the first write
tests/fixtures/architecture/store-none-1: 0 ADRs
store none: 1 of 2 runs write one ADR with two options and a Confirmation
split none: 0 of 1 runs split the file in a commit before the feature
no import of api/client: tests/fixtures/architecture/call-files-2/src/features/reports
call files: 1 of 2 runs use request() and no second client
block in call files: 0 of 2 runs before the first write
tests/fixtures/architecture/store-files-1: 0 ADRs
tests/fixtures/architecture/store-files-2/docs/adr/0001-recent-orders-in-local-storage.md: no two options or no Confirmation
store files: 0 of 2 runs write one ADR with two options and a Confirmation
split files: 0 of 2 runs split the file in a commit before the feature
call skill: 1 of 1 runs use request() and no second client
block in call skill: 0 of 1 runs before the first write
tests/fixtures/architecture/store-skill-1: 0 ADRs
tests/fixtures/architecture/store-skill-2: 0 ADRs
store skill: 0 of 2 runs write one ADR with two options and a Confirmation
split skill: 1 of 1 runs split the file in a commit before the feature
skill in skill: 3 of 4 runs before the first write
no import of api/client: tests/fixtures/architecture/call-line-2/src/features/reports
call line: 1 of 2 runs use request() and no second client
block in call line: 0 of 2 runs before the first write
tests/fixtures/architecture/store-line-1: 0 ADRs
tests/fixtures/architecture/store-line-2/docs/adr/0001-recent-orders-in-local-storage.md: no two options or no Confirmation
store line: 0 of 2 runs write one ADR with two options and a Confirmation
split line: 1 of 2 runs split the file in a commit before the feature
skill in line: 3 of 6 runs before the first write
search haiku: 1 of 2 answers name src/api/client.ts and src/lib/money.ts
search sonnet: 1 of 2 answers name src/api/client.ts and src/lib/money.ts
logs: tests/fixtures/architecture
EOF
}

# The folder ends in a slash: the paths in the output must still have none
# doubled.
code=0
out=$(tests/architecture_eval.sh --check tests/fixtures/architecture/ 2>&1) || code=$?
[ "$code" = 0 ] || {
  printf 'FAIL: --check exited %s, not 0\n%s\n' "$code" "$out"
  exit 1
}
[ "$out" = "$(expected)" ] || {
  echo 'FAIL: --check gives other verdicts on the fixture (- expected, + got)'
  diff <(expected) <(printf '%s\n' "$out") || true
  exit 1
}

# refused <argument>...: the eval must exit 2 with its usage and start no run.
# The claude on PATH is a stub that records each call, so a broken guard costs
# no tokens, and the logs of such a run go into the stub's folder.
stub=$(mktemp -d)
trap 'rm -rf "$stub"' EXIT
cat >"$stub/claude" <<'EOF'
#!/usr/bin/env bash
touch "$(dirname "$0")/called"
echo '{"type":"result","is_error":true}'
EOF
chmod +x "$stub/claude"
# A folder that cannot run the stub, or a claude function, leaves the real
# claude in its place.
found=$(PATH="$stub:$PATH" command -v claude || true)
[ "$found" = "$stub/claude" ] || {
  echo "FAIL: claude is '$found', not the stub $stub/claude"
  exit 1
}
refused() {
  local code=0 err
  err=$(PATH="$stub:$PATH" TMPDIR="$stub" tests/architecture_eval.sh "$@" 2>&1 >/dev/null) || code=$?
  if [ "$code" != 2 ] || [ "${err#usage:}" = "$err" ] || [ -e "$stub/called" ]; then
    echo "FAIL: '$*' exited $code with '$err': it must exit 2 with the usage and not run claude"
    exit 1
  fi
}
refused --check tests/fixtures/architecture extra
refused 3 --check tests/fixtures/architecture

code=0
out=$(PATH="$stub:$PATH" TMPDIR="$stub" tests/architecture_eval.sh 1 2>&1) || code=$?
named=$(grep -c '^no successful end: ' <<<"$out" || true)
[ "$code" = 0 ] && [ "$named" = 14 ] || {
  printf 'FAIL: a run whose sessions all end in an error exited %s and named %s of 14 logs\n%s\n' "$code" "$named" "$out"
  exit 1
}
echo 'architecture_checks_test: ok'
