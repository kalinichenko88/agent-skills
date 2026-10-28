#!/usr/bin/env bash
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
#!/usr/bin/env bash
echo "$*" >>"$FAKE/calls"
case "$*" in *"${FAKE_FAIL:-no failure asked}"*) echo 'gh: HTTP 502' >&2; exit 1 ;; esac
filter=. search=''
for ((i = 1; i <= $#; i++)); do
  j=$((i + 1))
  case ${!i} in --jq) filter=${!j} ;; --search) search=${!j} ;; --silent) exec >/dev/null ;; esac
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
    # As GitHub, only the issues that the query asks for.
    asked=$(grep -oE 'n[0-9]+: issueOrPullRequest' <<<"$*" | cut -d: -f1 | jq -Rsc 'split("\n") - [""]')
    jq --argjson asked "$asked" 'if $asked == [] then . else
      .data.repository |= with_entries(select(.key as $k | any($asked[]; . == $k))) end' \
      "$FAKE/graphql.json" | jq -r "$filter"
    # graphql.next.json, when there, answers from the next call on.
    [ ! -f "$FAKE/graphql.next.json" ] || mv "$FAKE/graphql.next.json" "$FAKE/graphql.json" ;;
  'issue list') list issues ;;
  'pr list') list prs ;;
  'issue view')
    jq ".data.repository.n$3 | {body, assignees: [.assignees.nodes[]?]}" "$FAKE/graphql.json" | jq -r "$filter" ;;
  'issue edit') while [ $# -gt 0 ] && [ "$1" != --body-file ]; do shift; done; [ $# = 0 ] || cp "$2" "$FAKE/body" ;;
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
# which you wrote and which only names #5.
answer .
check 'status of an issue whose one open PR is yours' "$(printf 'state: open\nstatus: PR #9 by you\nalso: 0')" \
  "$(bash "$scripts/collect.sh" status 5)"
check 'status takes the number with its #' "$(bash "$scripts/collect.sh" status 5)" \
  "$(bash "$scripts/collect.sh" status '#5')"

answer '.timelineItems.nodes = []'
check 'status of a free issue' "$(printf 'state: open\nstatus: free\nalso: 0')" \
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
  "$(printf 'status: assigned to someone, branch fix/5-citations, PR #9 by you, PR #12 by someone, PR #13 by ghost\nalso: 0')" \
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

# Past the limit, the bodies of the hits that the most names found come first:
# #8 is found by both names here, and the ties go newest first.
jq '[.[] | select(.number == 8)]' "$fixtures/issues-scout.md.json" >"$tmp/issues-sheet.json"
out=$(COLLECT_LIMIT=1 bash "$scripts/collect.sh" filing scout.md sheet)
check 'past the limit, the file names the hits it left out, in rank order' \
  "$(printf '== end: 0 entries\n\n== Left out\n\nThe file reached its limit of 0 KB. These hits have no entry, the timeline first, then the ones the most names found: #8 #10 #9 #5')" \
  "$(sed -n '/^== end/,$p' "${out%%: *}")"
whole=$(bash "$scripts/collect.sh" filing scout.md sheet)
whole=${whole%%: *}
head=$(sed '/^== Bodies$/,$d' "$whole" | wc -c)
eight=$(awk '/^==> / { p = /^==> #8 / } /^== end/ { p = 0 } p' "$whole" | wc -c)
out=$(COLLECT_LIMIT=$((head + eight + 10)) bash "$scripts/collect.sh" filing scout.md sheet)
check 'the limit keeps the first hits that fit, and leaves out the rest' \
  "$(printf '==> #8 \n== end: 1 entries\nhave no entry, the timeline first, then the ones the most names found: #10 #9 #5')" \
  "$(grep -E '^==> |^== end|have no entry' "${out%%: *}" | sed -E 's/^(==> (PR )?#[0-9]+ ).*/\1/; s/.*(have no entry)/\1/')"
rm "$tmp/issues-sheet.json"

# A path is searched by its base name too; an empty name is not searched.
: >"$tmp/calls"
bash "$scripts/collect.sh" filing '' skills/github/scout.md/ >/dev/null
check 'filing searches each name and base name once' \
  "$(printf 'skills/github/scout.md\nscout.md')" \
  "$(sed -n 's/^issue list --state all --limit 1000 --search \(.*\) --json.*/\1/p' "$tmp/calls")"

# A failed query leaves no file behind.
collects() { find "$tmp" -maxdepth 1 -name 'collect.*' | wc -l | tr -d ' '; }
before=$(collects)
FAKE_FAIL='comments(first' bash "$scripts/collect.sh" filing scout.md >/dev/null 2>&1 &&
  fail 'filing exits 0 when a query fails'
check 'a failed filing leaves no file behind' "$before" "$(collects)"

# bash 3.2 runs an EXIT trap with $? at 0 when set -u stops a script. stops
# <script> <n> <args> copies the scripts, puts a stop after the n-th line that
# sets an EXIT trap in that script, and runs the copy with a finished from the
# environment. Two stops: an unbound variable, the case itself, and an exit 0,
# which gives the trap the $? of 0 of bash 3.2 on any bash. Each must exit
# non-zero, show that it reached the stop, and leave nothing in TMPDIR.
stops() {
  local script=$1 at=$2 stop mark before out
  shift 2
  for stop in unbound exit; do
    rm -rf "$tmp/stopped"
    cp -R "$scripts" "$tmp/stopped"
    awk -v at="$at" -v stop="$stop" '{ print } !/^[ \t]*#/ && /trap .* EXIT/ && ++n == at {
      print (stop == "exit" ? "echo stop-after-trap; exit 0" : ": \"$unbound_after_trap\"") }' \
      "$scripts/$script" >"$tmp/stopped/$script"
    mark='stop-after-trap'
    [ "$stop" = exit ] || mark='unbound_after_trap: unbound variable'
    before=$(ls -A "$tmp")
    out=$(finished=1 bash "$tmp/stopped/$script" "$@" 2>&1) && fail "$script $at exits 0 after its $stop stop" "$out"
    case $out in *"$mark"*) ;; *) fail "$script $at stops before its $stop stop" "$out" ;; esac
    check "$script $at leaves nothing in TMPDIR after its $stop stop" "$before" "$(ls -A "$tmp")"
  done
}
stops collect.sh 2 filing scout.md
printf '== Bodies\n' >"$tmp/collected"
stops collect.sh 1 bodies "$tmp/collected" 5

