#!/bin/bash
# Runs the github skill's scripts against a fake gh. The fake answers GraphQL
# from a payload recorded on this repository's issue #5, filtered through jq
# as gh's own --jq does, and logs every call, so no test reaches GitHub.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
scripts=$root/skills/github/scripts
fixtures=$root/tests/fixtures/github
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir "$tmp/bin"
cat >"$tmp/bin/gh" <<'EOF'
#!/bin/bash
echo "$*" >>"$FAKE/calls"
filter=.
for ((i = 1; i <= $#; i++)); do
  if [ "${!i}" = --jq ]; then j=$((i + 1)); filter=${!j}; fi
done
case "$1 $2" in
  'api repos/{owner}/{repo}') echo kalinichenko88/agent-skills ;;
  'api user') echo kalinichenko88 ;;
  'api graphql') jq -r "$filter" "$FAKE/graphql.json" ;;
  'issue view') jq -r '.data.repository[].body' "$FAKE/graphql.json" ;;
  'issue edit') while [ "$1" != --body-file ]; do shift; done; cp "$2" "$FAKE/body" ;;
  'issue comment') ;;
  'issue develop')
    case $3 in
      --list) cat "$FAKE/linked" 2>/dev/null || true ;;
      --help) echo '      --worktree path        Check out the branch into a worktree at the given path' ;;
    esac ;;
  *) echo "fake gh: no answer for: $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH" FAKE="$tmp"

fail() {
  printf 'FAIL: %s\n' "$1"
  [ -z "${2:-}" ] || printf '%s\n' "$2"
  exit 1
}
check() { [ "$2" = "$3" ] || fail "$1" "$(printf 'want: %s\ngot:  %s' "$2" "$3")"; }
# Sets the GraphQL answer: the recorded issue #5, changed by the jq filter $1.
answer() { jq "${2:-.data.repository.n5} |= ($1)" "$fixtures/${3:-status-5.json}" >"$tmp/graphql.json"; }
writes() { grep -E '^issue (edit|comment)|^issue develop [0-9]+ --name' "$tmp/calls" || true; }

# status: and also: of a host.
answer .
check 'status of a free issue' "$(printf 'state: open\nstatus: free\nalso: 0')" \
  "$(bash "$scripts/collect.sh" status 5)"

answer '.assignees.nodes = [{login: "someone"}]
  | .linkedBranches.nodes = [{ref: {name: "fix/5-citations"}}, {ref: null}]
  | .closedByPullRequestsReferences.nodes = [{number: 12, state: "OPEN"}, {number: 11, state: "MERGED"}]
  | .timelineItems.nodes += [
      {isCrossRepository: false, source: {__typename: "PullRequest", number: 12, title: "t", state: "OPEN"}},
      {isCrossRepository: false, source: {__typename: "PullRequest", number: 13, title: "t", state: "OPEN"}},
      {isCrossRepository: true, source: {__typename: "PullRequest", number: 14, title: "t", state: "OPEN"}},
      {isCrossRepository: false, source: {__typename: "Issue", number: 15, title: "t", state: "OPEN"}}]'
check 'status of a busy issue' 'status: assigned to someone, branch fix/5-citations, PR #12, PR #13' \
  "$(bash "$scripts/collect.sh" status 5 | sed -n '/^status: /p')"

answer '.body += "\n\n## Also: one\r\n\r\nx\n\n## Also: two\n\nNot a heading: ## Also: three\n### Also: four\n"'
check 'also: counts the added sections' 'also: 2' \
  "$(bash "$scripts/collect.sh" status 5 | sed -n '/^also: /p')"

# bodies gives no second entry to a number already in the file.
printf '== Bodies\n\n==> #5 The scout misses a cited line open\n' >"$tmp/collected"
: >"$tmp/calls"
out=$(bash "$scripts/collect.sh" bodies "$tmp/collected" '#5')
case $out in 'already in the file: #5'*) ;; *) fail 'bodies with a number already in the file' "$out" ;; esac
check 'bodies adds nothing for a number already in the file' 3 "$(wc -l <"$tmp/collected" | tr -d ' ')"
check 'bodies queries nothing for a number already in the file' '' "$(grep graphql "$tmp/calls" || true)"

