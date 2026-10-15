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
# status prints the state:, status: and also: lines of one issue.
#
# Needs only bash and gh: every filter is gh's own --jq.

set -euo pipefail

usage() {
  sed -n '7,10s/^#   /usage: /p' "$0" >&2
  exit 2
}

# Every field an entry and its status: line need, for one issue or pull
# request. The timeline is its newest 100 references: the open pull requests.
fields='__typename
... on Issue {
  number title state stateReason body
  labels(first: 20) { nodes { name } }
  assignees(first: 10) { nodes { login } }
  linkedBranches(first: 10) { nodes { ref { name } } }
  closedByPullRequestsReferences(first: 10, includeClosedPrs: true) { nodes { number state } }
  timelineItems(last: 100, itemTypes: [CROSS_REFERENCED_EVENT]) {
    nodes { ... on CrossReferencedEvent { isCrossRepository source {
      __typename
      ... on Issue { number title state repository { nameWithOwner } }
      ... on PullRequest { number title state repository { nameWithOwner } }
    } } }
  }
  comments(first: 100) { totalCount nodes { author { login } body } }
  duplicateOf { number }
}
... on PullRequest { number title state body }'

# shellcheck disable=SC2016 # jq, not shell
defs='
def lower: ascii_downcase;
def labels: [.labels.nodes[].name] | if length > 0 then " [" + join(", ") + "]" else "" end;
def line:
  if .__typename == "PullRequest" then "PR #\(.number) \(.title) \(.state | lower)"
  else "#\(.number) \(.title)\(labels) \(.state | lower)"
    + (if .state == "CLOSED" and .stateReason then " " + (.stateReason | lower) else "" end)
  end;
def status:
  [ (.assignees.nodes[] | "assigned to \(.login)"),
    (.linkedBranches.nodes[] | select(.ref) | "branch \(.ref.name)"),
    ( [ (.closedByPullRequestsReferences.nodes[] | select(.state == "OPEN") | .number),
        (.timelineItems.nodes[] | select(.isCrossRepository == false) | .source
          | select(.__typename == "PullRequest" and .state == "OPEN") | .number) ]
      | unique[] | "PR #\(.)" ) ]
  | if length > 0 then join(", ") else "free" end;
def also: [.body | split("\n")[] | select(startswith("## Also:"))] | length;
def text: if . == "" then "(empty)" else gsub("\r"; "") end;
def entry:
  "==> " + line,
  ( select(.__typename == "Issue")
    | (select(.state == "OPEN") | "status: \(status)", "also: \(also)"),
      ( [.closedByPullRequestsReferences.nodes[] | select(.state == "MERGED") | "PR #\(.number)"]
        | select(length > 0) | "closed by: " + join(", ") ),
      (.duplicateOf | select(.) | "duplicate of: #\(.number)"),
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
# fields of each issue or pull request and $2 as the --jq filter.
each() {
  local f=$1 filter=$2 q n
  shift 2
  while [ $# -gt 0 ]; do
    q=''
    for n in "${@:1:20}"; do
      q="$q n$n: issueOrPullRequest(number: $n) { $f }"
    done
    gh api graphql -f owner="${repo%/*}" -f name="${repo#*/}" --jq "$filter" \
      -f query="query(\$owner: String!, \$name: String!) { repository(owner: \$owner, name: \$name) { $q } }"
    shift $(($# < 20 ? $# : 20))
  done
}

# Prints the entries of the numbers on stdin, and of the issues that the
# duplicates among them duplicate, sorted by number.
entries() {
  local nums
  nums=$(sort -un)
  [ -n "$nums" ] || return 0
  # shellcheck disable=SC2086 # one number per word
  nums=$({ echo "$nums"; each '... on Issue { duplicateOf { number } }' \
    '.data.repository[] | .duplicateOf.number // empty' $nums; } | sort -un)
  # shellcheck disable=SC2086
  each "$fields" "$defs [.data.repository[]] | sort_by(.number)[] | entry" $nums
  echo "== end: $(echo "$nums" | wc -l | tr -d ' ') entries"
}

# The lines that name an issue or pull request of this repository, as numbers;
# with "open", only the lines that end in its state open.
numbers() { sed -E -n "s/^(PR )?#([0-9]+) .*${1:+ $1}\$/\\2/p"; }

size() {
  printf '%s: %s bytes, %s lines' "$file" "$(wc -c <"$file" | tr -d ' ')" \
    "$(wc -l <"$file" | tr -d ' ')"
}

issue_line='"#\(.number) \(.title)" + ([.labels[].name] | if length > 0 then " [" + join(", ") + "]" else "" end)'

# Appends every open title, and a section of hits for each name, to $file;
# adds the numbers of the hits to $hits.
titles_and_searches() {
  local name issues prs
  {
    echo "== Open issues"
    echo
    gh issue list --state open --limit 1000 --json number,title,labels \
      --jq ".[] | $issue_line"
  } >>"$file"
  for name in "$@"; do
    case $name in */*) set -- "$@" "${name##*/}" ;; esac
  done
  printf '%s\n' "$@" | awk '!seen[$0]++' | while IFS= read -r name; do
    issues=$(gh issue list --state all --limit 1000 --search "$name" \
      --json number,title,labels,state,stateReason \
      --jq ".[] | $issue_line"' + " \(.state | ascii_downcase)" + (if .stateReason != "" and .state == "CLOSED" then " " + (.stateReason | ascii_downcase) else "" end)')
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
    each "$fields" "$defs"'.data.repository[] | "state: \(.state | lower)", "status: \(status)", "also: \(also)"' "$1"
    exit 0
    ;;
  bodies)
    [ $# -ge 2 ] || usage
    file=$1
    shift
    start=$(($(wc -l <"$file") + 1))
    new='' old=''
    for n in "$@"; do
      n=${n#\#}
      case $n in '' | *[!0-9]*) usage ;; esac
      if grep -qE "^==> (PR )?#$n " "$file"; then old="$old #$n"; else new="$new $n"; fi
    done
    [ -z "$old" ] || echo "already in the file:$old"
    if [ -n "$new" ]; then
      # shellcheck disable=SC2086 # one number per word
      { echo; echo "== Bodies, added"; echo; printf '%s\n' $new | entries; } >>"$file"
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
trap 'rm -f "$hits"' EXIT
echo "# collect.sh $job in $repo" >"$file"
echo >>"$file"

if [ "$job" = take-in ]; then
  n=$1 labels=$2
  shift 2
  timeline=$(each "$fields" "$defs"'.data.repository[] | .timelineItems.nodes[] | ref' "$n")
  {
    echo "Labels for bug and debt: ${labels:-none}"
    echo
    echo "== The issue"
    echo
    each "$fields" "$defs"'.data.repository[] | entry' "$n"
    echo "== Its timeline"
    echo
    echo "${timeline:-none}"
    echo
  } >>"$file"
  echo "$timeline" | numbers >>"$hits"
  printf '%s\n' "$labels" | tr , '\n' | while IFS= read -r label; do
    if [ -n "$label" ]; then
      gh issue list --state open --limit 1000 --label "$label" --json number --jq '.[].number'
    fi
  done >>"$hits"
fi

titles_and_searches "$@"

{
  echo
  echo "== Bodies"
  echo
  sed "/^${n:-0}\$/d" "$hits" | entries
} >>"$file"
size
echo