# take-in starts with the issue and its timeline, then the bodies of the
# timeline and of the open hits. An issue with a bug or debt label that
# nothing else brings, as #6 and #7 here, has its open title only.
: >"$tmp/calls"
out=$(bash "$scripts/collect.sh" take-in '#5' 'enhancement, bug ' scout.md)
collected=${out%%: *}
check 'take-in lists the timeline' \
  "$(printf 'PR #4 \n#8 \nPR #9 \n#10 ')" \
  "$(sed -n '/^== Its timeline/,/^== Open issues/p' "$collected" | sed -n -E 's/^((PR )?#[0-9]+ ).*/\1/p')"
check 'take-in gives the issue one entry, and a body to each hit' \
  "$(printf '==> #5 \n==> PR #4 \n==> #8 \n==> PR #9 \n==> #10 \n== end: 4 entries')" \
  "$(grep -E '^==> |^== end' "$collected" | sed -E 's/^(==> (PR )?#[0-9]+ ).*/\1/')"
check 'take-in names the bug and debt labels for the reader' \
  'Labels for bug and debt: enhancement, bug ' "$(grep '^Labels for bug and debt:' "$collected")"
grep -q '^#6 .* \[enhancement\] open$' "$collected" || fail 'take-in lists a bug or debt issue by its open title'
answer '.timelineItems.totalCount = 150'
out=$(bash "$scripts/collect.sh" take-in 5 '' scout.md)
grep -q '^Only the newest 100 of 150 references are here\.$' "${out%%: *}" ||
  fail 'take-in says when the timeline is cut'

