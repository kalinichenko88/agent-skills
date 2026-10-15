#!/bin/bash
# Runs the github skill's scripts against a fake gh. The fake answers from
# payloads recorded on this repository, filtered through jq as gh's own --jq
# does, and logs every call, so no test reaches GitHub.

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
filter=. search=''
for ((i = 1; i <= $#; i++)); do
  j=$((i + 1))
  case ${!i} in --jq) filter=${!j} ;; --search) search=${!j} ;; esac
done
# A list answers from issues-<search>.json or prs-<search>.json, and the open
# issues from open-issues.json, in $FAKE first.
list() {
  local f=$1-$search.json
  [ -n "$search" ] || f=open-issues.json
  if [ -f "$FAKE/$f" ]; then f=$FAKE/$f; else f=$FIXTURES/$f; fi
  if [ -f "$f" ]; then jq -r "$filter" "$f"; else echo '[]' | jq -r "$filter"; fi
}
case "$1 $2" in
  'api repos/{owner}/{repo}') echo kalinichenko88/agent-skills ;;
  'api user') echo kalinichenko88 ;;
  'api graphql')
    case "$*" in *"${FAKE_FAIL:-no failure asked}"*) echo 'gh: HTTP 502' >&2; exit 1 ;; esac
    # As GitHub, only the issues that the query asks for.
    asked=$(grep -oE 'n[0-9]+: issueOrPullRequest' <<<"$*" | cut -d: -f1 | jq -Rsc 'split("\n") - [""]')
    jq --argjson asked "$asked" 'if $asked == [] then . else
      .data.repository |= with_entries(select(.key as $k | any($asked[]; . == $k))) end' \
      "$FAKE/graphql.json" | jq -r "$filter" ;;
  'issue list') list issues ;;
  'pr list') list prs ;;
  'issue view') jq -r ".data.repository.n$3.body" "$FAKE/graphql.json" ;;
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
export PATH="$tmp/bin:$PATH" FAKE="$tmp" FIXTURES="$fixtures" TMPDIR="$tmp"

fail() {
  printf 'FAIL: %s\n' "$1"
  [ -z "${2:-}" ] || printf '%s\n' "$2"
  exit 1
}
check() { [ "$2" = "$3" ] || fail "$1" "$(printf 'want: %s\ngot:  %s' "$2" "$3")"; }
# Sets the GraphQL answer: issues and PRs #4 to #10 as recorded, with #5, or
# the path $2, changed by the jq filter $1.
answer() { jq "${2:-.data.repository.n5} |= ($1)" "$fixtures/${3:-tracker.json}" >"$tmp/graphql.json"; }
writes() { grep -E '^issue (edit|comment)|^issue develop [0-9]+ --name' "$tmp/calls" || true; }

# status: and also: of a host. As recorded, #5's one open pull request is #9,
# which you wrote and which only names #5: the issue is not taken.
answer .
check 'status of an issue whose one open PR is yours' "$(printf 'state: open\nstatus: PR #9 by you\nalso: 0\ntaken: no')" \
  "$(bash "$scripts/collect.sh" status 5)"
check 'status takes the number with its #' "$(bash "$scripts/collect.sh" status 5)" \
  "$(bash "$scripts/collect.sh" status '#5')"

answer '.timelineItems.nodes = []'
check 'status of a free issue' "$(printf 'state: open\nstatus: free\nalso: 0\ntaken: no')" \
  "$(bash "$scripts/collect.sh" status 5)"

answer '.assignees.nodes = [{login: "someone"}]
  | .linkedBranches.nodes = [{ref: {name: "fix/5-citations"}}, {ref: null}]
  | .closedByPullRequestsReferences.nodes = [{number: 12, state: "OPEN", author: {login: "someone"}},
      {number: 11, state: "MERGED", author: {login: "someone"}}]
  | .timelineItems.nodes += [
      {isCrossRepository: false, source: {__typename: "PullRequest", number: 12, title: "t", state: "OPEN", author: {login: "someone"}}},
      {isCrossRepository: false, source: {__typename: "PullRequest", number: 13, title: "t", state: "OPEN", author: null}},
      {isCrossRepository: true, source: {__typename: "PullRequest", number: 14, title: "t", state: "OPEN", author: {login: "someone"}}},
      {isCrossRepository: false, source: {__typename: "Issue", number: 15, title: "t", state: "OPEN"}}]'
