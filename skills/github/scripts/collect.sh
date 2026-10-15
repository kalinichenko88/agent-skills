#!/bin/bash
# Collects what the github skill reads from the tracker into one file, then
# prints the file's path and size. It only reads: no command here changes
# GitHub, git or any file but its own output.
#
#   collect.sh take-in <n> <bug-labels> <name>...
#   collect.sh filing <name>...
#   collect.sh bodies <file> <n>...
#   collect.sh status <n>
#
# take-in and filing write every open title and the hits of a search for each
# name, open and closed, then the body and comments of every open hit. take-in
# starts with the issue and its timeline, and also writes the body of every
# issue and pull request in the timeline and of every open issue with one of
# <bug-labels>: the repository's names for bug and debt, comma-separated, such
# as bug,debt, or ''. A name is a file, a symbol or a word for what the person
# sees; a path is searched by its base name too.
#
# bodies adds the bodies of more issues and pull requests to the file, and
# prints the line where they start: the closed hits and the titles that the
# reader picks. An issue closed as a duplicate brings the issue it duplicates.
# No number gets a second entry. A failed query writes nothing.
#
# status prints the state:, status:, also: and taken: lines of one issue.
# status: names you as "you", and taken: is yes when an entry of status: is
# not yours. A linked branch counts as not yours: GitHub does not say whose.
#
# Needs only bash and gh: every filter is gh's own --jq.

# shellcheck disable=SC2016 # the single-quoted $ are jq's and GraphQL's
set -euo pipefail

usage() {
  sed -n 's/^#   collect.sh/usage: collect.sh/p' "$0" >&2
  exit 2
}

# Sets n to the issue number $1, which can start with #.
number() {
  n=${1#\#}
  case $n in '' | *[!0-9]*) usage ;; esac
}

# Every field an entry and its status: line need, for one issue or pull
# request. The timeline is its newest 100 references: the open pull requests.
fields='__typename
... on Issue {
  number title state stateReason body
  repository { nameWithOwner }
  labels(first: 20) { nodes { name } }
  assignees(first: 10) { nodes { login } }
  linkedBranches(first: 10) { nodes { ref { name } } }
  closedByPullRequestsReferences(first: 100, includeClosedPrs: true) { nodes { number state author { login } } }
  timelineItems(last: 100, itemTypes: [CROSS_REFERENCED_EVENT]) {
    totalCount
    nodes { ... on CrossReferencedEvent { isCrossRepository source {
      __typename
      ... on Issue { number title state repository { nameWithOwner } }
      ... on PullRequest { number title state author { login } repository { nameWithOwner } }
    } } }
  }
  comments(first: 100) { totalCount nodes { author { login } body } }
  duplicateOf { number repository { nameWithOwner } }
}
... on PullRequest { number title state body }'