check 'usage names every job' 4 "$(bash "$scripts/collect.sh" 2>&1 | grep -c '^usage: collect.sh ')"

# add-finding.sh refuses a busy host and a full one, and writes nothing.
printf '## Also: the scout misses a cited line\n\nWhere: scout.md:26.\n' >"$tmp/section.md"
add() { bash "$scripts/add-finding.sh" 5 "$tmp/section.md" 'New title' "$@"; }
# Sets #5 with no open pull request, so that its status: is free, changed by
# the jq filter $1.
host() { answer ".timelineItems.nodes = [] | $1"; }

# Your own entries make a host busy too: another session of yours can work on
# it, as #119 was while a session worked on it.
for case in 'yours|. + {assignees: {nodes: [{login: "kalinichenko88"}]}, linkedBranches: {nodes: [{ref: {name: "fix/5-citations"}}]}}|it is busy: assigned to you, branch fix/5-citations' \
  'busy|.assignees.nodes = [{login: "someone"}]|it is busy: assigned to someone' \
  'full|.body += "\n## Also: one\n## Also: two\n"|it holds 2 added findings already' \
  'closed|.state = "CLOSED"|it is closed' \
  'pull request|{__typename: "PullRequest", number: 5, title: "t", state: "OPEN", body: ""}|it is a pull request'; do
  IFS='|' read -r name change reason <<<"$case"
  host "$change"
  : >"$tmp/calls"
  out=$(add) && fail "add-finding.sh wrote to a $name host"
  case $out in *"$reason"*) ;; *) fail "add-finding.sh on a $name host" "$out" ;; esac
  check "add-finding.sh writes nothing to a $name host" '' "$(writes)"
done
# As recorded, #5's one open pull request is #9, which you wrote.
answer .
: >"$tmp/calls"
out=$(add) && fail 'add-finding.sh wrote to a host with your open PR'
case $out in *'it is busy: PR #9 by you'*) ;; *) fail 'add-finding.sh on a host with your open PR' "$out" ;; esac
check 'add-finding.sh writes nothing to a host with your open PR' '' "$(writes)"

# A free host takes the finding. DRY_RUN=1 prints the writes and runs none.
host .
: >"$tmp/calls"
out=$(DRY_RUN=1 add bug)
case $out in *'dry run: gh issue edit 5 --title New\ title --body-file '*'--add-label bug'*'dry run: gh issue comment 5'*) ;;
  *) fail 'add-finding.sh with DRY_RUN=1 prints its writes' "$out" ;;
esac
[ -f "$(sed -n 's/.*--body-file \([^ ]*\) .*/\1/p' <<<"$out")" ] || fail 'a dry run keeps the body it names'
check 'add-finding.sh with DRY_RUN=1 runs no write' '' "$(writes)"

# Without it, the body keeps the old text and gains the section.
host .
: >"$tmp/calls"
add >/dev/null
check 'add-finding.sh edits and comments' \
  "$(printf 'issue edit 5 --title New title --body-file %s\nissue comment 5 --body Added to the body: the scout misses a cited line.' \
    "$(sed -n 's/^issue edit 5 --title New title --body-file //p' "$tmp/calls")")" "$(writes)"
check 'the new body is the old one and the section' \
  "$(jq -r .data.repository.n5.body "$fixtures/tracker.json"; echo; cat "$tmp/section.md")" "$(cat "$tmp/body")"
stops add-finding.sh 1 5 "$tmp/section.md" 'New title'