# add-finding.sh refuses a busy host and a full one, and writes nothing.
printf '## Also: the scout misses a cited line\n\nWhere: scout.md:26.\n' >"$tmp/section.md"
add() { bash "$scripts/add-finding.sh" 5 "$tmp/section.md" 'New title' "$@"; }

for case in 'busy|.assignees.nodes = [{login: "someone"}]|someone works on it: assigned to someone' \
  'full|.body += "\n## Also: one\n## Also: two\n"|it holds 2 added findings already' \
  'closed|.state = "CLOSED"|it is closed'; do
  IFS='|' read -r name change reason <<<"$case"
  answer "$change"
  : >"$tmp/calls"
  out=$(add) && fail "add-finding.sh wrote to a $name host"
  case $out in *"$reason"*) ;; *) fail "add-finding.sh on a $name host" "$out" ;; esac
  check "add-finding.sh writes nothing to a $name host" '' "$(writes)"
done

# DRY_RUN=1 prints the writes and runs none.
answer '.assignees.nodes = [{login: "kalinichenko88"}]'
: >"$tmp/calls"
out=$(DRY_RUN=1 add bug)
case $out in *'dry run: gh issue edit 5 --title New\ title --body-file '*'--add-label bug'*'dry run: gh issue comment 5'*) ;;
  *) fail 'add-finding.sh with DRY_RUN=1 prints its writes' "$out" ;;
esac
check 'add-finding.sh with DRY_RUN=1 runs no write' '' "$(writes)"

# Without it, the body keeps the old text and gains the section.
answer .
: >"$tmp/calls"
add >/dev/null
check 'add-finding.sh edits and comments' \
  "$(printf 'issue edit 5 --title New title --body-file %s\nissue comment 5 --body Added to the body: the scout misses a cited line.' \
    "$(sed -n 's/^issue edit 5 --title New title --body-file //p' "$tmp/calls")")" "$(writes)"
check 'the new body is the old one and the section' \
  "$(jq -r .data.repository.n5.body "$fixtures/status-5.json"; echo; cat "$tmp/section.md")" "$(cat "$tmp/body")"

# take-in-check.sh
take() { bash "$scripts/take-in-check.sh" "$@" 2>&1 || echo "exit $?"; }
answer . .data.repository.issue take-in-5.json
check 'take-in-check.sh on a free issue' 'take #5' "$(take 5)"
answer '.state = "CLOSED" | .assignees.nodes = [{login: "someone"}, {login: "kalinichenko88"}]
  | .closedByPullRequestsReferences.nodes = [{number: 9, state: "OPEN", author: {login: "someone"}},
      {number: 10, state: "OPEN", author: {login: "kalinichenko88"}}]' .data.repository.issue take-in-5.json
check 'take-in-check.sh on an issue someone else has' \
  "$(printf '#5: closed\n#5: assigned to someone\n#5: PR #9 by someone is open and closes it\nexit 1')" "$(take '#5')"
check 'take-in-check.sh on an issue of another repository' \
  "$(printf '#179 is in selgeo/magos, and this checkout is kalinichenko88/agent-skills: stop\nexit 1')" \
  "$(take https://github.com/selgeo/magos/issues/179)"

# worktree.sh in a main checkout, with DRY_RUN=1.
git init -q "$tmp/repo"
top=$(git -C "$tmp/repo" rev-parse --show-toplevel)
: >"$tmp/calls"
out=$(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 feat/5-scout-citations)
check 'worktree.sh with DRY_RUN=1 prints its writes and the path' \
  "$(printf 'dry run: gh issue develop 5 --name feat/5-scout-citations --checkout --worktree %s\ndry run: echo .claude/worktrees/ >>%s\n%s' \
    "$top/.claude/worktrees/feat/5-scout-citations" "$top/.git/info/exclude" "$top/.claude/worktrees/feat/5-scout-citations")" "$out"
check 'worktree.sh with DRY_RUN=1 runs no write' '' "$(writes)"
grep -q .claude/worktrees/ "$top/.git/info/exclude" && fail 'worktree.sh with DRY_RUN=1 wrote info/exclude'

printf 'feat/5-linked\thttps://github.com/kalinichenko88/agent-skills/tree/feat/5-linked\n' >"$tmp/linked"
out=$(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 feat/5-scout-citations)
case $out in *'using it'*'--name feat/5-linked --checkout'*) ;;
  *) fail 'worktree.sh reuses the linked branch' "$out" ;;
esac

echo 'github_scripts_test: ok'