defs='
def lower: ascii_downcase;
def labels: [(.labels | .nodes? // .)[].name] | if length > 0 then " [" + join(", ") + "]" else "" end;
def line:
  if .__typename == "PullRequest" then "PR #\(.number) \(.title) \(.state | lower)"
  else "#\(.number) \(.title)\(labels) \(.state | lower)"
    + (if .state == "CLOSED" and (.stateReason // "") != "" then " " + (.stateReason | lower) else "" end)
  end;
def prs:
  [ (.closedByPullRequestsReferences.nodes[] | select(.state == "OPEN")),
    (.timelineItems.nodes[] | select(.isCrossRepository == false) | .source
      | select(.__typename == "PullRequest" and .state == "OPEN")) ]
  | unique_by(.number)[] | {number, author: (.author.login // "ghost")};
def who($me): if . == $me then "you" else . end;
def status($me):
  [ (.assignees.nodes[] | "assigned to \(.login | who($me))"),
    (.linkedBranches.nodes[] | select(.ref) | "branch \(.ref.name)"),
    (prs | "PR #\(.number) by \(.author | who($me))") ]
  | if length > 0 then join(", ") else "free" end;
def taken($me):
  [ (.assignees.nodes[] | select(.login != $me)),
    (.linkedBranches.nodes[] | select(.ref)),
    (prs | select(.author != $me)) ]
  | if length > 0 then "yes" else "no" end;
def also: [.body | split("\n")[] | select(startswith("## Also:"))] | length;
def text: if . == "" then "(empty)" else gsub("\r"; "") end;
def entry($me):
  "==> " + line,
  ( select(.__typename == "Issue")
    | (select(.state == "OPEN") | "status: \(status($me))", "also: \(also)"),
      ( [.closedByPullRequestsReferences.nodes[] | select(.state == "MERGED") | "PR #\(.number)"]
        | select(length > 0) | "closed by: " + join(", ") ),
      ( .repository.nameWithOwner as $here | .duplicateOf | select(.)
        | "duplicate of: \(if .repository.nameWithOwner == $here then "" else .repository.nameWithOwner end)#\(.number)" ),
      (select(.comments.totalCount > 100) | "comments: the first 100 of \(.comments.totalCount)") ),
  "", (.body | text),
  ( select(.__typename == "Issue") | .comments.nodes[]
    | "", "-- comment by \(.author.login // "ghost")", "", (.body | text) ),
  "";
def ref:
  .isCrossRepository as $elsewhere | .source | select(.number)
  | (if .__typename == "PullRequest" then "PR " else "" end)
    + (if $elsewhere then .repository.nameWithOwner else "" end)
    + "#\(.number) \(.title) \(.state | lower)";
'

# Runs one GraphQL query for every 20 of the numbers "$@", with $1 as the
# fields of each issue or pull request and $2 as the --jq filter, which sees
# your login as .data.viewer.login. It returns gh's failure: bash does not
# stop on one inside $(...).
each() {
  local f=$1 filter=$2 q n
  shift 2
  while [ $# -gt 0 ]; do
    q=''
    for n in "${@:1:20}"; do
      q="$q n$n: issueOrPullRequest(number: $n) { $f }"
    done
    gh api graphql -f owner="${repo%/*}" -f name="${repo#*/}" --jq "$filter" \
      -f query="query(\$owner: String!, \$name: String!) { viewer { login } repository(owner: \$owner, name: \$name) { $q } }" ||
      return
    shift $(($# < 20 ? $# : 20))
  done
}

# Whether $file has an entry for the number $1.
has() { grep -qE "^==> (PR )?#$1 " "$file"; }

# Prints the entries of the numbers on stdin, and of the issues that the
# duplicates among them duplicate, sorted by number. A number with an entry
# in $file gets none.
entries() {
  local nums num
  nums=$(sort -un)
  if [ -n "$nums" ]; then
    # shellcheck disable=SC2086 # one number per word
    nums=$({ echo "$nums"; each '... on Issue { repository { nameWithOwner } duplicateOf { number repository { nameWithOwner } } }' \
      '.data.repository[] | select(.duplicateOf and .duplicateOf.repository.nameWithOwner == .repository.nameWithOwner)
        | .duplicateOf.number' $nums; } | sort -un)
    nums=$(for num in $nums; do has "$num" || echo "$num"; done)
  fi
  # shellcheck disable=SC2086
  set -- $nums
  each "$fields" "$defs"'.data.viewer.login as $me | [.data.repository[]] | sort_by(.number)[] | entry($me)' "$@"
  echo "== end: $# entries"
}

# The lines that name an issue or pull request of this repository, as numbers;
# with "open", only the lines that end in its state open.
numbers() { sed -E -n "s/^(PR )?#([0-9]+) .*${1:+ $1}\$/\\2/p"; }

size() {
  printf '%s: %s bytes, %s lines' "$file" "$(wc -c <"$file" | tr -d ' ')" \
    "$(wc -l <"$file" | tr -d ' ')"
}

# Appends every open title, and a section of hits for each name, to $file;
# adds the numbers of the hits to $hits.
titles_and_searches() {
  local name issues prs
  {
    echo "== Open issues"
    echo
    # Without --search, gh pages past 1,000: the limit only has to be high.
    gh issue list --state open --limit 100000 --json number,title,labels,state \
      --jq "$defs"'.[] | line'
  } >>"$file"
  # Each name once, and the base name of a path. An empty name would search
  # for everything.
  printf '%s\n' "$@" | sed 's:/*$::' |
    awk -F/ 'NF && !seen[$0]++ { print } NF > 1 && !seen[$NF]++ { print $NF }' |
    while IFS= read -r name; do
      issues=$(gh issue list --state all --limit 1000 --search "$name" \
        --json number,title,labels,state,stateReason --jq "$defs"'.[] | line')
      prs=$(gh pr list --state all --limit 1000 --search "$name" --json number,title,state \
        --jq '.[] | "PR #\(.number) \(.title) \(.state | ascii_downcase)"')
      {
        echo
        echo "== Search: $name"
        echo
        [ -z "$issues$prs" ] && echo "none"
        [ -z "$issues" ] || echo "$issues"
        [ -z "$prs" ] || echo "$prs"
        [ "$(echo "$issues" | wc -l)" -lt 1000 ] && [ "$(echo "$prs" | wc -l)" -lt 1000 ] ||
          echo "GitHub's search stops at 1,000 hits: this list can be cut. Search a narrower name."
      } >>"$file"
      printf '%s\n%s\n' "$issues" "$prs" | numbers open >>"$hits"
    done
}

[ $# -ge 1 ] || usage
repo=$(gh api 'repos/{owner}/{repo}' --jq .full_name)
job=$1
shift

case $job in
  status)
    [ $# -eq 1 ] || usage
    number "$1"
    each "$fields" "$defs"'.data.viewer.login as $me | .data.repository[]
      | if .__typename == "Issue"
        then "state: \(.state | lower)", "status: \(status($me))", "also: \(also)", "taken: \(taken($me))"
        else "state: a pull request" end' "$n"
    exit 0
    ;;
  bodies)
    [ $# -ge 2 ] || usage
    file=$1
    shift
    start=$(($(wc -l <"$file") + 1))
    new='' old=''
    for arg in "$@"; do
      number "$arg"
      if has "$n"; then old="$old #$n"; else new="$new $n"; fi
    done
    [ -z "$old" ] || echo "already in the file:$old"
    if [ -n "$new" ]; then
      part=$(mktemp)
      trap 'rm -f "$part"' EXIT
      # shellcheck disable=SC2086 # one number per word
      printf '%s\n' $new | entries >"$part"
      { echo; echo "== Bodies, added"; echo; cat "$part"; } >>"$file"
    fi
    echo "$(size), new from line $start"
    exit 0
    ;;
  take-in) [ $# -ge 2 ] || usage ;;
  filing) [ $# -ge 1 ] || usage ;;
  *) usage ;;
esac

tmp=${TMPDIR:-/tmp}
file=$(mktemp "${tmp%/}/collect.XXXXXX")
hits=$(mktemp)
# A failed run leaves no half-written file behind.
clean() {
  local code=$?
  rm -f "$hits"
  [ "$code" = 0 ] || rm -f "$file"
}
trap clean EXIT
echo "# collect.sh $job in $repo" >"$file"
echo >>"$file"

if [ "$job" = take-in ]; then
  number "$1"
  labels=$2
  shift 2
  timeline=$(each "$fields" "$defs"'.data.repository[] | (.timelineItems.nodes[] | ref),
    (.timelineItems.totalCount | select(. > 100) | "Only the newest 100 of \(.) references are here.")' "$n")
  {
    echo "Labels for bug and debt: ${labels:-none}"
    echo
    echo "== The issue"
    echo
    each "$fields" "$defs"'.data.viewer.login as $me | .data.repository[] | entry($me)' "$n"
    echo "== Its timeline"
    echo
    echo "${timeline:-none}"
    echo
  } >>"$file"
  echo "$timeline" | numbers >>"$hits"
  printf '%s\n' "$labels" | tr , '\n' | sed 's/^ *//; s/ *$//' | while IFS= read -r label; do
    if [ -n "$label" ]; then
      gh issue list --state open --limit 100000 --label "$label" --json number --jq '.[].number'
    fi
  done >>"$hits"
fi

titles_and_searches "$@"

{
  echo
  echo "== Bodies"
  echo
  entries <"$hits"
} >>"$file"
size
echo