# The comment fails after the edit. The rerun reads the edited body, finds the
# section there, adds the label again without the body or the title, and
# comments, on a host with no added finding before and on one with one before.
for change in . '.body += "\n## Also: one\n"'; do
  host "$change"
  rm -f "$tmp/body"
  FAKE_FAIL='issue comment' add bug >/dev/null 2>&1 && fail 'add-finding.sh passed with a failed comment'
  [ -f "$tmp/body" ] || fail "add-finding.sh did not edit before the comment ($change)"
  host ".body = $(jq -Rs . "$tmp/body")"
  : >"$tmp/calls"
  out=$(add bug) || fail "a rerun of add-finding.sh after a failed comment ($change)" "$out"
  check "a rerun after a failed comment leaves the body ($change)" \
    "$(printf 'issue edit 5 --add-label bug\nissue comment 5 --body Added to the body: the scout misses a cited line.')" \
    "$(writes)"
  check "the body holds the section once ($change)" 1 \
    "$(grep -cxF '## Also: the scout misses a cited line' "$tmp/body")"
done

# A dry rerun with no label prints only the comment, and removes the body that
# no printed edit names.
rm -f "$tmp"/body.*
host '.body += "\n## Also: the scout misses a cited line\n"'
check 'a dry rerun with no label only comments' \
  'dry run: gh issue comment 5 --body Added\ to\ the\ body:\ the\ scout\ misses\ a\ cited\ line.' "$(DRY_RUN=1 add)"
check 'a dry rerun leaves no body' '' "$(find "$tmp" -maxdepth 1 -name 'body.*')"

# A refusal before the body read leaves the file that the caller's $body
# names. One after it, in a dry run, removes its own body.
touch "$tmp/keep"
for change in '.state = "CLOSED"' '.body += "\n## Also: one\n## Also: two\n"'; do
  host "$change"
  body=$tmp/keep DRY_RUN=1 add >/dev/null && fail "add-finding.sh passed on a refused host ($change)"
  [ -f "$tmp/keep" ] || fail "a refusal removed the file that \$body names ($change)"
  check "a refused dry run leaves no body ($change)" '' "$(find "$tmp" -maxdepth 1 -name 'body.*')"
done

# take-in-check.sh, in a checkout of its own: it reads the local branches.
git init -q "$tmp/repo"
take() { (cd "$tmp/repo" && bash "$scripts/take-in-check.sh" "$@" 2>&1) || echo "exit $?"; }
answer . .data.repository.issue take-in-20.json
check 'take-in-check.sh on a free issue' 'take #20' "$(take 20)"
answer '.state = "CLOSED" | .assignees.nodes = [{login: "someone"}, {login: "kalinichenko88"}]
  | .closedByPullRequestsReferences.nodes = [{number: 9, state: "OPEN", author: {login: "someone"}},
      {number: 10, state: "OPEN", author: {login: "kalinichenko88"}}]' .data.repository.issue take-in-20.json
check 'take-in-check.sh on an issue someone else has' \
  "$(printf '#20: closed\n#20: assigned to someone\n#20: assigned to you\n#20: PR #9 by someone is open and closes it\n#20: PR #10 by you is open and closes it\nexit 1')" \
  "$(take '#20')"
# As recorded, #167 is assigned to you and has a linked branch. With no local
# copy of the branch, the work can run on another computer.
answer . .data.repository.issue take-in-167.json
yours167='#167: assigned to you
#167: branch fix/167-architecture-lens-exit2, 0 commits ahead of main, last commit 2026-10-28T13:08:52Z'
check 'take-in-check.sh on an issue that is yours, with its branch not on this computer' \
  "$(printf '%s\nexit 1' "$yours167")" "$(take 167)"
# A local copy that lacks the remote's last commit: work went on somewhere else.
git -C "$tmp/repo" -c user.name=t -c user.email=t commit -q --allow-empty -m 'Pushed work'
pushed=$(git -C "$tmp/repo" rev-parse HEAD)
git -C "$tmp/repo" -c user.name=t -c user.email=t commit -q --allow-empty -m 'Work not pushed yet'
git -C "$tmp/repo" branch fix/167-architecture-lens-exit2
git -C "$tmp/repo" branch fix/153-worktree-branch-owner
check 'take-in-check.sh on an issue whose local branch lacks the remote commit' \
  "$(printf '%s\nexit 1' "$yours167")" "$(take 167)"