check 'status of a busy issue' \
  "$(printf 'status: assigned to someone, branch fix/5-citations, PR #9 by you, PR #12 by someone, PR #13 by ghost\nalso: 0\ntaken: yes')" \
  "$(bash "$scripts/collect.sh" status 5 | sed 1d)"

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

# bodies gives no entry to the issue that a duplicate duplicates, when the
# file holds it already, nor to one in another repository.
here='{nameWithOwner: "kalinichenko88/agent-skills"}'
answer "{n7: (.n5 | .number = 7 | .state = \"CLOSED\" | .stateReason = \"DUPLICATE\" | .duplicateOf = {number: 5, repository: $here})}" .data.repository
: >"$tmp/calls"
bash "$scripts/collect.sh" bodies "$tmp/collected" 7 >/dev/null
check 'bodies does not fetch an issue already in the file' '' "$(grep 'n5: issueOrPullRequest' "$tmp/calls" || true)"
check 'bodies counts only the new entries' '== end: 1 entries' "$(tail -1 "$tmp/collected")"
answer '{n7: (.n5 | .number = 7 | .state = "CLOSED" | .stateReason = "DUPLICATE"
  | .duplicateOf = {number: 3, repository: {nameWithOwner: "other/repo"}})}' .data.repository
printf '== Bodies\n' >"$tmp/collected"
: >"$tmp/calls"
bash "$scripts/collect.sh" bodies "$tmp/collected" 7 >/dev/null
check 'bodies does not fetch a duplicate of another repository here' '' "$(grep 'n3: issueOrPullRequest' "$tmp/calls" || true)"
grep -q '^duplicate of: other/repo#3$' "$tmp/collected" || fail 'an entry names the other repository of its duplicate'

# A failed query stops bodies before it writes: the duplicateOf query, and the
# one that reads the entries.
answer .
printf '== Bodies\n' >"$tmp/collected"
for failing in '{ ... on Issue { repository { nameWithOwner } duplicateOf' 'comments(first'; do
  FAKE_FAIL=$failing bash "$scripts/collect.sh" bodies "$tmp/collected" 5 >/dev/null 2>&1 &&
    fail "bodies exits 0 when the query with \"$failing\" fails"
  check "bodies writes nothing when the query with \"$failing\" fails" '== Bodies' "$(cat "$tmp/collected")"
done

# filing writes the open titles, each search, and the bodies of its open hits.
out=$(bash "$scripts/collect.sh" filing scout.md)
collected=${out%%: *}
check 'filing lists every open issue' 5 "$(sed -n '/^== Open issues/,/^== Search/p' "$collected" | grep -c ' open$')"
check 'filing gives a body to each open hit' \
  "$(printf '==> #5 \n==> #8 \n==> PR #9 \n==> #10 \n== end: 4 entries')" \
  "$(grep -E '^==> |^== end' "$collected" | sed -E 's/^(==> (PR )?#[0-9]+ ).*/\1/')"
out=$(bash "$scripts/collect.sh" filing typescript)
check 'filing ends the bodies with no open hit' '== end: 0 entries' "$(tail -1 "${out%%: *}")"

# A path is searched by its base name too; an empty name is not searched.
: >"$tmp/calls"
bash "$scripts/collect.sh" filing skills/github/scout.md/ '' >/dev/null
check 'filing searches each name and base name once' \
  "$(printf 'skills/github/scout.md\nscout.md')" \
  "$(sed -n 's/^issue list --state all --limit 1000 --search \(.*\) --json.*/\1/p' "$tmp/calls")"