# The local copy has the remote's last commit, and more: the work continues here.
answer ".linkedBranches.nodes[0].ref.target.oid = \"$pushed\"" .data.repository.issue take-in-167.json
check 'take-in-check.sh continues an issue whose branch is on this computer' \
  "$(printf '%s\ncontinue #167 on fix/167-architecture-lens-exit2' "$yours167")" "$(take 167)"
answer ".linkedBranches.nodes[0].ref.target.oid = \"$pushed\" | .assignees.nodes = []" .data.repository.issue take-in-167.json
check 'take-in-check.sh does not continue an issue that nobody is assigned to' 'exit 1' "$(take 167 | tail -1)"
answer ".linkedBranches.nodes[0].ref.target.oid = \"$pushed\"
  | .linkedBranches.nodes[0].ref.repository.nameWithOwner = \"someone/agent-skills\"" .data.repository.issue take-in-167.json
check 'take-in-check.sh does not continue on a branch of another repository' 'exit 1' "$(take 167 | tail -1)"
# As recorded, #153 has your open pull request #181 and, so, no linked branch:
# the pull request's branch is the one the work continues on.
answer ".closedByPullRequestsReferences.nodes[0].headRefOid = \"$pushed\"" .data.repository.issue take-in-153.json
check 'take-in-check.sh continues an issue with your open pull request' \
  "$(printf '#153: assigned to you\n#153: PR #181 by you is open and closes it\ncontinue #153 on fix/153-worktree-branch-owner')" \
  "$(take 153)"
answer ".closedByPullRequestsReferences.nodes[0].headRefOid = \"$pushed\"
  | .assignees.nodes += [{login: \"someone\"}]" .data.repository.issue take-in-153.json
check 'take-in-check.sh does not continue an issue that someone else is assigned to' 'exit 1' "$(take 153 | tail -1)"
check 'take-in-check.sh on an issue of another repository' \
  "$(printf '#179 is in octo-org/octo-repo, and this checkout is kalinichenko88/agent-skills: stop\nexit 1')" \
  "$(take https://github.com/octo-org/octo-repo/issues/179)"

# worktree.sh in a main checkout, with DRY_RUN=1. As recorded, #5 has no
# assignee.
answer .
top=$(git -C "$tmp/repo" rev-parse --show-toplevel)
: >"$tmp/calls"
out=$(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 feat/5-scout-citations)
check 'worktree.sh with DRY_RUN=1 prints its writes and the path' \
  "$(printf 'dry run: gh issue edit 5 --add-assignee @me\ndry run: gh issue develop 5 --name feat/5-scout-citations --checkout --worktree %s\ndry run: echo .claude/worktrees/ >>%s\n%s' \
    "$top/.claude/worktrees/feat/5-scout-citations" "$top/.git/info/exclude" "$top/.claude/worktrees/feat/5-scout-citations")" "$out"
check 'worktree.sh with DRY_RUN=1 runs no write' '' "$(writes)"
grep -q .claude/worktrees/ "$top/.git/info/exclude" && fail 'worktree.sh with DRY_RUN=1 wrote info/exclude'

printf 'feat/5-linked\thttps://github.com/kalinichenko88/agent-skills/tree/feat/5-linked\n' >"$tmp/linked"
out=$(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 feat/5-scout-citations)
case $out in *'using it'*'--name feat/5-linked --checkout'*) ;;
  *) fail 'worktree.sh reuses the linked branch' "$out" ;;
esac

# A linked branch on an issue that nobody is assigned to can be someone
# else's: worktree.sh warns, and does not assign the issue to you.
case $out in *'warning: #5 has a linked branch and nobody is assigned'*) ;;
  *) fail 'worktree.sh warns about a linked branch with no assignee' "$out" ;;
esac
case $out in *'dry run: gh issue edit'*) fail 'worktree.sh assigns an issue whose linked branch can be someone else'"'"'s' "$out" ;; esac
out=$(cd "$tmp/repo" && FAKE_FAIL='issue view' DRY_RUN=1 bash "$scripts/worktree.sh" 5 feat/5-scout-citations 2>&1) &&
  fail 'worktree.sh goes on when it cannot read the assignees' "$out"
case $out in *'dry run: gh issue edit'*) fail 'worktree.sh assigns an issue whose assignees it could not read' "$out" ;; esac
answer '.assignees.nodes = [{login: "kalinichenko88"}]'
out=$(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 feat/5-scout-citations)
case $out in *warning*) fail 'worktree.sh warns about a linked branch on an issue assigned to you' "$out" ;; esac
case $out in *'dry run: gh issue edit 5 --add-assignee @me'*) ;;
  *) fail 'worktree.sh assigns an issue that is already yours' "$out" ;;
esac

# An issue that someone else is assigned to is theirs, with a linked branch or
# without one: worktree.sh warns, and does not assign the issue to you.
answer '.assignees.nodes = [{login: "someone"}]'
out=$(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 feat/5-scout-citations)
case $out in *'warning: #5 is assigned to someone'*) ;;
  *) fail 'worktree.sh warns about an issue with a linked branch that someone else is assigned to' "$out" ;;
esac
case $out in *'dry run: gh issue edit'*) fail 'worktree.sh assigns an issue with a linked branch that someone else is assigned to' "$out" ;; esac
mv "$tmp/linked" "$tmp/linked.kept"
out=$(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 feat/5-scout-citations)
case $out in *'warning: #5 is assigned to someone'*) ;;
  *) fail 'worktree.sh warns about an issue that someone else is assigned to' "$out" ;;
esac
case $out in *'dry run: gh issue edit'*) fail 'worktree.sh assigns an issue that someone else is assigned to' "$out" ;; esac
mv "$tmp/linked.kept" "$tmp/linked"
answer '.assignees.nodes = [{login: "someone"}, {login: "kalinichenko88"}]'
out=$(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 feat/5-scout-citations)
case $out in *warning*) fail 'worktree.sh warns about an issue that you are assigned to beside someone else' "$out" ;; esac
case $out in *'dry run: gh issue edit 5 --add-assignee @me'*) ;;
  *) fail 'worktree.sh assigns an issue that you are assigned to beside someone else' "$out" ;;
esac
out=$(cd "$tmp/repo" && FAKE_FAIL='api user' DRY_RUN=1 bash "$scripts/worktree.sh" 5 feat/5-scout-citations 2>&1) &&
  fail 'worktree.sh goes on when it cannot read your login' "$out"
case $out in *'HTTP 502'*) ;; *) fail 'worktree.sh stops on something else than the failed login read' "$out" ;; esac
case $out in *'dry run: gh issue edit'*) fail 'worktree.sh assigns an issue when it could not read your login' "$out" ;; esac

printf 'feat/5-scout-citations\thttps://github.com/kalinichenko88/agent-skills/tree/feat/5-scout-citations\n' >>"$tmp/linked"
out=$(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 feat/5-scout-citations)
case $out in *'using it'*) fail 'worktree.sh leaves a linked branch it was given' "$out" ;; esac
case $out in *'--name feat/5-scout-citations --checkout'*) ;;
  *) fail 'worktree.sh checks out the linked branch it was given' "$out" ;;
esac

# An issue linked only to a branch in another repository, as a fork's: gh
# would make a new branch of that name in this one. worktree.sh stops before
# its first write.
# The line is gh issue develop --list as recorded, with another owner.
printf 'feat/5-linked\thttps://github.com/someone/agent-skills/tree/feat/5-linked\n' >"$tmp/linked"
out=$(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 feat/5-scout-citations 2>&1) &&
  fail 'worktree.sh goes on with a linked branch in another repository' "$out"