# A failed query leaves no file behind.
collects() { find "$tmp" -maxdepth 1 -name 'collect.*' | wc -l | tr -d ' '; }
before=$(collects)
FAKE_FAIL='comments(first' bash "$scripts/collect.sh" filing scout.md >/dev/null 2>&1 &&
  fail 'filing exits 0 when a query fails'
check 'a failed filing leaves no file behind' "$before" "$(collects)"

# take-in starts with the issue and its timeline, then the bodies of the
# timeline, of each issue with a bug or debt label, and of the open hits.
: >"$tmp/calls"
out=$(bash "$scripts/collect.sh" take-in '#5' 'enhancement, bug ' scout.md)
collected=${out%%: *}
check 'take-in lists the timeline' \
  "$(printf 'PR #4 \n#8 \nPR #9 \n#10 ')" \
  "$(sed -n '/^== Its timeline/,/^== Open issues/p' "$collected" | sed -n -E 's/^((PR )?#[0-9]+ ).*/\1/p')"
check 'take-in gives the issue one entry, and a body to each hit' \
  "$(printf '==> #5 \n==> PR #4 \n==> #6 \n==> #7 \n==> #8 \n==> PR #9 \n==> #10 \n== end: 6 entries')" \
  "$(grep -E '^==> |^== end' "$collected" | sed -E 's/^(==> (PR )?#[0-9]+ ).*/\1/')"
check 'take-in reads each bug and debt label, its spaces cut' \
  "$(printf 'enhancement\nbug')" "$(sed -n 's/.*--label \(.*\) --json.*/\1/p' "$tmp/calls")"
answer '.timelineItems.totalCount = 150'
out=$(bash "$scripts/collect.sh" take-in 5 '' scout.md)
grep -q '^Only the newest 100 of 150 references are here\.$' "${out%%: *}" ||
  fail 'take-in says when the timeline is cut'

check 'usage names every job' 4 "$(bash "$scripts/collect.sh" 2>&1 | grep -c '^usage: collect.sh ')"

# add-finding.sh refuses a busy host and a full one, and writes nothing.
printf '## Also: the scout misses a cited line\n\nWhere: scout.md:26.\n' >"$tmp/section.md"
add() { bash "$scripts/add-finding.sh" 5 "$tmp/section.md" 'New title' "$@"; }

for case in 'busy|.assignees.nodes = [{login: "someone"}]|someone works on it: assigned to someone' \
  'full|.body += "\n## Also: one\n## Also: two\n"|it holds 2 added findings already' \
  'closed|.state = "CLOSED"|it is closed' \
  'pull request|{__typename: "PullRequest", number: 5, title: "t", state: "OPEN", body: ""}|it is a pull request'; do
  IFS='|' read -r name change reason <<<"$case"
  answer "$change"
  : >"$tmp/calls"
  out=$(add) && fail "add-finding.sh wrote to a $name host"
  case $out in *"$reason"*) ;; *) fail "add-finding.sh on a $name host" "$out" ;; esac
  check "add-finding.sh writes nothing to a $name host" '' "$(writes)"
done

# A host whose every entry is yours takes the finding. DRY_RUN=1 prints the
# writes and runs none.
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
  "$(jq -r .data.repository.n5.body "$fixtures/tracker.json"; echo; cat "$tmp/section.md")" "$(cat "$tmp/body")"

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

printf 'feat/5-scout-citations\thttps://github.com/kalinichenko88/agent-skills/tree/feat/5-scout-citations\n' >>"$tmp/linked"
out=$(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 feat/5-scout-citations)
case $out in *'using it'*) fail 'worktree.sh leaves a linked branch it was given' "$out" ;; esac
case $out in *'--name feat/5-scout-citations --checkout'*) ;;
  *) fail 'worktree.sh checks out the linked branch it was given' "$out" ;;
esac

echo 'github_scripts_test: ok'