check 'worktree.sh names the linked branch in another repository' \
  "$(printf '#5 is linked only to branches in another repository:\nhttps://github.com/someone/agent-skills/tree/feat/5-linked')" "$out"
# A linked branch in this repository still wins, after one in a fork, and
# over the fork branch's own name.
printf 'feat/5-scout-citations\thttps://github.com/kalinichenko88/agent-skills/tree/feat/5-scout-citations\n' >>"$tmp/linked"
out=$(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 feat/5-linked)
case $out in *'using it'*'--name feat/5-scout-citations --checkout'*) ;;
  *) fail 'worktree.sh skips a linked branch in another repository' "$out" ;;
esac

# worktree.sh --here, for "a branch only": it assigns the issue and checks the
# branch out in the checkout where it runs.
answer .
rm -f "$tmp/linked"
: >"$tmp/calls"
out=$(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 feat/5-scout-citations --here)
check 'worktree.sh --here assigns and checks the branch out where it is' \
  "$(printf 'dry run: gh issue edit 5 --add-assignee @me\ndry run: gh issue develop 5 --name feat/5-scout-citations --checkout\n%s' "$top")" "$out"
(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 b --there >/dev/null 2>&1) && fail 'worktree.sh takes an unknown third argument'

# A local branch of the name that no worktree holds, on an issue with no linked
# branch, as a merged pull request's branch that stayed: gh would check its old
# commits out as the work. worktree.sh stops before its first write and names
# them.
git -C "$tmp/repo" -c user.name=t -c user.email=t commit -q --allow-empty -m 'Old work'
git -C "$tmp/repo" branch fix/5-old
out=$(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 fix/5-old 2>&1) &&
  fail 'worktree.sh goes on with an old local branch of the name' "$out"
case $out in *'local branch fix/5-old'*'Old work'*) ;;
  *) fail 'worktree.sh names the old local branch and its commits' "$out" ;;
esac
case $out in *'dry run:'*) fail 'worktree.sh writes before it stops on an old local branch' "$out" ;; esac
# A worktree that still holds the branch, as one left after the merge, does
# not make it the issue's work. The stop names the worktree, to work in or to
# remove.
git -C "$tmp/repo" worktree add -q "$tmp/old" fix/5-old
out=$(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 fix/5-old 2>&1) &&
  fail 'worktree.sh goes on with an old local branch that a worktree holds' "$out"
case $out in *'local branch fix/5-old'*'checked out in '*'/old'*'Old work'*) ;;
  *) fail 'worktree.sh names the worktree that holds the old local branch' "$out" ;;
esac
case $out in *'dry run:'*) fail 'worktree.sh writes before it stops on an old local branch that a worktree holds' "$out" ;; esac
# --local: the person said that the local branch holds this work, or the issue
# continues on it. worktree.sh takes it as it is, where it is checked out.
out=$(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 fix/5-old --local)
case $out in *'fix/5-old is checked out already'*'/old') ;;
  *) fail 'worktree.sh --local works on the local branch in the worktree that holds it' "$out" ;;
esac
# Linked to the issue, the local branch is the issue's work: worktree.sh goes
# on, in the worktree that holds it, or with gh when none does.
printf 'fix/5-old\thttps://github.com/kalinichenko88/agent-skills/tree/fix/5-old\n' >"$tmp/linked"
out=$(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 fix/5-old)
case $out in *'fix/5-old is checked out already'*'/old') ;;
  *) fail 'worktree.sh works on a linked branch in the worktree that holds it' "$out" ;;
esac
git -C "$tmp/repo" worktree remove "$tmp/old"
out=$(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 fix/5-old) ||
  fail 'worktree.sh stops on the local branch that is linked to the issue' "$out"
case $out in *'--name fix/5-old --checkout'*) ;;
  *) fail 'worktree.sh checks out the local branch that is linked to the issue' "$out" ;;
esac
rm "$tmp/linked"
# With no worktree that holds it, --local makes one with git: gh would make a
# new remote branch of the name.
out=$(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 fix/5-old --local)
case $out in *"dry run: git worktree add $top/.claude/worktrees/fix/5-old fix/5-old"*) ;;
  *) fail 'worktree.sh --local makes a worktree for the local branch' "$out" ;;
esac
case $out in *'gh issue develop'*) fail 'worktree.sh --local makes or links a branch with gh' "$out" ;; esac
out=$(cd "$tmp/repo" && DRY_RUN=1 bash "$scripts/worktree.sh" 5 fix/5-old --local --here)
case $out in *'dry run: git switch fix/5-old'*) ;;
  *) fail 'worktree.sh --local --here checks the local branch out where it is' "$out" ;;
esac

# keep-open.sh removes the pull request's link to the one issue it is given.
# keep-open-21.json is PR #21's answer, with its link to #14; the cases add a
# link to #5, and one to another repository's #14.
export KEEP_OPEN_TRIES=1
refs=.data.repository.pullRequest.closingIssuesReferences.nodes
pr21=$(jq -r .data.repository.pullRequest.id "$fixtures/keep-open-21.json")
i14=$(jq -r "${refs}[0].id" "$fixtures/keep-open-21.json")
jq "$refs |= [{id: \"I_5\", number: 5, repository: .[0].repository},
  {id: \"I_other\", number: 14, repository: {id: \"R_other\"}}] + ." "$fixtures/keep-open-21.json" >"$tmp/graphql.json"
removed() { grep 'removeCloseIssueReferences' "$tmp/calls" | grep -oE 'pr=[^ ]+ -f issue=[^ ]+' || true; }
: >"$tmp/calls"
check 'keep-open.sh says what it removed' 'PR #21 no longer closes #14' "$(bash "$scripts/keep-open.sh" '#21' 14)"
check 'keep-open.sh removes only the link to the issue it is given, in this repository' \
  "pr=$pr21 -f issue=$i14" "$(removed)"
: >"$tmp/calls"
out=$(DRY_RUN=1 bash "$scripts/keep-open.sh" 21 '#5')
case $out in "dry run: gh api graphql --silent -f pr=$pr21 -f issue=I_5 "*) ;;
  *) fail 'keep-open.sh prints its write in a dry run' "$out" ;;
esac
check 'keep-open.sh writes nothing in a dry run' '' "$(removed)"
check 'keep-open.sh on an issue the pull request does not close' 'PR #21 does not close #7: nothing to do' \
  "$(bash "$scripts/keep-open.sh" 21 7)"
check 'keep-open.sh writes nothing for an issue the pull request does not close' '' "$(removed)"
FAKE_FAIL=closingIssuesReferences bash "$scripts/keep-open.sh" 21 14 >/dev/null 2>&1 &&
  fail 'keep-open.sh exits 0 when it cannot read the links'
check 'keep-open.sh writes nothing when it cannot read the links' '' "$(removed)"
FAKE_FAIL=removeCloseIssueReferences bash "$scripts/keep-open.sh" 21 14 >/dev/null 2>&1 &&
  fail 'keep-open.sh exits 0 when the removal fails'
jq "$refs = []" "$fixtures/keep-open-21.json" >"$tmp/graphql.json"
bash "$scripts/keep-open.sh" 21 abc >/dev/null 2>&1 && fail 'keep-open.sh takes a word for an issue number'
# GitHub adds a linked branch's link about a second after the pull request
# opens, as the timelines of #16 and #22 show: keep-open.sh reads again.
cp "$fixtures/keep-open-21.json" "$tmp/graphql.next.json"
check 'keep-open.sh waits for the link GitHub adds after the pull request opens' 'PR #21 no longer closes #14' \
  "$(KEEP_OPEN_TRIES=2 bash "$scripts/keep-open.sh" 21 14)"

echo 'github_scripts_test: ok'
